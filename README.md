# VibeMusic

VibeMusic is a private, single-user-oriented radio app that builds a session from Spotify search, artist top tracks, albums, and the user's listening library. The player intentionally omits track metadata and skip controls.

The iOS client supports up to five genre, artist, and album filters, shows the active session in a metadata-free Live Activity on the Lock Screen and Dynamic Island, and offers separate **Restart Radio** and **End Radio** actions. End Radio stops playback, clears the filters, and returns to the home screen. The Live Activity currently uses a green heartbeat mark on black; the supplied logo still needs to be resolved in the extension.

## Repository layout

- `backend/` — Spring Boot REST API and recommendation/session domain.
- `ios/` — native SwiftUI client and App Remote integration.
- `web/` — React browser client with Spotify Web Playback SDK integration.
- `docs/architecture.md` — system boundaries and Spotify integration decisions.

Local credentials and machine-specific configuration belong in ignored `.env` files. The example files are safe to commit. The iOS Spotify Client ID is embedded in the app and is public; never put the Spotify Client Secret in the iOS app.

## Run the backend

Requires Java 21 and Maven 3.9+. See [backend/README.md](backend/README.md) for environment setup and run instructions.

```sh
cp backend/.env.example backend/.env
# Edit backend/.env and set your Spotify Client ID and Client Secret.
openssl rand -base64 32
# Paste the generated value into TOKEN_ENCRYPTION_KEY in backend/.env.
bash backend/run-local.sh
```

The backend uses in-memory H2 by default, so no database URL or separate database credentials are needed. To use PostgreSQL, paste your provider's single `postgres://user:password@host/database` URL into the quoted `DATABASE_URL` entry in `backend/.env`; the local run script converts it for Spring Boot. See [backend/README.md](backend/README.md) for details.

The iOS setup is in [ios/README.md](ios/README.md). In brief: copy `ios/.env.example` to `ios/.env`, set your Spotify Client ID and the Mac’s Wi-Fi address, then run `bash ios/scripts/configure-local.sh` before opening the Xcode project. For a physical phone, use the Mac’s LAN IP rather than `127.0.0.1`.

## Run the web app

Requires Node.js 20.19+ (or 22.12+) and npm. See [web/README.md](web/README.md) for Spotify dashboard setup, local environment values, and Render deployment settings.

```sh
cp web/.env.example web/.env.local
# Set VITE_SPOTIFY_CLIENT_ID in web/.env.local.
cd web && npm install && npm run dev
```

Open `http://127.0.0.1:5173`. Run the backend with `bash backend/run-local.sh`; configure `VIBEMUSIC_WEB_ALLOWED_ORIGINS` and `VIBEMUSIC_COOKIE_SECURE` in `backend/.env` as described in the web README.

Never commit `.env` files or `ios/Config.local.xcconfig`.
