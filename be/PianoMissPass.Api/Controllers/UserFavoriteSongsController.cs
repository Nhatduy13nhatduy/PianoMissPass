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
public class UserFavoriteSongsController : ControllerBase
{
    private readonly AppDbContext _db;

    public UserFavoriteSongsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserFavoriteSongDto>>> GetAll()
    {
        var items = await _db.UserFavoriteSongs.ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{userId:int}/{songId:int}")]
    public async Task<ActionResult<UserFavoriteSongDto>> GetById(int userId, int songId)
    {
        var item = await _db.UserFavoriteSongs.FindAsync(userId, songId);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<UserFavoriteSongDto>> Create([FromBody] UserFavoriteSongRequestDto request)
    {
        var userExists = await _db.Users.AnyAsync(x => x.Id == request.UserId);
        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        if (!userExists || !songExists) return BadRequest("userId or songId does not exist.");

        var exists = await _db.UserFavoriteSongs.AnyAsync(x => x.UserId == request.UserId && x.SongId == request.SongId);
        if (exists) return Conflict("UserFavoriteSong already exists.");

        var item = new UserFavoriteSong { UserId = request.UserId, SongId = request.SongId };
        _db.UserFavoriteSongs.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { userId = item.UserId, songId = item.SongId }, item.ToDto());
    }

    [HttpDelete("{userId:int}/{songId:int}")]
    public async Task<IActionResult> Delete(int userId, int songId)
    {
        var item = await _db.UserFavoriteSongs.FindAsync(userId, songId);
        if (item is null) return NotFound();

        _db.UserFavoriteSongs.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


