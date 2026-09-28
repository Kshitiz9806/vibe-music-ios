# VibeMusic — Product & Technical Spec

## 1. Overview

**VibeMusic** is a native iOS app that plays music from the user's own Spotify account, but hides all track metadata during playback and removes the ability to skip. Before starting a session, the user can tune what kind of music the radio pulls from using a set of weighted parameters (genre, artist, album), and a recommendation engine scores and orders candidate tracks accordingly.

**Core principle:** the user picks the *shape* of the session up front, then surrenders control — no track names, no skipping, only pause/restart.

---

## 2. Architecture

- **Client:** Native iOS app (Swift), using Spotify's **iOS App Remote SDK** for playback control (requires the Spotify app installed; audio is played by the Spotify app itself, your app only sends commands and receives player state).
- **Backend:** Java Spring Boot, exposing a REST API the iOS app talks to. Owns auth, session state, recommendation scoring, and play history.
- **Database:** Postgres (SQLite acceptable for local dev).
- **External API:** Spotify Web API. This app currently uses `/search`, `/me/top/tracks`, `/me/tracks` (saved tracks), `/artists/{id}`, and `/albums/{id}/tracks`. The genre picker is a curated server-side list: Spotify marks artist genre metadata as deprecated and it may be empty. Genre-seeded candidates are generated with Spotify search queries such as `genre:pop`; the app does not call Spotify's recommendation or genre-seed endpoints.

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

- **Flow:** The iOS app performs Spotify Authorization Code with PKCE, then sends the code, redirect URI, and verifier to the backend. The backend holds the client secret; the iOS app never sees it. Spotify App Remote playback authorization is a separate flow handled by the Spotify iOS SDK.
- **Session model:** After Spotify authorization, the backend issues an opaque, random VibeMusic session token to the iOS app. All authenticated API calls use this token, not the Spotify Web API token. The default session lifetime is 7 days (`vibemusic.session-lifetime`).
- **Token storage:** Spotify access + refresh tokens stored server-side, tied to the user's session. Backend refreshes the Spotify access token transparently before it expires.
- **Web API scopes requested:** `user-read-email`, `user-read-private`, `user-top-read`, and `user-library-read`. Spotify App Remote obtains its playback authorization separately; playback scopes are not included in the backend OAuth request.

### Entities

| Entity | Fields |
|---|---|
| `User` | id, spotify_user_id, display_name, access_token (encrypted), refresh_token (encrypted), token_expires_at, created_at |
| `Session` | id, user_id, token_hash, created_at, expires_at |
| `PlayHistory` | id, user_id, track_id, played_at, radio_session_id |
| `RadioSession` | id, user_id, params (genre, artist_ids, album_ids), started_at |

---

## 4. Landing Page — Parameter Selection

User selects any combination of:

- **Genre** — one or more curated genre terms returned by the backend (not dynamically sourced from Spotify artist metadata)
- **Artist** — one or more seed artists
- **Album** — one or more seed albums

All parameters are optional; unselected ones simply don't contribute to the score. With no selections, the backend uses the user's top tracks and saved tracks as the candidate pool.

### Recommendation Engine

1. **Candidate pool generation** — pull tracks from a mix of live (non-deprecated) endpoints depending on selected params:
   - Genre selected → `/search` with genre-filtered queries such as `genre:pop`; candidates are tagged with the selected genre for scoring.
   - Artist selected → read the selected artist through `/artists/{id}`, then search tracks with an artist-name query through `/search`.
   - Album selected → `/albums/{id}/tracks` for each seed album.
   - No params selected → fallback to `/me/top/tracks` and `/me/tracks` (saved) as the baseline pool.
2. **Scoring** — each candidate gets a composite score, one sub-score per selected parameter:

   | Parameter | Scoring logic |
   |---|---|
   | Genre | Candidates returned by a genre-filtered search are tagged with the selected genre; score is exact/partial match against candidate tags |
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
| `GET` | `/health` | Check backend and database availability; returns `200` when ready or `503` while the database is unavailable |
| `GET` | `/radio/genres` | Return the curated genre list for the picker UI |

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
- Candidate generation now relies on `/search`, artist/album catalog endpoints, and the user's top/saved tracks rather than `/recommendations`. Spotify requests are throttled to about 3 requests/sec. Artist genre metadata is deprecated and is not relied on by the genre picker.
- Encrypt stored refresh tokens at rest.
- No-repeat window and scoring weights should be configurable (even just via application properties to start) rather than hardcoded, since you'll likely want to tune them after using it for a while.
- App is built in **Development Mode** initially (Spotify apps default here), which caps the number of authorized users — fine for personal use, but note this if you ever want to share it beyond your own account without applying for extended quota.

