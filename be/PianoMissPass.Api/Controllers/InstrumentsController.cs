using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PianoMissPass.Application.DTOs;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Api.Controllers;

[Authorize(Policy = "AdminOnly")]
[ApiController]
[Route("api/[controller]")]
public class InstrumentsController : ControllerBase
{
    private readonly AppDbContext _db;

    public InstrumentsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<InstrumentDto>>> GetAll()
    {
        var items = await _db.Instruments.OrderBy(x => x.Name).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<InstrumentDto>> GetById(int id)
    {
        var item = await _db.Instruments.FindAsync(id);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<InstrumentDto>> Create([FromBody] InstrumentRequestDto request)
    {
        var item = new Instrument { Name = request.Name };
        _db.Instruments.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] InstrumentRequestDto request)
    {
        var item = await _db.Instruments.FindAsync(id);
        if (item is null) return NotFound();

        item.Name = request.Name;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await _db.Instruments.FindAsync(id);
        if (item is null) return NotFound();

        _db.Instruments.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


