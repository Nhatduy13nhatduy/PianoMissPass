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
public class SheetAssetsController : ControllerBase
{
    private readonly AppDbContext _db;

    public SheetAssetsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<SheetAssetDto>>> GetAll()
    {
        var items = await _db.SheetAssets.OrderBy(x => x.DisplayOrder).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<SheetAssetDto>> GetById(int id)
    {
        var item = await _db.SheetAssets.FindAsync(id);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<SheetAssetDto>> Create([FromBody] SheetAssetRequestDto request)
    {
        var sheetExists = await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        if (!sheetExists) return BadRequest("sheetId does not exist.");

        var item = new SheetAsset
        {
            SheetId = request.SheetId,
            AssetType = request.AssetType,
            Url = request.Url,
            DisplayOrder = request.DisplayOrder
        };

        _db.SheetAssets.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] SheetAssetRequestDto request)
    {
        var item = await _db.SheetAssets.FindAsync(id);
        if (item is null) return NotFound();

        var sheetExists = await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        if (!sheetExists) return BadRequest("sheetId does not exist.");

        item.SheetId = request.SheetId;
        item.AssetType = request.AssetType;
        item.Url = request.Url;
        item.DisplayOrder = request.DisplayOrder;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await _db.SheetAssets.FindAsync(id);
        if (item is null) return NotFound();

        _db.SheetAssets.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


