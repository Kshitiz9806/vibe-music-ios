# Backend setup

The backend is a Spring Boot REST API. Local development uses an in-memory H2 database by default.

## Requirements

- Java 21
- Maven 3.9+
- A Spotify Developer app Client ID and Client Secret

## Configure credentials

From the repository root, copy the example file:

```sh
cp backend/.env.example backend/.env
```

Edit `backend/.env` and set `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` from the Spotify Developer Dashboard. Generate a stable token encryption key:

```sh
openssl rand -base64 32
```

Paste that output into `TOKEN_ENCRYPTION_KEY`. Keep the same key between backend restarts so previously stored tokens remain decryptable. `.env` is ignored by Git.

## Run

```sh
bash backend/run-local.sh
```

The API listens on port 8080 by default. API documentation is available at `http://localhost:8080/swagger-ui.html`. To use PostgreSQL instead of in-memory H2, set `DATABASE_URL`, `DATABASE_USERNAME`, and `DATABASE_PASSWORD` in `backend/.env`.
