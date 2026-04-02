using System.ComponentModel.DataAnnotations;

namespace PianoMissPass.Application.DTOs;

public class PaginationQueryDto
{
    [Range(1, int.MaxValue)]
    public int Page { get; set; } = 1;

    [Range(1, 100)]
    public int PageSize { get; set; } = 10;
}

public class PagedResultDto<T>
{
    public IReadOnlyList<T> Items { get; set; } = Array.Empty<T>();
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalItems { get; set; }
    public int TotalPages { get; set; }
}

public class SongListQueryDto : PaginationQueryDto
{
    public string? Search { get; set; }
    public string? Sort { get; set; } = "updated_desc";
}

public class SheetListQueryDto : PaginationQueryDto
{
    public string? Search { get; set; }
    public string? Sort { get; set; } = "updated_desc";
}

public class UserListQueryDto : PaginationQueryDto
{
    public string? Search { get; set; }
    public string? Sort { get; set; } = "updated_desc";
}

public class PlaylistListQueryDto : PaginationQueryDto
{
    public string? Search { get; set; }
    public string? Sort { get; set; } = "updated_desc";
}
