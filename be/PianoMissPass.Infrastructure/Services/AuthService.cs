using Microsoft.EntityFrameworkCore;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Application.DTOs;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Domain.Exceptions;
using PianoMissPass.Domain.Entities;
using System.Security.Cryptography;

namespace PianoMissPass.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly AppDbContext _db;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;

    public AuthService(AppDbContext db, IPasswordHasher passwordHasher, IJwtTokenService jwtTokenService)
    {
        _db = db;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request, CancellationToken cancellationToken = default)
    {
        var exists = await _db.Users.AnyAsync(x => x.Email == request.Email, cancellationToken);
        if (exists)
        {
            throw new AppException("Email already exists.", 409);
        }

        var now = DateTime.UtcNow;
        var user = new User
        {
            UserName = request.UserName,
            Email = request.Email,
            Password = _passwordHasher.Hash(request.Password),
            AvatarUrl = request.AvatarUrl,
            Role = UserRole.User,
            CreatedAt = now,
            UpdatedAt = now
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync(cancellationToken);

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    public async Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == request.Email, cancellationToken);
        if (user is null || !_passwordHasher.Verify(request.Password, user.Password))
        {
            throw new AppException("Invalid email or password.", 401);
        }

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    public async Task<AuthResponseDto> RefreshAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default)
    {
        var current = await _db.RefreshTokens
            .Include(x => x.User)
            .FirstOrDefaultAsync(x => x.Token == request.RefreshToken, cancellationToken);

        if (current is null || current.RevokedAt.HasValue || current.ExpiresAt <= DateTime.UtcNow || current.User is null)
        {
            throw new AppException("Invalid refresh token.", 401);
        }

        current.RevokedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        return await BuildAuthResponseAsync(current.User, cancellationToken);
    }

    public async Task RevokeRefreshTokenAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default)
    {
        var current = await _db.RefreshTokens.FirstOrDefaultAsync(x => x.Token == request.RefreshToken, cancellationToken);
        if (current is null)
        {
            return;
        }

        current.RevokedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
    }

    private async Task<AuthResponseDto> BuildAuthResponseAsync(User user, CancellationToken cancellationToken)
    {
        var token = _jwtTokenService.GenerateToken(user);
        var refreshToken = new RefreshToken
        {
            UserId = user.Id,
            Token = GenerateRefreshToken(),
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(14)
        };

        _db.RefreshTokens.Add(refreshToken);
        await _db.SaveChangesAsync(cancellationToken);

        return new AuthResponseDto
        {
            AccessToken = token.Token,
            RefreshToken = refreshToken.Token,
            ExpiresAtUtc = token.ExpiresAtUtc,
            User = new UserDto
            {
                Id = user.Id,
                UserName = user.UserName,
                Email = user.Email,
                AvatarUrl = user.AvatarUrl,
                Role = user.Role,
                CreatedAt = user.CreatedAt,
                UpdatedAt = user.UpdatedAt
            }
        };
    }

    private static string GenerateRefreshToken()
    {
        return Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    }
}

