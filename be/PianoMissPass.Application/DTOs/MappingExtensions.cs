using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.DTOs;

public static class MappingExtensions
{
    public static UserDto ToDto(this User entity) => new()
    {
        Id = entity.Id,
        UserName = entity.UserName,
        Email = entity.Email,
        AvatarUrl = entity.AvatarUrl,
        Role = entity.Role,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static SongDto ToDto(this Song entity) => new()
    {
        Id = entity.Id,
        ArtistId = entity.ArtistId,
        Title = entity.Title,
        Composer = entity.Composer,
        PlayCount = entity.PlayCount,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static SheetDto ToDto(this Sheet entity) => new()
    {
        Id = entity.Id,
        SongId = entity.SongId,
        InstrumentId = entity.InstrumentId,
        Name = entity.Name,
        LikeCount = entity.LikeCount,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static SheetAssetDto ToDto(this SheetAsset entity) => new()
    {
        Id = entity.Id,
        SheetId = entity.SheetId,
        AssetType = entity.AssetType,
        Url = entity.Url,
        DisplayOrder = entity.DisplayOrder
    };

    public static InstrumentDto ToDto(this Instrument entity) => new()
    {
        Id = entity.Id,
        Name = entity.Name
    };

    public static UserSheetPointDto ToDto(this UserSheetPoint entity) => new()
    {
        Id = entity.Id,
        SheetId = entity.SheetId,
        PlayerId = entity.PlayerId,
        Point = entity.Point
    };

    public static UserSheetLikeDto ToDto(this UserSheetLike entity) => new()
    {
        UserId = entity.UserId,
        SheetId = entity.SheetId,
        CreatedAt = entity.CreatedAt
    };

    public static GenreDto ToDto(this Genre entity) => new()
    {
        Id = entity.Id,
        Name = entity.Name
    };

    public static GenreSongDto ToDto(this GenreSong entity) => new()
    {
        GenreId = entity.GenreId,
        SongId = entity.SongId
    };

    public static UserFavoriteSongDto ToDto(this UserFavoriteSong entity) => new()
    {
        UserId = entity.UserId,
        SongId = entity.SongId
    };

    public static PlaylistDto ToDto(this Playlist entity) => new()
    {
        Id = entity.Id,
        UserId = entity.UserId,
        Name = entity.Name,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static PlaylistSongDto ToDto(this PlaylistSong entity) => new()
    {
        PlaylistId = entity.PlaylistId,
        SongId = entity.SongId,
        DisplayOrder = entity.DisplayOrder
    };
}

