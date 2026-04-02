using PianoMissPass.Application.DTOs;

namespace PianoMissPass.Application.Abstractions;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request, CancellationToken cancellationToken = default);
    Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default);
    Task<AuthResponseDto> RefreshAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default);
    Task RevokeRefreshTokenAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default);
}

