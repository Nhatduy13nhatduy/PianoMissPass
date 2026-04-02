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

Admin endpoints:

- PATCH /api/users/{id}/role

Use returned accessToken in Swagger Authorize:

- Bearer {token}

Swagger includes example payloads for:

- register/login/refresh/revoke
- admin role update

Most resource endpoints require JWT authentication.

Authorization policies:

- AdminOnly: requires role Admin.
- UserOrAdmin: requires role User or Admin.

## Default connection string

Configured in `appsettings.json`:

- Host=localhost
- Port=5432
- Database=PianoMissPassDb
- Username=postgres
- Password=Duy13112002

You can override these values through `be/.env` using keys like `ConnectionStrings__DefaultConnection` and `Jwt__Secret`.

Update this if your local PostgreSQL credentials are different.

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
