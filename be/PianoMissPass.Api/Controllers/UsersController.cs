using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Application.DTOs;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Api.Controllers;

[Authorize(Policy = "AdminOnly")]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IPasswordHasher _passwordHasher;

    public UsersController(AppDbContext db, IPasswordHasher passwordHasher)
    {
        _db = db;
        _passwordHasher = passwordHasher;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResultDto<UserDto>>> GetAll([FromQuery] UserListQueryDto query)
    {
        var usersQuery = _db.Users.AsNoTracking().Include(x => x.DataAssets).AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            usersQuery = usersQuery.Where(x => x.UserName.Contains(search) || x.Email.Contains(search));
        }

        usersQuery = (query.Sort ?? "updated_desc").ToLowerInvariant() switch
        {
            "title_asc" => usersQuery.OrderBy(x => x.UserName),
            "title_desc" => usersQuery.OrderByDescending(x => x.UserName),
            "updated_asc" => usersQuery.OrderBy(x => x.UpdatedAt),
            "updated_desc" => usersQuery.OrderByDescending(x => x.UpdatedAt),
            _ => usersQuery.OrderByDescending(x => x.UpdatedAt)
        };

        var totalItems = await usersQuery.CountAsync();
        var totalPages = (int)Math.Ceiling(totalItems / (double)query.PageSize);
        var users = await usersQuery
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync();

        return Ok(new PagedResultDto<UserDto>
        {
            Items = users.Select(x => x.ToDto()).ToList(),
            Page = query.Page,
            PageSize = query.PageSize,
            TotalItems = totalItems,
            TotalPages = totalPages
        });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<UserDto>> GetById(string id)
    {
        var user = await _db.Users
            .AsNoTracking()
            .Include(x => x.DataAssets)
            .FirstOrDefaultAsync(x => x.Id == id);
        if (user is null)
        {
            return NotFound();
        }

        return Ok(user.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<UserDto>> Create([FromBody] UserCreateRequestDto request)
    {
        var user = new User
        {
            UserName = request.UserName,
            Email = request.Email,
            Password = _passwordHasher.Hash(request.Password),
            Role = request.Role
        };

        var now = DateTime.UtcNow;
        user.CreatedAt = now;
        user.UpdatedAt = now;

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        if (!string.IsNullOrWhiteSpace(request.AvatarUrl))
        {
            _db.DataAssets.Add(new DataAsset
            {
                UserId = user.Id,
                AssetType = DataAssetType.ImageAvatar,
                Url = request.AvatarUrl,
                DisplayOrder = 1
            });
            await _db.SaveChangesAsync();
        }

        return CreatedAtAction(nameof(GetById), new { id = user.Id }, user.ToDto());
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] UserUpdateRequestDto request)
    {
        var user = await _db.Users.FindAsync(id);
        if (user is null)
        {
            return NotFound();
        }

        user.UserName = request.UserName;
        user.Email = request.Email;
        user.Password = _passwordHasher.Hash(request.Password);
        user.Role = request.Role;
        user.UpdatedAt = DateTime.UtcNow;

        var existingAvatar = await _db.DataAssets
            .Where(x => x.UserId == user.Id && x.AssetType == DataAssetType.ImageAvatar)
            .OrderByDescending(x => x.Id)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(request.AvatarUrl))
        {
            if (existingAvatar is not null)
            {
                _db.DataAssets.Remove(existingAvatar);
            }
        }
        else if (existingAvatar is null)
        {
            _db.DataAssets.Add(new DataAsset
            {
                UserId = user.Id,
                AssetType = DataAssetType.ImageAvatar,
                Url = request.AvatarUrl,
                DisplayOrder = 1
            });
        }
        else
        {
            existingAvatar.Url = request.AvatarUrl;
        }

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var user = await _db.Users.FindAsync(id);
        if (user is null)
        {
            return NotFound();
        }

        _db.Users.Remove(user);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPatch("{id}/role")]
    public async Task<ActionResult<UserDto>> UpdateRole(string id, [FromBody] UpdateUserRoleRequestDto request)
    {
        var user = await _db.Users.FindAsync(id);
        if (user is null)
        {
            return NotFound();
        }

        user.Role = request.Role;
        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(user.ToDto());
    }
}


