using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Infrastructure.Data;

public static class SampleDataSeeder
{
    public static async Task SeedAsync(IServiceProvider services, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var passwordHasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();

        var now = DateTime.UtcNow;

        var usersByEmail = await db.Users.ToDictionaryAsync(x => x.Email, cancellationToken);

        if (!usersByEmail.TryGetValue("admin@pianomisspass.local", out var adminUser))
        {
            adminUser = new User
            {
                UserName = "admin",
                Email = "admin@pianomisspass.local",
                Password = passwordHasher.Hash("Password123!"),
                Role = UserRole.Admin,
                IsEmailVerified = true,
                CreatedAt = now.AddDays(-14),
                UpdatedAt = now.AddDays(-1)
            };
            db.Users.Add(adminUser);
        }

        if (!usersByEmail.TryGetValue("artist@pianomisspass.local", out var artistUser))
        {
            artistUser = new User
            {
                UserName = "artist_demo",
                Email = "artist@pianomisspass.local",
                Password = passwordHasher.Hash("Password123!"),
                Role = UserRole.User,
                IsEmailVerified = true,
                CreatedAt = now.AddDays(-10),
                UpdatedAt = now.AddDays(-1)
            };
            db.Users.Add(artistUser);
        }

        if (!usersByEmail.TryGetValue("listener@pianomisspass.local", out var listenerUser))
        {
            listenerUser = new User
            {
                UserName = "listener_demo",
                Email = "listener@pianomisspass.local",
                Password = passwordHasher.Hash("Password123!"),
                Role = UserRole.User,
                IsEmailVerified = true,
                CreatedAt = now.AddDays(-8),
                UpdatedAt = now.AddDays(-1)
            };
            db.Users.Add(listenerUser);
        }

        await db.SaveChangesAsync(cancellationToken);

        var userAvatarSeeds = new[]
        {
            (UserId: adminUser!.Id, Url: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=256"),
            (UserId: artistUser!.Id, Url: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=256"),
            (UserId: listenerUser!.Id, Url: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=256")
        };

        foreach (var seed in userAvatarSeeds)
        {
            var exists = await db.DataAssets.AnyAsync(x => x.UserId == seed.UserId && x.AssetType == DataAssetType.ImageAvatar, cancellationToken);
            if (!exists)
            {
                db.DataAssets.Add(new DataAsset
                {
                    UserId = seed.UserId,
                    AssetType = DataAssetType.ImageAvatar,
                    Url = seed.Url,
                    DisplayOrder = 1
                });
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        var instrumentsByName = await db.Instruments.ToDictionaryAsync(x => x.Name, cancellationToken);
        foreach (var instrumentName in new[] { "Piano", "Guitar", "Violin", "Drums" })
        {
            if (!instrumentsByName.ContainsKey(instrumentName))
            {
                db.Instruments.Add(new Instrument { Name = instrumentName });
            }
        }

        var genresByName = await db.Genres.ToDictionaryAsync(x => x.Name, cancellationToken);
        foreach (var genreName in new[] { "Classical", "Pop", "Jazz", "Soundtrack" })
        {
            if (!genresByName.ContainsKey(genreName))
            {
                db.Genres.Add(new Genre { Name = genreName });
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        instrumentsByName = await db.Instruments.ToDictionaryAsync(x => x.Name, cancellationToken);
        genresByName = await db.Genres.ToDictionaryAsync(x => x.Name, cancellationToken);

        var songsByTitle = await db.Songs.ToDictionaryAsync(x => x.Title, cancellationToken);
        var songSeeds = new[]
        {
            new Song { ArtistId = artistUser!.Id, Title = "River in the Night", Composer = "D. Vu", PlayCount = 2400, CreatedAt = now.AddDays(-20), UpdatedAt = now.AddDays(-2) },
            new Song { ArtistId = artistUser!.Id, Title = "Morning Arpeggio", Composer = "L. Tran", PlayCount = 1800, CreatedAt = now.AddDays(-18), UpdatedAt = now.AddDays(-3) },
            new Song { ArtistId = adminUser!.Id, Title = "Cafe Waltz", Composer = "A. Nguyen", PlayCount = 3200, CreatedAt = now.AddDays(-16), UpdatedAt = now.AddDays(-4) },
            new Song { ArtistId = adminUser!.Id, Title = "Sunset Ballad", Composer = "K. Pham", PlayCount = 2700, CreatedAt = now.AddDays(-12), UpdatedAt = now.AddDays(-1) },
            new Song { ArtistId = artistUser!.Id, Title = "City Rain Theme", Composer = "M. Hoang", PlayCount = 1400, CreatedAt = now.AddDays(-9), UpdatedAt = now.AddDays(-1) }
        };

        foreach (var song in songSeeds)
        {
            if (!songsByTitle.ContainsKey(song.Title))
            {
                db.Songs.Add(song);
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        songsByTitle = await db.Songs.ToDictionaryAsync(x => x.Title, cancellationToken);

        var songCoverSeeds = new[]
        {
            (SongId: songsByTitle["River in the Night"].Id, Url: "https://images.unsplash.com/photo-1513883049090-d0b7439799bf?w=1200"),
            (SongId: songsByTitle["Morning Arpeggio"].Id, Url: "https://images.unsplash.com/photo-1465821185615-20b3c2fbf41b?w=1200"),
            (SongId: songsByTitle["Cafe Waltz"].Id, Url: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=1200"),
            (SongId: songsByTitle["Sunset Ballad"].Id, Url: "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=1200"),
            (SongId: songsByTitle["City Rain Theme"].Id, Url: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=1200")
        };

        foreach (var seed in songCoverSeeds)
        {
            var exists = await db.DataAssets.AnyAsync(x => x.SongId == seed.SongId && x.AssetType == DataAssetType.ImageSongCover, cancellationToken);
            if (!exists)
            {
                db.DataAssets.Add(new DataAsset
                {
                    SongId = seed.SongId,
                    AssetType = DataAssetType.ImageSongCover,
                    Url = seed.Url,
                    DisplayOrder = 1
                });
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        var songGenrePairs = new[]
        {
            (Song: "River in the Night", Genre: "Classical"),
            (Song: "Morning Arpeggio", Genre: "Jazz"),
            (Song: "Cafe Waltz", Genre: "Jazz"),
            (Song: "Sunset Ballad", Genre: "Pop"),
            (Song: "City Rain Theme", Genre: "Soundtrack")
        };

        foreach (var (songTitle, genreName) in songGenrePairs)
        {
            var song = songsByTitle[songTitle];
            var genre = genresByName[genreName];
            var exists = await db.GenreSongs.AnyAsync(x => x.SongId == song.Id && x.GenreId == genre.Id, cancellationToken);
            if (!exists)
            {
                db.GenreSongs.Add(new GenreSong { SongId = song.Id, GenreId = genre.Id });
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        var sheetsByName = await db.Sheets.ToDictionaryAsync(x => x.Name, cancellationToken);
        var sheetSeeds = new[]
        {
            new Sheet { SongId = songsByTitle["River in the Night"].Id, InstrumentId = instrumentsByName["Piano"].Id, Name = "River in the Night - Piano Solo", LeftData = "LH: C2 G2 C3 E3", RightData = "RH: E4 G4 C5 G4", LikeCount = 48, CreatedAt = now.AddDays(-15), UpdatedAt = now.AddDays(-2) },
            new Sheet { SongId = songsByTitle["Morning Arpeggio"].Id, InstrumentId = instrumentsByName["Guitar"].Id, Name = "Morning Arpeggio - Fingerstyle", LeftData = "LH: Bass pattern 6-4-5-4", RightData = "RH: Melody arpeggio sequence", LikeCount = 31, CreatedAt = now.AddDays(-14), UpdatedAt = now.AddDays(-3) },
            new Sheet { SongId = songsByTitle["Cafe Waltz"].Id, InstrumentId = instrumentsByName["Piano"].Id, Name = "Cafe Waltz - Easy Version", LeftData = "LH: 3/4 waltz oom-pah-pah", RightData = "RH: Theme A then variation", LikeCount = 77, CreatedAt = now.AddDays(-13), UpdatedAt = now.AddDays(-5) },
            new Sheet { SongId = songsByTitle["Sunset Ballad"].Id, InstrumentId = instrumentsByName["Violin"].Id, Name = "Sunset Ballad - Violin Lead", LeftData = "LH: Bowing legato markers", RightData = "RH: Phrase accents and vibrato", LikeCount = 22, CreatedAt = now.AddDays(-11), UpdatedAt = now.AddDays(-2) }
        };

        foreach (var sheet in sheetSeeds)
        {
            if (!sheetsByName.ContainsKey(sheet.Name))
            {
                db.Sheets.Add(sheet);
            }
        }

        await db.SaveChangesAsync(cancellationToken);

        sheetsByName = await db.Sheets.ToDictionaryAsync(x => x.Name, cancellationToken);

        var assetSeeds = new[]
        {
            (Sheet: "River in the Night - Piano Solo", Type: DataAssetType.Pdf, Url: "https://cdn.pianomisspass.local/sheets/river-night-piano.pdf", Order: 1),
            (Sheet: "River in the Night - Piano Solo", Type: DataAssetType.Audio, Url: "https://cdn.pianomisspass.local/sheets/river-night-preview.mp3", Order: 2),
            (Sheet: "Cafe Waltz - Easy Version", Type: DataAssetType.Pdf, Url: "https://cdn.pianomisspass.local/sheets/cafe-waltz-easy.pdf", Order: 1),
            (Sheet: "Sunset Ballad - Violin Lead", Type: DataAssetType.Pdf, Url: "https://cdn.pianomisspass.local/sheets/sunset-ballad-violin.pdf", Order: 1)
        };

        foreach (var seed in assetSeeds)
        {
            var sheetId = sheetsByName[seed.Sheet].Id;
            var exists = await db.DataAssets.AnyAsync(x => x.SheetId == sheetId && x.Url == seed.Url, cancellationToken);
            if (!exists)
            {
                db.DataAssets.Add(new DataAsset
                {
                    SheetId = sheetId,
                    AssetType = seed.Type,
                    Url = seed.Url,
                    DisplayOrder = seed.Order
                });
            }
        }

        var favorites = new[]
        {
            songsByTitle["Cafe Waltz"].Id,
            songsByTitle["Sunset Ballad"].Id
        };

        foreach (var songId in favorites)
        {
            var exists = await db.UserFavoriteSongs.AnyAsync(x => x.UserId == listenerUser!.Id && x.SongId == songId, cancellationToken);
            if (!exists)
            {
                db.UserFavoriteSongs.Add(new UserFavoriteSong { UserId = listenerUser.Id, SongId = songId });
            }
        }

        var likes = new[]
        {
            sheetsByName["River in the Night - Piano Solo"].Id,
            sheetsByName["Cafe Waltz - Easy Version"].Id
        };

        foreach (var sheetId in likes)
        {
            var exists = await db.UserSheetLikes.AnyAsync(x => x.UserId == listenerUser!.Id && x.SheetId == sheetId, cancellationToken);
            if (!exists)
            {
                db.UserSheetLikes.Add(new UserSheetLike { UserId = listenerUser.Id, SheetId = sheetId, CreatedAt = now.AddDays(-1) });
            }
        }

        var pointsSeed = new[]
        {
            new UserSheetPoint { PlayerId = listenerUser!.Id, SheetId = sheetsByName["River in the Night - Piano Solo"].Id, Point = 94 },
            new UserSheetPoint { PlayerId = listenerUser!.Id, SheetId = sheetsByName["Cafe Waltz - Easy Version"].Id, Point = 88 }
        };

        foreach (var point in pointsSeed)
        {
            var exists = await db.UserSheetPoints.AnyAsync(x => x.PlayerId == point.PlayerId && x.SheetId == point.SheetId, cancellationToken);
            if (!exists)
            {
                db.UserSheetPoints.Add(point);
            }
        }

        var playlist = await db.Playlists.FirstOrDefaultAsync(x => x.UserId == listenerUser!.Id && x.Name == "Evening Practice", cancellationToken);
        if (playlist is null)
        {
            playlist = new Playlist
            {
                UserId = listenerUser.Id,
                Name = "Evening Practice",
                CreatedAt = now.AddDays(-4),
                UpdatedAt = now.AddDays(-1)
            };
            db.Playlists.Add(playlist);
            await db.SaveChangesAsync(cancellationToken);
        }

        var playlistSongSeeds = new[]
        {
            (Song: songsByTitle["River in the Night"].Id, Order: 1),
            (Song: songsByTitle["Sunset Ballad"].Id, Order: 2),
            (Song: songsByTitle["City Rain Theme"].Id, Order: 3)
        };

        foreach (var seed in playlistSongSeeds)
        {
            var exists = await db.PlaylistSongs.AnyAsync(x => x.PlaylistId == playlist.Id && x.SongId == seed.Song, cancellationToken);
            if (!exists)
            {
                db.PlaylistSongs.Add(new PlaylistSong
                {
                    PlaylistId = playlist.Id,
                    SongId = seed.Song,
                    DisplayOrder = seed.Order
                });
            }
        }

        await db.SaveChangesAsync(cancellationToken);
    }
}
