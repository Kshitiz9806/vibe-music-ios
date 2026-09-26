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

The API listens on port 8080 by default. `GET /health` returns `200` with `{"status":"UP"}` when the API can reach its database, or `503` while the database is unavailable. API documentation is available at `http://localhost:8080/swagger-ui.html`. To use PostgreSQL instead of in-memory H2, uncomment `DATABASE_URL` in `backend/.env` and paste the single connection URL from your provider, for example:

```dotenv
DATABASE_URL='postgres://user:password@host:5432/database?sslmode=require'
```

The local run script converts `postgres://` or `postgresql://` URLs to the JDBC format Spring needs, using the username and password already embedded in the URL. It does not print the URL. Keep the value quoted in `.env`, especially when it contains query parameters such as `sslmode=require`.

## Deploy to Render

The backend Dockerfile and Docker ignore file are in this directory. Before creating the service, commit and push `backend/Dockerfile`, `backend/.dockerignore`, and `backend/src/main/java/app/vibemusic/api/HealthController.java` to the branch Render will deploy.

In Render, choose **New → Web Service**, connect the repository, and configure:

- **Root Directory:** `backend`
- **Runtime:** Docker
- **Dockerfile Path:** `Dockerfile`
- **Docker Context Directory:** `.`
- **Docker Command:** leave blank
- **Health Check Path:** `/health`
- **Region:** nearest to the Neon database
- **Instance Type:** Free for initial testing (free services sleep after inactivity)

Add these environment variables in Render. Use the JDBC URL format for `DATABASE_URL`; the local launcher is not used inside the container.

| Key | Value |
| --- | --- |
| `DATABASE_URL` | `jdbc:postgresql://<Neon-host>/neondb?sslmode=require` |
| `SPRING_DATASOURCE_USERNAME` | Neon database username |
| `SPRING_DATASOURCE_PASSWORD` | Neon database password |
| `SPOTIFY_CLIENT_ID` | Spotify app Client ID |
| `SPOTIFY_CLIENT_SECRET` | Spotify app Client Secret |
| `TOKEN_ENCRYPTION_KEY` | Stable encryption key |

Leave `PORT` unset; Render supplies it. After deployment, the service URL is your backend base URL. Check readiness at `https://<service>.onrender.com/health`.
