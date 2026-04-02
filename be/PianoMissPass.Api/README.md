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

```powershell
docker compose up -d
```

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

Use returned accessToken in Swagger Authorize:

- Bearer {token}

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
- Password=postgres

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
