using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.Abstractions;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAtUtc) GenerateToken(User user);
}

