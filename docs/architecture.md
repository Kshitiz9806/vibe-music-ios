# Architecture decisions

## Spotify authorization and playback

The backend owns Web API credentials, refresh tokens, VibeMusic sessions, candidate generation, and play history. The iOS app separately authorizes Spotify App Remote so it can connect to the installed Spotify app and control playback. These are two grants with distinct purposes: a backend Web API bearer token is never sent to App Remote, and the client secret never ships in the app.

The iOS app uses `ASWebAuthenticationSession` with Authorization Code + PKCE for the backend Web API grant, verifies OAuth state, and posts the code, verifier, and exact redirect URI to `/auth/spotify/callback`; the backend exchanges it using its confidential client credentials. App Remote obtains its own authorization through the Spotify iOS SDK. Both grants request only scopes needed for their APIs.

## Candidate generation

Use only supported sources in the spec: Spotify search, artist top tracks, album tracks, top tracks, saved tracks, and artist genre tags. Do not call Recommendations, Audio Features, Audio Analysis, or genre-seed endpoints. Candidate providers are isolated behind an interface so source limits and Spotify API changes do not leak into scoring.

The score is the equal-weight mean across each selected genre, artist, and album. Artist and album selections are exact ID matches. Genre scoring is exact when artist tags contain the chosen genre and partial when tags share meaningful tokens. Deduplicate by Spotify track ID, remove played items inside the configurable window, rank, retain the top 40% clamped to 10–30 (bounded by available candidates), then randomly sample proportional to nonnegative score. If all scores are zero, sample uniformly within the retained window.

## Session and history semantics

Fetching `/next-track` reserves a track but does not mark it played. The client confirms playback through `/mark-played`; the reservation ID ties that confirmation to the selected track. A periodic cleanup marks sessions inactive after configurable inactivity. Explicit end and restart remain available.

## Data and security

Spotify access and refresh tokens are encrypted at rest using AES-GCM. API session tokens are random opaque values; only SHA-256 digests are persisted. The local profile uses H2 for quick startup, with PostgreSQL as the deployment target. The iOS client validates OAuth state before forwarding the one-time code and PKCE verifier.

## Current implementation boundary

The backend API, data model, Spotify Web API adapter, recommendation core, and SwiftUI client are implemented. Spotify requires a configured developer app, bundle ID, redirect URIs, client credentials, and its SDK binary before the iOS target can be built on a machine with full Xcode.
