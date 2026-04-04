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
public class GenresController : ControllerBase
{
    private readonly AppDbContext _db;

    public GenresController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<GenreDto>>> GetAll()
    {
        var items = await _db.Genres.OrderBy(x => x.Name).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<GenreDto>> GetById(string id)
    {
        var item = await _db.Genres.FindAsync(id);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<GenreDto>> Create([FromBody] GenreRequestDto request)
    {
        var item = new Genre { Name = request.Name };
        _db.Genres.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPut("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Update(string id, [FromBody] GenreRequestDto request)
    {
        var item = await _db.Genres.FindAsync(id);
        if (item is null) return NotFound();

        item.Name = request.Name;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Delete(string id)
    {
        var item = await _db.Genres.FindAsync(id);
        if (item is null) return NotFound();

        _db.Genres.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}


