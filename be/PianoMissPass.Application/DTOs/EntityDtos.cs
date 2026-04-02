using System.ComponentModel.DataAnnotations;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.DTOs;

public class UserDto
{
    public string Id { get; set; }
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
    public string Id { get; set; }
    public string ArtistId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Composer { get; set; }
    public string? ImageUrl { get; set; }
    public int PlayCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class SongDetailDto
{
    public string Id { get; set; }
    public string ArtistId { get; set; }
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
    public string Id { get; set; }
    public string SongId { get; set; }
    public string InstrumentId { get; set; }
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
    public string ArtistId { get; set; }

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
    public string Id { get; set; }
    public string SongId { get; set; }
    public string InstrumentId { get; set; }
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
    public string SongId { get; set; }

    [Required]
    public string InstrumentId { get; set; }

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
    public string Id { get; set; }
    public string? SheetId { get; set; }
    public string? SongId { get; set; }
    public string? UserId { get; set; }
    public DataAssetType AssetType { get; set; }
    public string Url { get; set; } = string.Empty;
    public string? PublicId { get; set; }
    public int DisplayOrder { get; set; }
}

public class DataAssetRequestDto
{
    public string? SheetId { get; set; }
    public string? SongId { get; set; }
    public string? UserId { get; set; }

    public DataAssetType AssetType { get; set; } = DataAssetType.File;

    [Required, StringLength(500)]
    public string Url { get; set; } = string.Empty;

    [StringLength(255)]
    public string? PublicId { get; set; }

    public int DisplayOrder { get; set; }
}

public class InstrumentDto
{
    public string Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class InstrumentRequestDto
{
    [Required, StringLength(100)]
    public string Name { get; set; } = string.Empty;
}

public class UserSheetPointDto
{
    public string Id { get; set; }
    public string SheetId { get; set; }
    public string PlayerId { get; set; }
    public int Point { get; set; }
}

public class UserSheetPointRequestDto
{
    [Required]
    public string SheetId { get; set; }

    [Required]
    public string PlayerId { get; set; }

    public int Point { get; set; }
}

public class UserSheetLikeDto
{
    public string UserId { get; set; }
    public string SheetId { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UserSheetLikeRequestDto
{
    [Required]
    public string UserId { get; set; }

    [Required]
    public string SheetId { get; set; }
}

public class GenreDto
{
    public string Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public class GenreRequestDto
{
    [Required, StringLength(100)]
    public string Name { get; set; } = string.Empty;
}

public class GenreSongDto
{
    public string GenreId { get; set; }
    public string SongId { get; set; }
}

public class GenreSongRequestDto
{
    [Required]
    public string GenreId { get; set; }

    [Required]
    public string SongId { get; set; }
}

public class UserFavoriteSongDto
{
    public string UserId { get; set; }
    public string SongId { get; set; }
}

public class UserFavoriteSongRequestDto
{
    [Required]
    public string UserId { get; set; }

    [Required]
    public string SongId { get; set; }
}

public class PlaylistDto
{
    public string Id { get; set; }
    public string UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class PlaylistRequestDto
{
    [Required]
    public string UserId { get; set; }

    [Required, StringLength(255)]
    public string Name { get; set; } = string.Empty;
}

public class PlaylistSongDto
{
    public string PlaylistId { get; set; }
    public string SongId { get; set; }
    public int DisplayOrder { get; set; }
}

public class PlaylistSongRequestDto
{
    [Required]
    public string PlaylistId { get; set; }

    [Required]
    public string SongId { get; set; }

    [Range(0, int.MaxValue)]
    public int DisplayOrder { get; set; }
}

