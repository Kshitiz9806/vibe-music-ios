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

if [[ "${DATABASE_URL:-}" == postgres://* || "${DATABASE_URL:-}" == postgresql://* ]]; then
    uri_remainder="${DATABASE_URL#*://}"
    if [[ "$uri_remainder" != *@* ]]; then
        echo "DATABASE_URL must include user:password@host for a postgres:// or postgresql:// URL." >&2
        exit 1
    fi

    credentials="${uri_remainder%%@*}"
    database_location="${uri_remainder#*@}"
    if [[ "$credentials" != *:* ]]; then
        echo "DATABASE_URL must include both username and password before @host." >&2
        exit 1
    fi

    database_user="${credentials%%:*}"
    database_password="${credentials#*:}"
    if [[ -z "$database_user" || -z "$database_password" ]]; then
        echo "DATABASE_URL must include non-empty username and password values." >&2
        exit 1
    fi

    if [[ "$database_location" == *\?* ]]; then
        database_query="${database_location#*\?}"
        database_location="${database_location%%\?*}"
        query_separator='?'
    else
        database_query=''
        query_separator=''
    fi

    DATABASE_URL="jdbc:postgresql://${database_location}${query_separator}${database_query}"
    if [[ "$database_user$database_password" == *%* ]]; then
        # Keep percent-encoded URI credentials in the JDBC URL so pgJDBC decodes them.
        if [[ -n "$database_query" ]]; then
            credential_separator='&'
        else
            credential_separator='?'
        fi
        DATABASE_URL="${DATABASE_URL}${credential_separator}user=${database_user}&password=${database_password}"
    else
        SPRING_DATASOURCE_USERNAME="$database_user"
        SPRING_DATASOURCE_PASSWORD="$database_password"
        export SPRING_DATASOURCE_USERNAME SPRING_DATASOURCE_PASSWORD
    fi
    export DATABASE_URL
fi

exec mvn spring-boot:run
