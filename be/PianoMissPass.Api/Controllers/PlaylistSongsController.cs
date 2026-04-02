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
public class PlaylistSongsController : ControllerBase
{
    private readonly AppDbContext _db;

    public PlaylistSongsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<PlaylistSongDto>>> GetAll()
    {
        var items = await _db.PlaylistSongs.OrderBy(x => x.DisplayOrder).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{playlistId:int}/{songId:int}")]
    public async Task<ActionResult<PlaylistSongDto>> GetById(int playlistId, int songId)
    {
        var item = await _db.PlaylistSongs.FindAsync(playlistId, songId);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<PlaylistSongDto>> Create([FromBody] PlaylistSongRequestDto request)
    {
        var playlistExists = await _db.Playlists.AnyAsync(x => x.Id == request.PlaylistId);
        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        if (!playlistExists || !songExists) return BadRequest("playlistId or songId does not exist.");

        var exists = await _db.PlaylistSongs.AnyAsync(x => x.PlaylistId == request.PlaylistId && x.SongId == request.SongId);
        if (exists) return Conflict("PlaylistSong already exists.");

        var orderTaken = await _db.PlaylistSongs.AnyAsync(x => x.PlaylistId == request.PlaylistId && x.DisplayOrder == request.DisplayOrder);
        if (orderTaken) return Conflict("displayOrder already exists in this playlist.");

        var item = new PlaylistSong
        {
            PlaylistId = request.PlaylistId,
            SongId = request.SongId,
            DisplayOrder = request.DisplayOrder
        };

        _db.PlaylistSongs.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { playlistId = item.PlaylistId, songId = item.SongId }, item.ToDto());
    }

    [HttpPut("{playlistId:int}/{songId:int}")]
    public async Task<IActionResult> Update(int playlistId, int songId, [FromBody] PlaylistSongRequestDto request)
    {
        var item = await _db.PlaylistSongs.FindAsync(playlistId, songId);
        if (item is null) return NotFound();

        var playlistExists = await _db.Playlists.AnyAsync(x => x.Id == request.PlaylistId);
        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        if (!playlistExists || !songExists) return BadRequest("playlistId or songId does not exist.");

        var orderTaken = await _db.PlaylistSongs.AnyAsync(x =>
            (x.PlaylistId != playlistId || x.SongId != songId) &&
            x.PlaylistId == request.PlaylistId &&
            x.DisplayOrder == request.DisplayOrder);
        if (orderTaken) return Conflict("displayOrder already exists in this playlist.");

        item.PlaylistId = request.PlaylistId;
        item.SongId = request.SongId;
        item.DisplayOrder = request.DisplayOrder;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{playlistId:int}/{songId:int}")]
    public async Task<IActionResult> Delete(int playlistId, int songId)
    {
        var item = await _db.PlaylistSongs.FindAsync(playlistId, songId);
        if (item is null) return NotFound();

        _db.PlaylistSongs.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


