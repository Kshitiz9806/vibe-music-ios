# VibeMusic — Product & Technical Spec

## 1. Overview

**VibeMusic** is a native iOS app that plays music from the user's own Spotify account, but hides all track metadata during playback and removes the ability to skip. Before starting a session, the user can tune what kind of music the radio pulls from using a set of weighted parameters (genre, artist, album), and a recommendation engine scores and orders candidate tracks accordingly.

**Core principle:** the user picks the *shape* of the session up front, then surrenders control — no track names, no skipping, only pause/restart.

---

## 2. Architecture

- **Client:** Native iOS app (Swift), using Spotify's **iOS App Remote SDK** for playback control (requires the Spotify app installed; audio is played by the Spotify app itself, your app only sends commands and receives player state).
- **Backend:** Java Spring Boot, exposing a REST API the iOS app talks to. Owns auth, session state, recommendation scoring, and play history.
- **Database:** Postgres (SQLite acceptable for local dev).
- **External API:** Spotify Web API. Note: `/recommendations`, `/audio-features`, `/audio-analysis`, and `/recommendations/available-genre-seeds` were deprecated by Spotify on Nov 27, 2024 for apps created after that date — this app cannot use them. Candidate generation instead uses `/search` (genre-filtered queries), `/me/top/tracks`, `/me/tracks` (saved), `/artists/{id}/top-tracks`, and `/albums/{id}/tracks`. Genre data comes from the `genres` array still present on artist objects (`/artists/{id}`), not the deprecated seed-list endpoint.

```
iOS App (App Remote SDK for playback)
   │  REST calls
   ▼
Spring Boot Backend
   │  Web API calls (server-side token)
   ▼
Spotify Web API
```

---

## 3. Authentication

- **Flow:** Spotify OAuth 2.0 Authorization Code flow, handled server-side (backend holds the client secret; iOS app never sees it).
- **Session model:** Once the user authenticates via Spotify, the backend issues its own session token (e.g., a signed JWT or opaque session id) to the iOS app. All subsequent API calls from the app use this session token, not the raw Spotify token.
- **Token storage:** Spotify access + refresh tokens stored server-side, tied to the user's session. Backend refreshes the Spotify access token transparently before it expires.
- **Scopes needed:** `user-read-email`, `user-top-read`, `user-library-read`, `streaming`, `app-remote-control`, `user-read-playback-state`, `user-modify-playback-state`.

### Entities

| Entity | Fields |
|---|---|
| `User` | id, spotify_user_id, display_name, access_token (encrypted), refresh_token (encrypted), token_expires_at, created_at |
| `Session` | id, user_id, session_token, created_at, expires_at |
| `PlayHistory` | id, user_id, track_id, played_at, radio_session_id |
| `RadioSession` | id, user_id, params (genre, artist_ids, album_ids), started_at |

---

## 4. Landing Page — Parameter Selection

User selects any combination of:

- **Genre** — one or more genres (sourced from artist genre tags, since Spotify's genre-seed list is deprecated)
- **Artist** — one or more seed artists
- **Album** — one or more seed albums

All parameters are optional; unselected ones simply don't contribute to the score. At least one parameter should be required to start a session (fallback: if none selected, default to the user's top tracks/genres as a baseline pool).

### Recommendation Engine

1. **Candidate pool generation** — pull tracks from a mix of live (non-deprecated) endpoints depending on selected params:
   - Genre selected → `/search` with genre-filtered queries (`genre:lo-fi`), plus cross-referencing artist `genres` tags on tracks pulled from the user's library.
   - Artist selected → `/artists/{id}/top-tracks` for each seed artist.
   - Album selected → `/albums/{id}/tracks` for each seed album.
   - No params selected → fallback to `/me/top/tracks` and `/me/tracks` (saved) as the baseline pool.
2. **Scoring** — each candidate gets a composite score, one sub-score per selected parameter:

   | Parameter | Scoring logic |
   |---|---|
   | Genre | Match against track/artist genre tags (1.0 exact match, partial credit for related genres) |
   | Artist | 1.0 if track's artist is in the selected set, else 0 |
   | Album | 1.0 if track's album is in the selected set, else 0 |

   Final score = weighted average across only the parameters the user selected (equal weighting by default; consider letting the user adjust weights later).
