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
public class GenreSongsController : ControllerBase
{
    private readonly AppDbContext _db;

    public GenreSongsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<GenreSongDto>>> GetAll()
    {
        var items = await _db.GenreSongs.ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{genreId:int}/{songId:int}")]
    public async Task<ActionResult<GenreSongDto>> GetById(string genreId, string songId)
    {
        var item = await _db.GenreSongs.FindAsync(genreId, songId);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<GenreSongDto>> Create([FromBody] GenreSongRequestDto request)
    {
        var genreExists = await _db.Genres.AnyAsync(x => x.Id == request.GenreId);
        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        if (!genreExists || !songExists) return BadRequest("genreId or songId does not exist.");

        var exists = await _db.GenreSongs.AnyAsync(x => x.GenreId == request.GenreId && x.SongId == request.SongId);
        if (exists) return Conflict("GenreSong already exists.");

        var item = new GenreSong { GenreId = request.GenreId, SongId = request.SongId };
        _db.GenreSongs.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { genreId = item.GenreId, songId = item.SongId }, item.ToDto());
    }

    [HttpDelete("{genreId:int}/{songId:int}")]
    public async Task<IActionResult> Delete(string genreId, string songId)
    {
        var item = await _db.GenreSongs.FindAsync(genreId, songId);
        if (item is null) return NotFound();

        _db.GenreSongs.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


