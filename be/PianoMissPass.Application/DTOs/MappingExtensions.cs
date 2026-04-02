using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.DTOs;

public static class MappingExtensions
{
    public static UserDto ToDto(this User entity) => new()
    {
        Id = entity.Id,
        UserName = entity.UserName,
        Email = entity.Email,
        AvatarUrl = entity.DataAssets
            .Where(x => x.UserId == entity.Id && x.AssetType == DataAssetType.ImageAvatar)
            .OrderByDescending(x => x.Id)
            .Select(x => x.Url)
            .FirstOrDefault(),
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
        ImageUrl = entity.DataAssets
            .Where(x => x.SongId == entity.Id && x.AssetType == DataAssetType.ImageSongCover)
            .OrderByDescending(x => x.Id)
            .Select(x => x.Url)
            .FirstOrDefault(),
        PlayCount = entity.PlayCount,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static SongDetailDto ToDetailDto(this Song entity) => new()
    {
        Id = entity.Id,
        ArtistId = entity.ArtistId,
        Title = entity.Title,
        Composer = entity.Composer,
        ImageUrl = entity.DataAssets
            .Where(x => x.SongId == entity.Id && x.AssetType == DataAssetType.ImageSongCover)
            .OrderByDescending(x => x.Id)
            .Select(x => x.Url)
            .FirstOrDefault(),
        PlayCount = entity.PlayCount,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt,
        Genres = entity.GenreSongs
            .Where(x => x.Genre is not null)
            .Select(x => x.Genre!.ToDto())
            .ToList(),
        Instruments = entity.Sheets
            .Where(x => x.Instrument is not null)
            .Select(x => x.Instrument!)
            .DistinctBy(x => x.Id)
            .Select(x => x.ToDto())
            .ToList(),
        Sheets = entity.Sheets
            .OrderBy(x => x.Id)
            .Select(x => new SongDetailSheetDto
            {
                Id = x.Id,
                SongId = x.SongId,
                InstrumentId = x.InstrumentId,
                Name = x.Name,
                LeftData = x.LeftData,
                RightData = x.RightData,
                LikeCount = x.LikeCount,
                CreatedAt = x.CreatedAt,
                UpdatedAt = x.UpdatedAt,
                Instrument = x.Instrument?.ToDto(),
                DataAssets = x.DataAssets
                    .OrderBy(a => a.DisplayOrder)
                    .ThenBy(a => a.Id)
                    .Select(a => a.ToDto())
                    .ToList(),
                UserSheetLikes = x.UserSheetLikes
                    .OrderByDescending(l => l.CreatedAt)
                    .Select(l => l.ToDto())
                    .ToList(),
                UserSheetPoints = x.UserSheetPoints
                    .OrderByDescending(p => p.Point)
                    .ThenBy(p => p.Id)
                    .Select(p => p.ToDto())
                    .ToList()
            })
            .ToList()
    };

    public static SheetDto ToDto(this Sheet entity) => new()
    {
        Id = entity.Id,
        SongId = entity.SongId,
        InstrumentId = entity.InstrumentId,
        Name = entity.Name,
        LeftData = entity.LeftData,
        RightData = entity.RightData,
        LikeCount = entity.LikeCount,
        CreatedAt = entity.CreatedAt,
        UpdatedAt = entity.UpdatedAt
    };

    public static DataAssetDto ToDto(this DataAsset entity) => new()
    {
        Id = entity.Id,
        SheetId = entity.SheetId,
        SongId = entity.SongId,
        UserId = entity.UserId,
        AssetType = entity.AssetType,
        Url = entity.Url,
        PublicId = entity.PublicId,
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