---

## 7. Resolved decisions

- **Parameter cap:** hard cap of **5 total selections** across genre/artist/album combined — no combining logic needed, just block selection past 5.
- **BPM:** dropped entirely as a parameter/scoring criterion. Spotify deprecated the tempo data source (`/audio-features`) with no first-party replacement; not worth the added latency/coverage gaps of a third-party lookup for v1.
- **Candidate sourcing:** genre picks query `/search` with a `genre:` filter; artist picks read `/artists/{id}` then query `/search` by artist name; album picks use `/albums/{id}/tracks`; no-parameter fallback uses `/me/top/tracks` and `/me/tracks` — see §2 and §4.1.
- **Candidate selection:** take the **top 40% of scored candidates** (clamped to a 10–30 count range regardless of pool size) — widened from the earlier top-20%/uniform approach to inject more variety into the pool itself. Pick the next track via **score-weighted random** selection within that window (probability proportional to score, e.g. normalize scores in the window and sample from that distribution) — higher scorers are still more likely, but the wider window means lower-but-still-relevant matches get real odds too.
- **Session expiry:** the UI ends a radio session through the restart/end actions. A backend cleanup job marks sessions ended after 75 minutes of inactivity by default (`vibemusic.idle-session-window`), and checks every 10 minutes (`vibemusic.cleanup-interval`).
- **Lock-screen/Control Center leak:** accepted as a known limitation, not addressed in v1. Spotify's own OS-level media controls will still show track name and skip during a session — no suppression attempted.

---

## 8. API Reference

Authenticated endpoints (`/auth/session` and all `/radio/*` routes) require:

```
Authorization: Bearer <sessionToken>
```

Errors handled by the backend's API error handler use this shape (the readiness endpoint has its own `503` body):

```json
{
  "error": "TOO_MANY_PARAMS",
  "message": "genres + artistIds + albumIds must total 5 or fewer",
  "status": 400
}
```

### 8.1 `GET /health`

Public readiness check used by the startup screen and periodically while a radio session is active. It runs `SELECT 1` against Postgres.

**Response `200`**
```json
{ "status": "UP" }
```

**Response `503`** when the database is not available:
```json
{ "status": "STARTING" }
```

The iOS app polls this endpoint every 10 minutes only while a radio session is active, and checks again when returning to the foreground. iOS may suspend app networking in the background, so background polls are not guaranteed.

---

### 8.2 `POST /auth/spotify/callback`

