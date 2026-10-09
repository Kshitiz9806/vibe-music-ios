# Architecture decisions

## Spotify authorization and playback

The backend owns Web API credentials, refresh tokens, VibeMusic sessions, candidate generation, and play history. The iOS app separately authorizes Spotify App Remote so it can connect to the installed Spotify app and control playback. These are two grants with distinct purposes: a backend Web API bearer token is never sent to App Remote, and the client secret never ships in the app.

The iOS app uses `ASWebAuthenticationSession` with Authorization Code + PKCE for the backend Web API grant, verifies OAuth state, and posts the code, verifier, and exact redirect URI to `/auth/spotify/callback`; the backend exchanges it using its confidential client credentials. App Remote obtains its own authorization through the Spotify iOS SDK. Both grants request only scopes needed for their APIs.

The web client uses Authorization Code with PKCE and the same callback endpoint. The backend returns its usual session token for iOS and also sets a seven-day `HttpOnly`, `SameSite=Lax` session cookie for the browser. The browser never reads the session cookie from JavaScript. Authenticated API calls accept either iOS bearer tokens or the web cookie; cookie-authenticated state-changing requests must include an allowed `Origin`. Both clients request the same Spotify scope set, including `streaming` and `user-modify-playback-state`, so either client can refresh the shared server-side Spotify grant without narrowing its permissions. The web client obtains a short-lived Spotify access token from `/auth/spotify/playback-token` for the Spotify Web Playback SDK and Spotify's play endpoint. Spotify refresh tokens remain encrypted on the backend.

The browser radio uses up to five genre, artist, and album filters. Its player screen displays only VibeMusic artwork and playback status, with play/pause, restart, and end actions; it does not render track metadata, track lists, seek, or skip controls. Spotify's published policy currently requires streaming apps to show relevant metadata and cover art during playback, so the requested metadata-free experience needs a policy review before public release.

## Candidate generation

Use only supported sources in the spec: Spotify search, artist top tracks, album tracks, top tracks, saved tracks, and artist genre tags. Do not call Recommendations, Audio Features, Audio Analysis, or genre-seed endpoints. Candidate providers are isolated behind an interface so source limits and Spotify API changes do not leak into scoring.

The score is the equal-weight mean across each selected genre, artist, and album. Artist and album selections are exact ID matches. Genre scoring is exact when artist tags contain the chosen genre and partial when tags share meaningful tokens. Deduplicate by Spotify track ID, remove played items inside the configurable window, rank, retain the top 40% clamped to 10–30 (bounded by available candidates), then randomly sample proportional to nonnegative score. If all scores are zero, sample uniformly within the retained window.

## Session and history semantics

Fetching `/next-track` reserves a track but does not mark it played. The client confirms playback through `/mark-played`; the reservation ID ties that confirmation to the selected track. A periodic cleanup marks sessions inactive after configurable inactivity. Explicit end and restart remain available.

## iOS radio and Live Activity lifecycle

The iOS player keeps track metadata out of its own interface and does not provide skip controls. **Restart Radio** pauses playback, ends the current backend session, and starts another session with the selected filters. **End Radio** pauses playback, ends the backend session and Live Activity, clears selected filters and search text, and returns to the landing screen.

The ActivityKit widget extension presents a metadata-free status on the Lock Screen and Dynamic Island: connecting, playing, or paused. The current icon is a green ECG heartbeat on black; the original logo asset is not yet rendering reliably inside the extension. Explicit radio end uses immediate Live Activity dismissal. If iOS terminates the app unexpectedly, VibeMusic clears leftover activities at its next launch; force-quitting does not reliably provide a termination callback for immediate cleanup.

## Data and security

Spotify access and refresh tokens are encrypted at rest using AES-GCM. API session tokens are random opaque values; only SHA-256 digests are persisted. The local profile uses H2 for quick startup, with PostgreSQL as the deployment target. The iOS client validates OAuth state before forwarding the one-time code and PKCE verifier.

## Current implementation boundary

The backend API, data model, Spotify Web API adapter, recommendation core, SwiftUI client, and React browser client are implemented. Spotify requires a configured developer app, bundle ID, redirect URIs, client credentials, and its SDK binary before the iOS target can be built on a machine with full Xcode.
