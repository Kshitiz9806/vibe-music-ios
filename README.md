# VibeMusic

VibeMusic is a private, single-user-oriented radio app that builds a session from Spotify search, artist top tracks, albums, and the user's listening library. The player intentionally omits track metadata and skip controls.

## Repository layout

- `backend/` — Spring Boot REST API and recommendation/session domain.
- `ios/` — native SwiftUI client and App Remote integration.
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

The iOS setup is in [ios/README.md](ios/README.md). In brief: copy `ios/.env.example` to `ios/.env`, set your Spotify Client ID and the Mac’s Wi-Fi address, then run `bash ios/scripts/configure-local.sh` before opening the Xcode project. For a physical phone, use the Mac’s LAN IP rather than `127.0.0.1`.

Never commit `.env` files or `ios/Config.local.xcconfig`.
