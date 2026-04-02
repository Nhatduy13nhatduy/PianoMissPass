namespace PianoMissPass.Domain.Entities;

public enum UserRole
{
    User = 0,
    Admin = 1
}

public enum DataAssetType
{
    ImageAvatar = 0,
    ImageSongCover = 1,
    Pdf = 2,
    Audio = 3,
    Image = 4,
    File = 5
}

public static class DataAssetTypeConverter
{
    public static string ToStorageValue(DataAssetType type) => type switch
    {
        DataAssetType.ImageAvatar => "image.avatar",
        DataAssetType.ImageSongCover => "image.song-cover",
        DataAssetType.Pdf => "pdf",
        DataAssetType.Audio => "audio",
        DataAssetType.Image => "image",
        DataAssetType.File => "file",
        _ => "file"
    };

    public static DataAssetType FromStorageValue(string value) => value switch
    {
        "image.avatar" => DataAssetType.ImageAvatar,
        "image.song-cover" => DataAssetType.ImageSongCover,
        "pdf" => DataAssetType.Pdf,
        "audio" => DataAssetType.Audio,
        "image" => DataAssetType.Image,
        "file" => DataAssetType.File,
        _ => DataAssetType.File
    };
}

public class User
{
    public int Id { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public bool IsEmailVerified { get; set; }
    public int VerificationFailedAttempts { get; set; }
    public DateTime? VerificationFailedWindowStartAt { get; set; }
    public DateTime? VerificationLockedUntilAt { get; set; }
    public string Password { get; set; } = string.Empty;
    public UserRole Role { get; set; } = UserRole.User;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<Song> Songs { get; set; } = new List<Song>();
    public ICollection<UserSheetPoint> SheetPoints { get; set; } = new List<UserSheetPoint>();
    public ICollection<UserSheetLike> SheetLikes { get; set; } = new List<UserSheetLike>();
    public ICollection<UserFavoriteSong> FavoriteSongs { get; set; } = new List<UserFavoriteSong>();
    public ICollection<Playlist> Playlists { get; set; } = new List<Playlist>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public ICollection<EmailVerificationCode> EmailVerificationCodes { get; set; } = new List<EmailVerificationCode>();
    public ICollection<PasswordResetCode> PasswordResetCodes { get; set; } = new List<PasswordResetCode>();
    public ICollection<DataAsset> DataAssets { get; set; } = new List<DataAsset>();
}

public class EmailVerificationCode
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public string CodeSalt { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UsedAt { get; set; }

    public User? User { get; set; }
}

public class RefreshToken
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? RevokedAt { get; set; }

    public User? User { get; set; }
}

public class PasswordResetCode
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public string CodeSalt { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UsedAt { get; set; }
    public int FailedAttempts { get; set; }

    public User? User { get; set; }
}

public class Song
{
    public int Id { get; set; }
    public int ArtistId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Composer { get; set; }
    public int PlayCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User? Artist { get; set; }
    public ICollection<Sheet> Sheets { get; set; } = new List<Sheet>();
    public ICollection<GenreSong> GenreSongs { get; set; } = new List<GenreSong>();
    public ICollection<UserFavoriteSong> FavoriteByUsers { get; set; } = new List<UserFavoriteSong>();
    public ICollection<PlaylistSong> PlaylistSongs { get; set; } = new List<PlaylistSong>();
    public ICollection<DataAsset> DataAssets { get; set; } = new List<DataAsset>();
}

public class Sheet
{
    public int Id { get; set; }
    public int SongId { get; set; }
    public int InstrumentId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? LeftData { get; set; }
    public string? RightData { get; set; }
    public int LikeCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Song? Song { get; set; }
    public Instrument? Instrument { get; set; }
    public ICollection<DataAsset> DataAssets { get; set; } = new List<DataAsset>();
    public ICollection<UserSheetPoint> UserSheetPoints { get; set; } = new List<UserSheetPoint>();
    public ICollection<UserSheetLike> UserSheetLikes { get; set; } = new List<UserSheetLike>();
}

public class DataAsset
{
    public int Id { get; set; }
    public int? SheetId { get; set; }
    public int? SongId { get; set; }
    public int? UserId { get; set; }
    public DataAssetType AssetType { get; set; } = DataAssetType.File;
    public string Url { get; set; } = string.Empty;
    public string? PublicId { get; set; }
    public int DisplayOrder { get; set; }

    public Sheet? Sheet { get; set; }
    public Song? Song { get; set; }
    public User? User { get; set; }
}

public class Instrument
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;

    public ICollection<Sheet> Sheets { get; set; } = new List<Sheet>();
}

public class UserSheetPoint
{
    public int Id { get; set; }
    public int SheetId { get; set; }
    public int PlayerId { get; set; }
    public int Point { get; set; }

    public Sheet? Sheet { get; set; }
    public User? Player { get; set; }
}

public class UserSheetLike
{
    public int UserId { get; set; }
    public int SheetId { get; set; }
    public DateTime CreatedAt { get; set; }

    public User? User { get; set; }
    public Sheet? Sheet { get; set; }
}

public class Genre
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;

    public ICollection<GenreSong> GenreSongs { get; set; } = new List<GenreSong>();
}

public class GenreSong
{
    public int GenreId { get; set; }
    public int SongId { get; set; }

    public Genre? Genre { get; set; }
    public Song? Song { get; set; }
}

public class UserFavoriteSong
{
    public int UserId { get; set; }
    public int SongId { get; set; }

    public User? User { get; set; }
    public Song? Song { get; set; }
}

public class Playlist
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User? User { get; set; }
    public ICollection<PlaylistSong> PlaylistSongs { get; set; } = new List<PlaylistSong>();
}

public class PlaylistSong
{
    public int PlaylistId { get; set; }
    public int SongId { get; set; }
    public int DisplayOrder { get; set; }

    public Playlist? Playlist { get; set; }
    public Song? Song { get; set; }
}

