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
public class UserSheetPointsController : ControllerBase
{
    private readonly AppDbContext _db;

    public UserSheetPointsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserSheetPointDto>>> GetAll()
    {
        var items = await _db.UserSheetPoints.OrderByDescending(x => x.Point).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<UserSheetPointDto>> GetById(int id)
    {
        var item = await _db.UserSheetPoints.FindAsync(id);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<UserSheetPointDto>> Create([FromBody] UserSheetPointRequestDto request)
    {
        var sheetExists = await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        var userExists = await _db.Users.AnyAsync(x => x.Id == request.PlayerId);
        if (!sheetExists || !userExists) return BadRequest("sheetId or playerId does not exist.");

        var duplicate = await _db.UserSheetPoints.AnyAsync(x => x.SheetId == request.SheetId && x.PlayerId == request.PlayerId);
        if (duplicate) return Conflict("This player already has a point for this sheet.");

        var item = new UserSheetPoint
        {
            SheetId = request.SheetId,
            PlayerId = request.PlayerId,
            Point = request.Point
        };

        _db.UserSheetPoints.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UserSheetPointRequestDto request)
    {
        var item = await _db.UserSheetPoints.FindAsync(id);
        if (item is null) return NotFound();

        var sheetExists = await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        var userExists = await _db.Users.AnyAsync(x => x.Id == request.PlayerId);
        if (!sheetExists || !userExists) return BadRequest("sheetId or playerId does not exist.");

        var duplicate = await _db.UserSheetPoints.AnyAsync(x => x.Id != id && x.SheetId == request.SheetId && x.PlayerId == request.PlayerId);
        if (duplicate) return Conflict("This player already has a point for this sheet.");

        item.SheetId = request.SheetId;
        item.PlayerId = request.PlayerId;
        item.Point = request.Point;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await _db.UserSheetPoints.FindAsync(id);
        if (item is null) return NotFound();

        _db.UserSheetPoints.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


