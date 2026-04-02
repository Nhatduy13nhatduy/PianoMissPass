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
    public async Task<ActionResult<IEnumerable<PlaylistDto>>> GetAll()
    {
        var playlists = await _db.Playlists
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        return Ok(playlists.Select(x => x.ToDto()));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<PlaylistDto>> GetById(int id)
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

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] PlaylistRequestDto request)
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

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
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


