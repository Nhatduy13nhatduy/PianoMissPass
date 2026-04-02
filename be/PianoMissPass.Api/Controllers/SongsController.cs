using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PianoMissPass.Application.DTOs;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Api.Controllers;

[Authorize(Policy = "UserOrAdmin")]
[ApiController]
[Route("api/[controller]")]
public class SongsController : ControllerBase
{
    private readonly AppDbContext _db;

    public SongsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<SongDto>>> GetAll([FromQuery] SongListQueryDto query)
    {
        var songsQuery = BuildSongsListQuery(query, includeDetails: false);

        var totalItems = await songsQuery.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)query.PageSize);

        var songs = await songsQuery
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Ok(new PagedResultDto<SongDto>
        {
            Items = songs.Select(x => x.ToDto()).ToList(),
            Page = query.Page,
            PageSize = query.PageSize,
            TotalItems = totalItems,
            TotalPages = totalPages
        });
    }

    [HttpGet("detail")]
    public async Task<ActionResult<PagedResultDto<SongDetailDto>>> GetAllDetail([FromQuery] SongListQueryDto query)
    {
        var songsQuery = BuildSongsListQuery(query, includeDetails: true);

        var totalItems = await songsQuery.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)query.PageSize);

        var songs = await songsQuery
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Ok(new PagedResultDto<SongDetailDto>
        {
            Items = songs.Select(x => x.ToDetailDto()).ToList(),
            Page = query.Page,
            PageSize = query.PageSize,
            TotalItems = totalItems,
            TotalPages = totalPages
        });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<SongDto>> GetById(string id)
    {
        var song = await _db.Songs
            .AsNoTracking()
            .Include(x => x.DataAssets)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (song is null)
        {
            return NotFound();
        }

        return Ok(song.ToDto());
    }

    [HttpGet("detail/{id}")]
    public async Task<ActionResult<SongDetailDto>> GetByIdDetail(string id)
    {
        var song = await _db.Songs
            .AsNoTracking()
            .Include(x => x.DataAssets)
            .Include(x => x.GenreSongs)
                .ThenInclude(x => x.Genre)
            .Include(x => x.Sheets)
                .ThenInclude(x => x.Instrument)
            .Include(x => x.Sheets)
                .ThenInclude(x => x.DataAssets)
            .Include(x => x.Sheets)
                .ThenInclude(x => x.UserSheetLikes)
            .Include(x => x.Sheets)
                .ThenInclude(x => x.UserSheetPoints)
            .AsSplitQuery()
            .FirstOrDefaultAsync(x => x.Id == id);

        if (song is null)
        {
            return NotFound();
        }

        return Ok(song.ToDetailDto());
    }

    private IQueryable<Song> BuildSongsListQuery(SongListQueryDto query, bool includeDetails)
    {
        var songsQuery = _db.Songs.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            songsQuery = songsQuery.Where(x => x.Title.Contains(search) || (x.Composer != null && x.Composer.Contains(search)));
        }

        songsQuery = (query.Sort ?? "updated_desc").ToLowerInvariant() switch
        {
            "title_asc" => songsQuery.OrderBy(x => x.Title),
            "title_desc" => songsQuery.OrderByDescending(x => x.Title),
            "updated_asc" => songsQuery.OrderBy(x => x.UpdatedAt),
            "updated_desc" => songsQuery.OrderByDescending(x => x.UpdatedAt),
            "play_asc" => songsQuery.OrderBy(x => x.PlayCount),
            "play_desc" => songsQuery.OrderByDescending(x => x.PlayCount),
            _ => songsQuery.OrderByDescending(x => x.UpdatedAt)
        };

        if (includeDetails)
        {
            songsQuery = songsQuery
                .Include(x => x.DataAssets)
                .Include(x => x.GenreSongs)
                .ThenInclude(x => x.Genre)
                .Include(x => x.Sheets)
                .ThenInclude(x => x.Instrument)
                .Include(x => x.Sheets)
                .ThenInclude(x => x.DataAssets)
                .Include(x => x.Sheets)
                .ThenInclude(x => x.UserSheetLikes)
                .Include(x => x.Sheets)
                .ThenInclude(x => x.UserSheetPoints)
                .AsSplitQuery();
        }
        else
        {
            songsQuery = songsQuery.Include(x => x.DataAssets);
        }

        return songsQuery;
    }

    [HttpPost]
    public async Task<ActionResult<SongDto>> Create([FromBody] SongRequestDto request)
    {
        var artistExists = await _db.Users.AnyAsync(x => x.Id == request.ArtistId);
        if (!artistExists)
        {
            return BadRequest("artistId does not exist.");
        }

        var song = new Song
        {
            ArtistId = request.ArtistId,
            Title = request.Title,
            Composer = request.Composer,
            PlayCount = request.PlayCount
        };

        var now = DateTime.UtcNow;
        song.CreatedAt = now;
        song.UpdatedAt = now;

        _db.Songs.Add(song);
        await _db.SaveChangesAsync();

        if (!string.IsNullOrWhiteSpace(request.ImageUrl))
        {
            _db.DataAssets.Add(new DataAsset
            {
                SongId = song.Id,
                AssetType = DataAssetType.ImageSongCover,
                Url = request.ImageUrl,
                DisplayOrder = 1
            });
            await _db.SaveChangesAsync();
        }

        return CreatedAtAction(nameof(GetById), new { id = song.Id }, song.ToDto());
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] SongRequestDto request)
    {
        var song = await _db.Songs.FindAsync(id);
        if (song is null)
        {
            return NotFound();
        }

        var artistExists = await _db.Users.AnyAsync(x => x.Id == request.ArtistId);
        if (!artistExists)
        {
            return BadRequest("artistId does not exist.");
        }

        song.ArtistId = request.ArtistId;
        song.Title = request.Title;
        song.Composer = request.Composer;
        song.PlayCount = request.PlayCount;
        song.UpdatedAt = DateTime.UtcNow;

        var existingCover = await _db.DataAssets
            .Where(x => x.SongId == song.Id && x.AssetType == DataAssetType.ImageSongCover)
            .OrderByDescending(x => x.Id)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(request.ImageUrl))
        {
            if (existingCover is not null)
            {
                _db.DataAssets.Remove(existingCover);
            }
        }
        else if (existingCover is null)
        {
            _db.DataAssets.Add(new DataAsset
            {
                SongId = song.Id,
                AssetType = DataAssetType.ImageSongCover,
                Url = request.ImageUrl,
                DisplayOrder = 1
            });
        }
        else
        {
            existingCover.Url = request.ImageUrl;
        }

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var song = await _db.Songs.FindAsync(id);
        if (song is null)
        {
            return NotFound();
        }

        _db.Songs.Remove(song);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


