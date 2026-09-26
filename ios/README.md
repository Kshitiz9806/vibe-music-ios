# iOS app setup

The app source is SwiftUI and targets iOS 16+. The Xcode project pins Spotify's official iOS SDK Swift Package at version 5.0.1; Xcode resolves it on the first open/build. Local configuration is stored in the ignored `ios/.env` file and generated into the ignored `Config.local.xcconfig` file. The Spotify Client ID is public and must be embedded in the app; never put the Spotify Client Secret in this iOS configuration.

Register these redirect URIs in the Spotify developer dashboard:

- `app.vibemusic.ios://oauth-callback` — Web API authorization code returned to the app, then exchanged by the backend.
- `app.vibemusic.ios://spotify-login-callback` — App Remote authorization handled by the iOS SDK.

## Configure and run

1. From the repository root, copy the example environment file:

   ```sh
   cp ios/.env.example ios/.env
   ```

2. Edit `ios/.env`. Set `SPOTIFY_CLIENT_ID` to the Client ID for the same Spotify app configured above. For a physical iPhone, set `API_BASE_URL` to your Mac's current Wi-Fi IP address, such as `http://192.168.1.10:8080`. For the iOS Simulator, use `http://127.0.0.1:8080`.

3. Generate the local Xcode configuration:

   ```sh
   bash ios/scripts/configure-local.sh
   ```

4. Open `ios/VibeMusic.xcodeproj` in Xcode, select the VibeMusic scheme and your device or simulator, then press **Run**. Xcode resolves the Spotify iOS SDK package on the first build.

For physical-device playback, run the backend on your Mac, keep the phone and Mac on the same Wi-Fi, allow VibeMusic local-network access, and install Spotify on the phone. The Simulator cannot connect to Spotify App Remote.

At launch, VibeMusic checks `GET /health` before showing sign-in or the radio screen. It displays an animated wake-up indicator while the API and database become ready, retries for up to 90 seconds, then offers a retry button.

Never commit `ios/.env` or `ios/Config.local.xcconfig`.
