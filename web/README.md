# VibeMusic Web

The browser client mirrors the iOS filter flow and dark visual theme. It supports up to five genre, artist, and album filters, then plays a radio session through Spotify's Web Playback SDK. The player surface exposes play/pause, restart, and end only; it does not render track lists, metadata, skip, or seek controls.

## Requirements

- Node.js 20.19+ (or 22.12+) and npm
- A running VibeMusic backend
- A Spotify Developer app with your Spotify Client ID and Client Secret configured on the backend
- A Spotify Premium account for browser playback

## Local setup

1. In Spotify Developer Dashboard, add this exact Redirect URI:

   ```text
   http://127.0.0.1:5173/auth/callback
   ```

2. Copy `web/.env.example` to `web/.env.local` and set `VITE_SPOTIFY_CLIENT_ID`. Keep the redirect URI and API URL at their example values for local development.

3. In `backend/.env`, set these local web values:

   ```dotenv
   VIBEMUSIC_WEB_ALLOWED_ORIGINS=http://127.0.0.1:5173
   VIBEMUSIC_COOKIE_SECURE=false
   ```

   Set the backend Spotify Client ID and Client Secret to the same Spotify app. The backend's run script reads this file.

4. Start the backend in one terminal:

   ```sh
   bash backend/run-local.sh
   ```

5. Start the web app in another terminal:

   ```sh
   cd web
   cp .env.example .env.local
   npm install
   npm run dev
   ```

6. Open `http://127.0.0.1:5173`. Sign in through Spotify and approve the requested scopes. The backend stores Spotify refresh tokens encrypted and sets a seven-day `HttpOnly` VibeMusic session cookie.

Use `127.0.0.1` consistently in the browser and `VITE_API_URL`; Spotify no longer accepts `localhost` as an OAuth redirect URI. The browser callback and API host should stay on the same loopback hostname for the local cookie to work.

## Render static-site deployment

Create a **Static Site** with `web` as the root directory, `npm install && npm run build` as the build command, and `dist` as the publish directory. Set these build-time environment variables:

| Variable | Value |
| --- | --- |
| `VITE_API_URL` | The backend base URL, such as `https://your-api.onrender.com` |
| `VITE_SPOTIFY_CLIENT_ID` | The Spotify app Client ID |
| `VITE_SPOTIFY_REDIRECT_URI` | `https://your-web-domain/auth/callback` |

Add the exact HTTPS callback URI to the Spotify Developer Dashboard. Add the exact web origin (scheme and host, with no path) to the backend's `VIBEMUSIC_WEB_ALLOWED_ORIGINS`, and set `VIBEMUSIC_COOKIE_SECURE=true`. Configure the static site to rewrite unknown paths to `/index.html`, so `/auth/callback` loads the SPA after Spotify redirects back.

For reliable cookie behavior in production, serve the web app and API from the same site (for example, `www.example.com` and `api.example.com`) or put the API behind the web domain. If they are on unrelated domains, browser third-party-cookie restrictions may prevent the session cookie from being sent.

## Spotify policy note

The current requested player intentionally hides track metadata and cover art. Spotify's published policy says streaming apps must show relevant metadata and cover art during playback. Review this requirement before making the web app public or broadly available.
