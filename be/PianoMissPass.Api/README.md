# PianoMissPass Backend (.NET 9 + PostgreSQL)

Architecture layers:

- Domain: entities, enums (Admin/User), business exceptions.
- Application: DTOs, abstractions, mapping.
- Infrastructure: DbContext, auth implementation, JWT + password hasher.
- API: controllers + middleware.

Solution structure:

- ../PianoMissPass.sln
- ../PianoMissPass.Domain
- ../PianoMissPass.Application
- ../PianoMissPass.Infrastructure
- . (PianoMissPass.Api)

## 1) Start PostgreSQL

At folder `be`:

Windows note: Docker Desktop must be running before this command.

Local config is stored in `be/.env`. The API and Docker Compose both read from it.

If you already started Postgres before and later changed the password or connection string, reset the named volume first:

```powershell
docker compose down -v
```

```powershell
docker compose up -d
```

The first init password comes from `be/docker-compose.yml`, so if the existing volume was created with a different password, you must remove the volume or use that old password in `appsettings.json`.
For local development, prefer updating `be/.env` instead of editing `appsettings.json` directly.

## 2) Run migration

At folder `be/PianoMissPass.Api`:

```powershell
dotnet tool restore
dotnet tool run dotnet-ef database update --project ..\PianoMissPass.Infrastructure\PianoMissPass.Infrastructure.csproj --startup-project PianoMissPass.Api.csproj
```

## 3) Run API

```powershell
dotnet run
```

Swagger UI:

- https://localhost:xxxx/swagger

## JWT auth

Public endpoints:

- POST /api/auth/register
- POST /api/auth/login
- POST /api/auth/refresh
- POST /api/auth/revoke
- POST /api/auth/verify-email
- POST /api/auth/resend-verification

Admin endpoints:

- PATCH /api/users/{id}/role

Use returned accessToken in Swagger Authorize:

- Bearer {token}

Swagger includes example payloads for:

- register/login/refresh/revoke
- admin role update

Email verification flow:

1. Register account.
2. Server sends 6-digit code via SMTP email.
3. Call `/api/auth/verify-email` with email + code.
4. Login is allowed only after email verification.

Anti-spam limits for verification code:

- Resend cooldown: 60 seconds between requests.
- Rate limit: maximum 5 codes per account per hour.
- Verification code is stored as salted hash in database (not plain text).
- Brute-force lock: if OTP is entered incorrectly 5 times within 10 minutes, verification is locked for 10 minutes.

Most resource endpoints require JWT authentication.

Authorization policies:

- AdminOnly: requires role Admin.
- UserOrAdmin: requires role User or Admin.

## Implemented API controllers

- /api/users
- /api/songs
- /api/sheets
- /api/sheetassets
- /api/instruments
- /api/usersheetpoints
- /api/usersheetlikes
- /api/genres
- /api/genresongs
- /api/userfavoritesongs
- /api/playlists
- /api/playlistsongs
- /api/auth

All database tables from your schema are mapped in EF Core model and initial migration.
Refresh token and role support are included in Infrastructure migrations.

## List endpoints: pagination, search, sort

List endpoints now share the following query parameters:

- `page`: current page, starting from `1`.
- `pageSize`: number of records per page, default `10`, maximum `100`.
- `search`: endpoint-specific search string.
- `sort`: sorting key.

List endpoints return paged responses in the following shape:

- `items`: data for the current page.
- `page`: current page number.
- `pageSize`: number of records per page.
- `totalItems`: total number of records after filtering.
- `totalPages`: total number of pages.

### Sort keys by endpoint

| Endpoint | Sort keys |
| --- | --- |
| `/api/songs` | `title_asc`, `title_desc`, `updated_asc`, `updated_desc`, `play_asc`, `play_desc` |
| `/api/sheets` | `title_asc`, `title_desc`, `updated_asc`, `updated_desc`, `like_asc`, `like_desc` |
| `/api/users` | `title_asc`, `title_desc`, `updated_asc`, `updated_desc` |
| `/api/playlists` | `title_asc`, `title_desc`, `updated_asc`, `updated_desc` |

### Search behavior

- `/api/songs`: search by `title` or `composer`
- `/api/sheets`: search by `name`
- `/api/users`: search by `userName` or `email`
- `/api/playlists`: search by `name`

### Example

```http
GET /api/songs?page=1&pageSize=20&search=river&sort=play_desc
```

This returns page 1 with 20 songs per page, filters records related to `river`, and sorts by play count descending.
