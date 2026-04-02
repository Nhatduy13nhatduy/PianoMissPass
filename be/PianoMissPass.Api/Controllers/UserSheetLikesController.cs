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
public class UserSheetLikesController : ControllerBase
{
    private readonly AppDbContext _db;

    public UserSheetLikesController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserSheetLikeDto>>> GetAll()
    {
        var items = await _db.UserSheetLikes.OrderByDescending(x => x.CreatedAt).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{userId:int}/{sheetId:int}")]
    public async Task<ActionResult<UserSheetLikeDto>> GetById(string userId, string sheetId)
    {
        var item = await _db.UserSheetLikes.FindAsync(userId, sheetId);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<UserSheetLikeDto>> Create([FromBody] UserSheetLikeRequestDto request)
    {
        var userExists = await _db.Users.AnyAsync(x => x.Id == request.UserId);
        var sheetExists = await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        if (!userExists || !sheetExists) return BadRequest("userId or sheetId does not exist.");

        var exists = await _db.UserSheetLikes.AnyAsync(x => x.UserId == request.UserId && x.SheetId == request.SheetId);
        if (exists) return Conflict("Like already exists.");

        var item = new UserSheetLike
        {
            UserId = request.UserId,
            SheetId = request.SheetId,
            CreatedAt = DateTime.UtcNow
        };

        _db.UserSheetLikes.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { userId = item.UserId, sheetId = item.SheetId }, item.ToDto());
    }

    [HttpDelete("{userId:int}/{sheetId:int}")]
    public async Task<IActionResult> Delete(string userId, string sheetId)
    {
        var item = await _db.UserSheetLikes.FindAsync(userId, sheetId);
        if (item is null) return NotFound();

        _db.UserSheetLikes.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


