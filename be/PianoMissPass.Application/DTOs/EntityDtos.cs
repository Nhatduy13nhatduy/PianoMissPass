using System.ComponentModel.DataAnnotations;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.DTOs;

public class UserDto
{
    public int Id { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public UserRole Role { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class UserCreateRequestDto
{
    [Required, StringLength(255)]
    public string UserName { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(6), StringLength(255)]
    public string Password { get; set; } = string.Empty;

    [StringLength(500)]
    public string? AvatarUrl { get; set; }

    public UserRole Role { get; set; } = UserRole.User;
}

public class UserUpdateRequestDto : UserCreateRequestDto;

public class SongDto
{
    public int Id { get; set; }
    public int ArtistId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Composer { get; set; }
    public string? ImageUrl { get; set; }
    public int PlayCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class SongDetailDto
{
    public int Id { get; set; }
    public int ArtistId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Composer { get; set; }
    public int PlayCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public string? ImageUrl { get; set; }
    public IReadOnlyList<GenreDto> Genres { get; set; } = Array.Empty<GenreDto>();
    public IReadOnlyList<InstrumentDto> Instruments { get; set; } = Array.Empty<InstrumentDto>();
    public IReadOnlyList<SongDetailSheetDto> Sheets { get; set; } = Array.Empty<SongDetailSheetDto>();
}

public class SongDetailSheetDto
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
    public InstrumentDto? Instrument { get; set; }
    public IReadOnlyList<DataAssetDto> DataAssets { get; set; } = Array.Empty<DataAssetDto>();
    public IReadOnlyList<UserSheetLikeDto> UserSheetLikes { get; set; } = Array.Empty<UserSheetLikeDto>();
    public IReadOnlyList<UserSheetPointDto> UserSheetPoints { get; set; } = Array.Empty<UserSheetPointDto>();
}

public class SongRequestDto
{
    [Required]
    public int ArtistId { get; set; }

    [Required, StringLength(255)]
    public string Title { get; set; } = string.Empty;

    [StringLength(255)]
    public string? Composer { get; set; }

    [StringLength(500)]
    public string? ImageUrl { get; set; }

    [Range(0, int.MaxValue)]
    public int PlayCount { get; set; }
}

public class SheetDto
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
}

public class SheetRequestDto
{
    [Required]
    public int SongId { get; set; }

    [Required]
    public int InstrumentId { get; set; }

    [Required, StringLength(255)]
    public string Name { get; set; } = string.Empty;

    [StringLength(4000)]
    public string? LeftData { get; set; }

    [StringLength(4000)]
    public string? RightData { get; set; }

    [Range(0, int.MaxValue)]
    public int LikeCount { get; set; }
}

public class DataAssetDto
{
    public int Id { get; set; }
    public int? SheetId { get; set; }
    public int? SongId { get; set; }
    public int? UserId { get; set; }
    public DataAssetType AssetType { get; set; }
    public string Url { get; set; } = string.Empty;
    public string? PublicId { get; set; }
    public int DisplayOrder { get; set; }
}

public class DataAssetRequestDto
{
    public int? SheetId { get; set; }
    public int? SongId { get; set; }
    public int? UserId { get; set; }

    public DataAssetType AssetType { get; set; } = DataAssetType.File;

    [Required, StringLength(500)]
    public string Url { get; set; } = string.Empty;

    [StringLength(255)]
    public string? PublicId { get; set; }

    public int DisplayOrder { get; set; }
}

public class InstrumentDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class InstrumentRequestDto
{
    [Required, StringLength(100)]
    public string Name { get; set; } = string.Empty;
}

public class UserSheetPointDto
{
    public int Id { get; set; }
    public int SheetId { get; set; }
    public int PlayerId { get; set; }
    public int Point { get; set; }
}

public class UserSheetPointRequestDto
{
    [Required]
    public int SheetId { get; set; }

    [Required]
    public int PlayerId { get; set; }

    public int Point { get; set; }
}

public class UserSheetLikeDto
{
    public int UserId { get; set; }
    public int SheetId { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UserSheetLikeRequestDto
{
    [Required]
    public int UserId { get; set; }

    [Required]
    public int SheetId { get; set; }
}

public class GenreDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class GenreRequestDto
{
    [Required, StringLength(100)]
    public string Name { get; set; } = string.Empty;
}

public class GenreSongDto
{
    public int GenreId { get; set; }
    public int SongId { get; set; }
}

public class GenreSongRequestDto
{
    [Required]
    public int GenreId { get; set; }

    [Required]
    public int SongId { get; set; }
}

public class UserFavoriteSongDto
{
    public int UserId { get; set; }
    public int SongId { get; set; }
}

public class UserFavoriteSongRequestDto
{
    [Required]
    public int UserId { get; set; }

    [Required]
    public int SongId { get; set; }
}

public class PlaylistDto
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class PlaylistRequestDto
{
    [Required]
    public int UserId { get; set; }

    [Required, StringLength(255)]
    public string Name { get; set; } = string.Empty;
}

public class PlaylistSongDto
{
    public int PlaylistId { get; set; }
    public int SongId { get; set; }
    public int DisplayOrder { get; set; }
}

public class PlaylistSongRequestDto
{
    [Required]
    public int PlaylistId { get; set; }

    [Required]
    public int SongId { get; set; }

    [Range(0, int.MaxValue)]
    public int DisplayOrder { get; set; }
}

