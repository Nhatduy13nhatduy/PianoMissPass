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
    public async Task<ActionResult<PagedResultDto<SheetDto>>> GetAll([FromQuery] SheetListQueryDto query)
    {
        var sheetsQuery = _db.Sheets.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            sheetsQuery = sheetsQuery.Where(x => x.Name.Contains(search));
        }

        sheetsQuery = (query.Sort ?? "updated_desc").ToLowerInvariant() switch
        {
            "title_asc" => sheetsQuery.OrderBy(x => x.Name),
            "title_desc" => sheetsQuery.OrderByDescending(x => x.Name),
            "updated_asc" => sheetsQuery.OrderBy(x => x.UpdatedAt),
            "updated_desc" => sheetsQuery.OrderByDescending(x => x.UpdatedAt),
            "like_asc" => sheetsQuery.OrderBy(x => x.LikeCount),
            "like_desc" => sheetsQuery.OrderByDescending(x => x.LikeCount),
            _ => sheetsQuery.OrderByDescending(x => x.UpdatedAt)
        };

        var totalItems = await sheetsQuery.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)query.PageSize);

        var sheets = await sheetsQuery
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Ok(new PagedResultDto<SheetDto>
        {
            Items = sheets.Select(x => x.ToDto()).ToList(),
            Page = query.Page,
            PageSize = query.PageSize,
            TotalItems = totalItems,
            TotalPages = totalPages
        });
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
            LeftData = request.LeftData,
            RightData = request.RightData,
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
        sheet.LeftData = request.LeftData;
        sheet.RightData = request.RightData;
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