Exchanges the Spotify authorization code (from the iOS app's PKCE OAuth redirect) for tokens, creates/updates the `User`, and issues a backend session. This endpoint is unauthenticated.

**Request**
```json
{
  "code": "AQD...",
  "redirectUri": "app.vibemusic.ios://oauth-callback",
  "codeVerifier": "..."
}
```

**Response `200`**
```json
{
  "sessionToken": "<opaque random token>",
  "expiresAt": "2026-10-03T06:00:00Z",
  "user": {
    "id": "usr_123",
    "displayName": "Kshitiz",
    "isPremium": true
  }
}
```

**Errors:** `401 INVALID_CODE` if Spotify code exchange/profile lookup fails; `403 PREMIUM_REQUIRED` if the Spotify account is not Premium.

---

### 8.3 `POST /auth/logout`

Invalidates the current session token server-side.

**Request:** empty body. The `Authorization: Bearer` header is optional; when a valid token is supplied, its session is revoked. Missing or invalid tokens are treated as a no-op.
**Response `204`:** no content.

---

### 8.4 `GET /auth/session`

Lightweight check the iOS app can call on launch to validate a stored session token before showing the landing page.

**Response `200`**
```json
{ "valid": true, "user": { "id": "usr_123", "displayName": "Kshitiz" } }
```
**Response `401`** if expired/invalid — client should route to login.

---

### 8.5 `GET /radio/genres`

Returns a stable, curated genre list for the picker. It requires a valid VibeMusic session token but does not call Spotify. This avoids relying on Spotify artist genre metadata, which is deprecated and may be empty.

**Response `200`**
```json
{ "genres": ["alternative", "ambient", "blues", "classical", "country", "...", "world-music"] }
```

The current list includes alternative, ambient, blues, classical, country, dance, disco, drum-and-bass, dubstep, edm, electronic, emo, folk, funk, gospel, grunge, hard-rock, heavy-metal, hip-hop, house, indie, indie-pop, jazz, k-pop, latin, metal, new-age, opera, pop, punk, r&b, reggae, reggaeton, rock, singer-songwriter, soul, soundtrack, synth-pop, techno, trance, trap, trip-hop, and world-music.

---

### 8.6 `POST /radio/start`

Creates a new `RadioSession` from selected params. Requires authentication. Total items across `genres` + `artistIds` + `albumIds` must be ≤ 5; each list is trimmed and deduplicated. Empty selections are accepted and use top tracks plus saved tracks as the candidate pool.

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

**Errors:** `400 TOO_MANY_PARAMS` (>5 total), `401 UNAUTHORIZED` if the session token is missing or invalid.

---

### 8.7 `GET /radio/{sessionId}/next-track`

Runs candidate generation → scoring → filtering → weighted-random selection, creates a play reservation in `PlayHistory`, and returns just enough for the client to start playback. The reservation is marked played only after the client calls `/mark-played`. **Deliberately excludes track name/artist/album from the response** — the client only needs the URI to hand to the App Remote SDK; any metadata the SDK later exposes is simply not rendered by the UI.

**Response `200`**
```json
{
  "trackUri": "spotify:track:4uLU6hMCjMI75M1A2tKUQC",
  "playHistoryId": "ph_456"
}
```

**Response `204`** if the candidate pool is exhausted (e.g., extremely narrow params + full no-repeat window) — client should show a "widen your parameters" prompt rather than erroring.

---

### 8.8 `POST /radio/{sessionId}/mark-played`

Confirms a track actually played (vs. was fetched but skipped due to app close/network issue), used to keep `PlayHistory` accurate for the no-repeat window.

**Request**
```json
{ "playHistoryId": "ph_456", "playedAt": "2026-09-26T06:21:15Z" }
```
**Response `204`**

---

### 8.9 `POST /radio/{sessionId}/restart`

Ends the current session and atomically starts a new one with new params — same shape as `/radio/start`, but as one call so the client doesn't have to sequence two requests.

**Request:** same body as `/radio/start`.
**Response `201`:** same shape as `/radio/start`, with a new `radioSessionId`.

---

### 8.10 `POST /radio/{sessionId}/end`

Explicit end without starting a new session (e.g., user backgrounds the app / logs out mid-session). Optional — the idle cleanup job would eventually catch these anyway, but calling this proactively keeps `PlayHistory` reporting cleaner.

**Response `204`**

---

### 8.11 `GET /radio/search?q={query}&type={artist|album}`

Searches Spotify for artists or albums and returns up to 10 picker results. Requires a valid VibeMusic session token.

**Response `200`**
```json
{
  "items": [
    { "id": "spotify-id", "name": "Artist or album", "subtitle": "Optional artist or genre detail" }
  ]
}
```

An empty query returns `{ "items": [] }`. `type` must be `artist` or `album`; otherwise the API returns `400 INVALID_SEARCH_TYPE`. Spotify upstream failures return `502 SPOTIFY_REQUEST_FAILED` (or `429` for rate limiting).

---

### Session and radio errors

Authenticated endpoints return `401 UNAUTHORIZED` when the VibeMusic session is missing or expired, `404 NOT_FOUND` for an unknown or non-owned radio session/reservation, and `409 SESSION_ENDED` when requesting a track from an ended session. Validation errors use `400 INVALID_REQUEST`; too many picker parameters use `400 TOO_MANY_PARAMS`. Error responses use `{ "error", "message", "status" }` except the health endpoint's readiness body.
