#!/bin/bash
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$IOS_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Created ios/.env from the example. Add your Spotify Client ID and backend URL, then run this script again."
    exit 1
fi

set -a
source .env
set +a

for required_name in SPOTIFY_CLIENT_ID API_BASE_URL OAUTH_REDIRECT_URI APP_REMOTE_REDIRECT_URI; do
    required_value="${!required_name:-}"
    if [[ -z "$required_value" || "$required_value" == replace-* ]]; then
        echo "Set $required_name in ios/.env before configuring Xcode." >&2
        exit 1
    fi
done

PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-app.vibemusic.ios}"

# xcconfig treats // as a comment delimiter, so split URL schemes with an
# empty variable expansion. Xcode rejoins this into the original URL value.
xcconfig_url() {
    printf '%s\n' "$1" | sed 's|://|:/$()/|g'
}

CONFIG_FILE="$IOS_DIR/Config.local.xcconfig"
{
    printf 'PRODUCT_BUNDLE_IDENTIFIER = %s\n' "$PRODUCT_BUNDLE_IDENTIFIER"
    printf 'SPOTIFY_CLIENT_ID = %s\n' "$SPOTIFY_CLIENT_ID"
    printf 'API_BASE_URL = %s\n' "$(xcconfig_url "$API_BASE_URL")"
    printf 'OAUTH_REDIRECT_URI = %s\n' "$(xcconfig_url "$OAUTH_REDIRECT_URI")"
    printf 'APP_REMOTE_REDIRECT_URI = %s\n' "$(xcconfig_url "$APP_REMOTE_REDIRECT_URI")"
} > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"
echo "Generated ignored ios/Config.local.xcconfig. Rebuild the VibeMusic scheme in Xcode to use these values."
