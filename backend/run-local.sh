#!/bin/bash
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BACKEND_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Created backend/.env from the example. Add your Spotify credentials and a generated TOKEN_ENCRYPTION_KEY, then run this script again."
    exit 1
fi

set -a
source .env
set +a

for required_name in SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET TOKEN_ENCRYPTION_KEY; do
    required_value="${!required_name:-}"
    if [[ -z "$required_value" || "$required_value" == replace-* ]]; then
        echo "Set $required_name in backend/.env before starting the backend." >&2
        exit 1
    fi
done

exec mvn spring-boot:run