3. **Filtering** — exclude anything in `PlayHistory` within a configurable no-repeat window (e.g., last 30 days).
4. **Selection** — pick the next track via **score-weighted random** selection from the top 40% of scored candidates (clamped to a 10–30 count window). Probability proportional to score within the window — higher scorers still more likely, but the wider window gives lower-but-relevant matches real odds too (pure greedy/highest-score selection would make the radio predictable).

### Backend endpoints (indicative)

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/auth/spotify/callback` | Exchange Spotify auth code, create session |
| `POST` | `/radio/start` | Create a `RadioSession` with selected params |
| `GET` | `/radio/{sessionId}/next-track` | Return next track URI (runs scoring + selection + logs to history) |
| `POST` | `/radio/{sessionId}/mark-played` | Log a track as played |
| `POST` | `/radio/{sessionId}/restart` | End current session, accept new params, start fresh session |
| `GET` | `/radio/genres` | Return a genre list (derived from artist genre tags) for the picker UI |

---

## 5. Player UI

- Visually modeled on Spotify's now-playing screen, minus:
  - Track name, artist name, album art/name
  - Lyrics
- Retains:
  - Play/pause
  - Progress bar (time elapsed/remaining is fine — it's not identifying info)
  - Volume control (optional, if not already OS-level)
  - Big, obvious **"Restart Radio"** action — ends the current session and returns to the landing page/parameter picker to start a new one with different params.
- **No skip control** — no next/previous button in the UI.
- **Keep screen awake** — disable the iOS idle timer (`UIApplication.shared.isIdleTimerDisabled = true`) while the radio/player screen is active, so the device doesn't auto-lock mid-session. Re-enable it when navigating away from that screen (landing page, restart flow, backgrounding the app) to avoid draining battery unnecessarily elsewhere in the app.
- **Known limitation (accepted):** this is a UI-level restriction only. The OS lock screen and Control Center will still show Spotify's own now-playing info and skip controls, since Spotify (not this app) renders those system media controls. No attempt will be made to suppress or override this — it's out of scope for v1.

---

## 6. Non-functional notes

- Spotify on-demand playback via the API/App Remote requires **Premium** — worth a check/gate at login.
- Candidate generation now relies on `/search`, top-tracks, and library endpoints (see §2) rather than the deprecated `/recommendations` — this means more API calls per session (roughly 10–20 search/lookup calls to build one candidate pool). Throttle to ~3 requests/sec and cache per-artist genre lookups where possible to stay within Spotify's rate limits.
- Encrypt stored refresh tokens at rest.
- No-repeat window and scoring weights should be configurable (even just via application properties to start) rather than hardcoded, since you'll likely want to tune them after using it for a while.
- App is built in **Development Mode** initially (Spotify apps default here), which caps the number of authorized users — fine for personal use, but note this if you ever want to share it beyond your own account without applying for extended quota.

---

## 7. Resolved decisions

- **Parameter cap:** hard cap of **5 total selections** across genre/artist/album combined — no combining logic needed, just block selection past 5.
- **BPM:** dropped entirely as a parameter/scoring criterion. Spotify deprecated the tempo data source (`/audio-features`) with no first-party replacement; not worth the added latency/coverage gaps of a third-party lookup for v1.
- **Candidate sourcing:** since `/recommendations` is deprecated, candidates are built from `/search` (genre), `/artists/{id}/top-tracks` (artist), `/albums/{id}/tracks` (album), and `/me/top/tracks` + `/me/tracks` (no-params fallback) — see §2 and §4.1.
- **Candidate selection:** take the **top 40% of scored candidates** (clamped to a 10–30 count range regardless of pool size) — widened from the earlier top-20%/uniform approach to inject more variety into the pool itself. Pick the next track via **score-weighted random** selection within that window (probability proportional to score, e.g. normalize scores in the window and sample from that distribution) — higher scorers are still more likely, but the wider window means lower-but-still-relevant matches get real odds too.
- **Session expiry:** sessions only end via **manual restart** (user-facing) — no auto-timeout in the UX. Backend adds a silent **idle cleanup job** that ends/garbage-collects any `RadioSession` with 60–90 min of no playback activity, purely to keep the DB tidy after abandoned/force-quit sessions.
- **Lock-screen/Control Center leak:** accepted as a known limitation, not addressed in v1. Spotify's own OS-level media controls will still show track name and skip during a session — no suppression attempted.

---

## 8. API Reference

All authenticated endpoints (everything except `/auth/spotify/callback`) require:

```
Authorization: Bearer <sessionToken>
```

Standard error shape for all non-2xx responses:

```json
{
  "error": "TOO_MANY_PARAMS",
  "message": "genres + artistIds + albumIds must total 5 or fewer",
  "status": 400
}
```

### 8.1 `POST /auth/spotify/callback`

Exchanges the Spotify authorization code (from the iOS app's OAuth redirect) for tokens, creates/updates the `User`, and issues a backend session.

**Request**
```json
{
  "code": "AQD...",
  "redirectUri": "vibemusic://callback"
}
```

**Response `200`**
```json
{
  "sessionToken": "eyJhbGciOi...",
  "expiresAt": "2026-10-03T06:00:00Z",
  "user": {
    "id": "usr_123",
    "displayName": "Kshitiz",
    "isPremium": true
  }
}
```

**Errors:** `401 INVALID_CODE`, `403 PREMIUM_REQUIRED` (if account isn't Premium, fail fast here rather than letting playback fail later).

---

### 8.2 `POST /auth/logout`

Invalidates the current session token server-side.

**Request:** empty body.
**Response `204`:** no content.

---

### 8.3 `GET /auth/session`

Lightweight check the iOS app can call on launch to validate a stored session token before showing the landing page.

**Response `200`**
```json
{ "valid": true, "user": { "id": "usr_123", "displayName": "Kshitiz" } }
```
**Response `401`** if expired/invalid — client should route to login.

---

### 8.4 `GET /radio/genres`

Returns a genre list for the picker UI, derived server-side from artist `genres` tags (Spotify's dedicated genre-seed endpoint is deprecated) — e.g. aggregated from the user's top/saved artists and cached periodically.

**Response `200`**
```json
{ "genres": ["house", "lo-fi", "indie-pop", "drum-and-bass", "..."] }
```

---

### 8.5 `POST /radio/start`

Creates a new `RadioSession` from selected params. Total items across `genres` + `artistIds` + `albumIds` must be ≤ 5.

**Request**
```json
{
  "genres": ["lo-fi", "indie-pop"],
  "artistIds": ["3TVXtAsR1Inumwj472S9r4"],
  "albumIds": []
}
```

**Response `201`**
```json
{
  "radioSessionId": "rs_789",
  "startedAt": "2026-09-26T06:20:00Z"
}
```

**Errors:** `400 TOO_MANY_PARAMS` (>5 total), `400 NO_PARAMS_AND_NO_FALLBACK` (only if you decide not to auto-fallback to top tracks).

---

### 8.6 `GET /radio/{sessionId}/next-track`

Runs candidate generation → scoring → filtering → weighted-random selection, logs the pick to `PlayHistory`, and returns just enough for the client to start playback. **Deliberately excludes track name/artist/album from the response** — the client only needs the URI to hand to the App Remote SDK; any metadata the SDK later exposes is simply not rendered by the UI.

**Response `200`**
```json
{
  "trackUri": "spotify:track:4uLU6hMCjMI75M1A2tKUQC",
  "playHistoryId": "ph_456"
}
```

**Response `204`** if the candidate pool is exhausted (e.g., extremely narrow params + full no-repeat window) — client should show a "widen your parameters" prompt rather than erroring.

---

### 8.7 `POST /radio/{sessionId}/mark-played`

Confirms a track actually played (vs. was fetched but skipped due to app close/network issue), used to keep `PlayHistory` accurate for the no-repeat window.

**Request**
```json
{ "playHistoryId": "ph_456", "playedAt": "2026-09-26T06:21:15Z" }
```
**Response `204`**

---

### 8.8 `POST /radio/{sessionId}/restart`

Ends the current session and atomically starts a new one with new params — same shape as `/radio/start`, but as one call so the client doesn't have to sequence two requests.

**Request:** same body as `/radio/start`.
**Response `201`:** same shape as `/radio/start`, with a new `radioSessionId`.

---

### 8.9 `POST /radio/{sessionId}/end`

Explicit end without starting a new session (e.g., user backgrounds the app / logs out mid-session). Optional — the idle cleanup job would eventually catch these anyway, but calling this proactively keeps `PlayHistory` reporting cleaner.

**Response `204`**