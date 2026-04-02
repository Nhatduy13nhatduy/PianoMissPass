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

    [HttpGet("{id:int}")]
    public async Task<ActionResult<SongDto>> GetById(int id)
    {
        var song = await _db.Songs.FirstOrDefaultAsync(x => x.Id == id);

        if (song is null)
        {
            return NotFound();
        }

        return Ok(song.ToDto());
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

        return CreatedAtAction(nameof(GetById), new { id = song.Id }, song.ToDto());
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] SongRequestDto request)
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

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
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


