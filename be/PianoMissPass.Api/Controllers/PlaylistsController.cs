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
public class PlaylistsController : ControllerBase
{
    private readonly AppDbContext _db;

    public PlaylistsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<PlaylistDto>>> GetAll([FromQuery] PlaylistListQueryDto query)
    {
        var playlistsQuery = _db.Playlists.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            playlistsQuery = playlistsQuery.Where(x => x.Name.Contains(search));
        }

        playlistsQuery = (query.Sort ?? "updated_desc").ToLowerInvariant() switch
        {
            "title_asc" => playlistsQuery.OrderBy(x => x.Name),
            "title_desc" => playlistsQuery.OrderByDescending(x => x.Name),
            "updated_asc" => playlistsQuery.OrderBy(x => x.UpdatedAt),
            "updated_desc" => playlistsQuery.OrderByDescending(x => x.UpdatedAt),
            _ => playlistsQuery.OrderByDescending(x => x.UpdatedAt)
        };

        var totalItems = await playlistsQuery.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)query.PageSize);
        var playlists = await playlistsQuery
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Ok(new PagedResultDto<PlaylistDto>
        {
            Items = playlists.Select(x => x.ToDto()).ToList(),
            Page = query.Page,
            PageSize = query.PageSize,
            TotalItems = totalItems,
            TotalPages = totalPages
        });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<PlaylistDto>> GetById(string id)
    {
        var playlist = await _db.Playlists.FirstOrDefaultAsync(x => x.Id == id);

        if (playlist is null)
        {
            return NotFound();
        }

        return Ok(playlist.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<PlaylistDto>> Create([FromBody] PlaylistRequestDto request)
    {
        var userExists = await _db.Users.AnyAsync(x => x.Id == request.UserId);
        if (!userExists)
        {
            return BadRequest("userId does not exist.");
        }

        var playlist = new Playlist
        {
            UserId = request.UserId,
            Name = request.Name
        };

        var now = DateTime.UtcNow;
        playlist.CreatedAt = now;
        playlist.UpdatedAt = now;

        _db.Playlists.Add(playlist);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = playlist.Id }, playlist.ToDto());
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] PlaylistRequestDto request)
    {
        var playlist = await _db.Playlists.FindAsync(id);
        if (playlist is null)
        {
            return NotFound();
        }

        var userExists = await _db.Users.AnyAsync(x => x.Id == request.UserId);
        if (!userExists)
        {
            return BadRequest("userId does not exist.");
        }

        playlist.UserId = request.UserId;
        playlist.Name = request.Name;
        playlist.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var playlist = await _db.Playlists.FindAsync(id);
        if (playlist is null)
        {
            return NotFound();
        }

        _db.Playlists.Remove(playlist);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


