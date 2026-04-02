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
    private const int VerificationCodeLength = 6;
    private const int VerificationCodeTtlMinutes = 10;
    private const int ResendCooldownSeconds = 60;
    private const int MaxVerificationCodesPerHour = 5;
    private const int MaxFailedVerificationAttempts = 5;
    private const int FailedVerificationWindowMinutes = 10;
    private const int VerificationLockMinutes = 10;

    private readonly AppDbContext _db;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IEmailSender _emailSender;

    public AuthService(AppDbContext db, IPasswordHasher passwordHasher, IJwtTokenService jwtTokenService, IEmailSender emailSender)
    {
        _db = db;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
        _emailSender = emailSender;
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

        await CreateAndSendVerificationCodeAsync(user, enforceCooldown: false, cancellationToken);

        return new AuthResponseDto
        {
            AccessToken = string.Empty,
            RefreshToken = string.Empty,
            ExpiresAtUtc = DateTime.UtcNow,
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

    public async Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == request.Email, cancellationToken);
        if (user is null || !_passwordHasher.Verify(request.Password, user.Password))
        {
            throw new AppException("Invalid email or password.", 401);
        }

        if (!user.IsEmailVerified)
        {
            throw new AppException("Email is not verified. Please verify your email first.", 403);
        }

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    public async Task VerifyEmailAsync(VerifyEmailRequestDto request, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == request.Email, cancellationToken);
        if (user is null)
        {
            throw new AppException("User not found.", 404);
        }

        var now = DateTime.UtcNow;
        if (user.VerificationLockedUntilAt.HasValue && user.VerificationLockedUntilAt.Value > now)
        {
            var seconds = (int)Math.Ceiling((user.VerificationLockedUntilAt.Value - now).TotalSeconds);
            throw new AppException($"Too many invalid attempts. Try again in {seconds} seconds.", 429);
        }

        var code = await _db.EmailVerificationCodes
            .Where(x => x.UserId == user.Id && x.UsedAt == null)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

        if (code is null || code.ExpiresAt <= DateTime.UtcNow || !VerifyCode(request.Code, code.CodeSalt, code.CodeHash))
        {
            await RegisterFailedVerificationAttemptAsync(user, now, cancellationToken);
            throw new AppException("Invalid or expired verification code.", 400);
        }

        code.UsedAt = now;
        user.IsEmailVerified = true;
        user.UpdatedAt = now;
        user.VerificationFailedAttempts = 0;
        user.VerificationFailedWindowStartAt = null;
        user.VerificationLockedUntilAt = null;

        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task ResendVerificationCodeAsync(ResendVerificationCodeRequestDto request, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(x => x.Email == request.Email, cancellationToken);
        if (user is null)
        {
            return;
        }

        if (user.IsEmailVerified)
        {
            return;
        }

        var now = DateTime.UtcNow;
        if (user.VerificationLockedUntilAt.HasValue && user.VerificationLockedUntilAt.Value > now)
        {
            var seconds = (int)Math.Ceiling((user.VerificationLockedUntilAt.Value - now).TotalSeconds);
            throw new AppException($"Too many invalid attempts. Try again in {seconds} seconds.", 429);
        }

        await CreateAndSendVerificationCodeAsync(user, enforceCooldown: true, cancellationToken);
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

    private async Task CreateAndSendVerificationCodeAsync(User user, bool enforceCooldown, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        if (enforceCooldown)
        {
            var lastCodeTime = await _db.EmailVerificationCodes
                .Where(x => x.UserId == user.Id)
                .OrderByDescending(x => x.CreatedAt)
                .Select(x => (DateTime?)x.CreatedAt)
                .FirstOrDefaultAsync(cancellationToken);

            if (lastCodeTime.HasValue && (now - lastCodeTime.Value).TotalSeconds < ResendCooldownSeconds)
            {
                throw new AppException($"Please wait {ResendCooldownSeconds} seconds before requesting another code.", 429);
            }
        }

        var issuedInLastHour = await _db.EmailVerificationCodes
            .CountAsync(x => x.UserId == user.Id && x.CreatedAt >= now.AddHours(-1), cancellationToken);

        if (issuedInLastHour >= MaxVerificationCodesPerHour)
        {
            throw new AppException("Too many verification requests. Please try again later.", 429);
        }

        var code = RandomNumberGenerator.GetInt32(0, (int)Math.Pow(10, VerificationCodeLength)).ToString($"D{VerificationCodeLength}");
        var salt = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
        var hash = HashCode(code, salt);

        var entity = new EmailVerificationCode
        {
            UserId = user.Id,
            CodeHash = hash,
            CodeSalt = salt,
            CreatedAt = now,
            ExpiresAt = now.AddMinutes(VerificationCodeTtlMinutes)
        };

        _db.EmailVerificationCodes.Add(entity);
        await _db.SaveChangesAsync(cancellationToken);

                var subject = "PianoMissPass - Verify your email";
                var body = BuildVerificationEmailTemplate(user.UserName, code, VerificationCodeTtlMinutes);
                await _emailSender.SendAsync(user.Email, subject, body, isHtml: true, cancellationToken);
    }

        private static string HashCode(string code, string salt)
        {
                var bytes = Rfc2898DeriveBytes.Pbkdf2(code, Convert.FromBase64String(salt), 10_000, HashAlgorithmName.SHA256, 32);
                return Convert.ToBase64String(bytes);
        }

        private static bool VerifyCode(string code, string salt, string expectedHash)
        {
                var actualHash = HashCode(code, salt);
                return CryptographicOperations.FixedTimeEquals(Convert.FromBase64String(expectedHash), Convert.FromBase64String(actualHash));
        }

        private static string BuildVerificationEmailTemplate(string userName, string code, int expiresInMinutes)
        {
                return $"""
<!DOCTYPE html>
<html>
<head>
    <meta charset=\"UTF-8\" />
    <title>PianoMissPass Email Verification</title>
</head>
<body style=\"margin:0;padding:0;background:#f4f7fb;font-family:Segoe UI,Arial,sans-serif;\">
    <table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f4f7fb;padding:24px 0;\">
        <tr>
            <td align=\"center\">
                <table role=\"presentation\" width=\"560\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#ffffff;border-radius:14px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,0.08);\">
                    <tr>
                        <td style=\"background:linear-gradient(120deg,#0f172a,#1d4ed8);padding:22px 28px;color:#ffffff;font-size:20px;font-weight:700;\">PianoMissPass</td>
                    </tr>
                    <tr>
                        <td style=\"padding:28px;color:#0f172a;\">
                            <p style=\"margin:0 0 14px;font-size:16px;\">Hi {System.Net.WebUtility.HtmlEncode(userName)},</p>
                            <p style=\"margin:0 0 16px;font-size:15px;line-height:1.6;color:#334155;\">Use the verification code below to activate your account.</p>
                            <div style=\"text-align:center;margin:22px 0;\">
                                <span style=\"display:inline-block;background:#e0e7ff;color:#1e3a8a;font-size:34px;letter-spacing:8px;font-weight:800;padding:14px 20px;border-radius:10px;\">{code}</span>
                            </div>
                            <p style=\"margin:0 0 10px;font-size:14px;color:#64748b;\">This code expires in {expiresInMinutes} minutes.</p>
                            <p style=\"margin:0;font-size:13px;color:#94a3b8;\">If you did not create this account, you can ignore this email.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
""";
        }

    private async Task RegisterFailedVerificationAttemptAsync(User user, DateTime now, CancellationToken cancellationToken)
    {
        if (!user.VerificationFailedWindowStartAt.HasValue || (now - user.VerificationFailedWindowStartAt.Value).TotalMinutes > FailedVerificationWindowMinutes)
        {
            user.VerificationFailedWindowStartAt = now;
            user.VerificationFailedAttempts = 0;
        }

        user.VerificationFailedAttempts += 1;

        if (user.VerificationFailedAttempts >= MaxFailedVerificationAttempts)
        {
            user.VerificationLockedUntilAt = now.AddMinutes(VerificationLockMinutes);
            user.VerificationFailedAttempts = 0;
            user.VerificationFailedWindowStartAt = null;
        }

        user.UpdatedAt = now;
        await _db.SaveChangesAsync(cancellationToken);
    }
}

