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
    public async Task<ActionResult<IEnumerable<SongDto>>> GetAll()
    {
        var songs = await _db.Songs
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        return Ok(songs.Select(x => x.ToDto()));
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


