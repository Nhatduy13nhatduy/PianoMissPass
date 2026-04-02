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
public class SheetsController : ControllerBase
{
    private readonly AppDbContext _db;

    public SheetsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<SheetDto>>> GetAll()
    {
        var sheets = await _db.Sheets
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        return Ok(sheets.Select(x => x.ToDto()));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<SheetDto>> GetById(int id)
    {
        var sheet = await _db.Sheets.FirstOrDefaultAsync(x => x.Id == id);

        if (sheet is null)
        {
            return NotFound();
        }

        return Ok(sheet.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<SheetDto>> Create([FromBody] SheetRequestDto request)
    {
        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        var instrumentExists = await _db.Instruments.AnyAsync(x => x.Id == request.InstrumentId);
        if (!songExists || !instrumentExists)
        {
            return BadRequest("songId or instrumentId does not exist.");
        }

        var sheet = new Sheet
        {
            SongId = request.SongId,
            InstrumentId = request.InstrumentId,
            Name = request.Name,
            LikeCount = request.LikeCount
        };

        var now = DateTime.UtcNow;
        sheet.CreatedAt = now;
        sheet.UpdatedAt = now;

        _db.Sheets.Add(sheet);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = sheet.Id }, sheet.ToDto());
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] SheetRequestDto request)
    {
        var sheet = await _db.Sheets.FindAsync(id);
        if (sheet is null)
        {
            return NotFound();
        }

        var songExists = await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        var instrumentExists = await _db.Instruments.AnyAsync(x => x.Id == request.InstrumentId);
        if (!songExists || !instrumentExists)
        {
            return BadRequest("songId or instrumentId does not exist.");
        }

        sheet.SongId = request.SongId;
        sheet.InstrumentId = request.InstrumentId;
        sheet.Name = request.Name;
        sheet.LikeCount = request.LikeCount;
        sheet.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var sheet = await _db.Sheets.FindAsync(id);
        if (sheet is null)
        {
            return NotFound();
        }

        _db.Sheets.Remove(sheet);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


