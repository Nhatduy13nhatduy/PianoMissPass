using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Application.DTOs;

namespace PianoMissPass.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _authService.RegisterAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _authService.LoginAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> Refresh([FromBody] RefreshTokenRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _authService.RefreshAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("revoke")]
    [AllowAnonymous]
    public async Task<IActionResult> Revoke([FromBody] RefreshTokenRequestDto request, CancellationToken cancellationToken)
    {
        await _authService.RevokeRefreshTokenAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("verify-email")]
    [AllowAnonymous]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequestDto request, CancellationToken cancellationToken)
    {
        await _authService.VerifyEmailAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("resend-verification")]
    [AllowAnonymous]
    public async Task<IActionResult> ResendVerification([FromBody] ResendVerificationCodeRequestDto request, CancellationToken cancellationToken)
    {
        await _authService.ResendVerificationCodeAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto request, CancellationToken cancellationToken)
    {
        await _authService.ForgotPasswordAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequestDto request, CancellationToken cancellationToken)
    {
        await _authService.ResetPasswordAsync(request, cancellationToken);
        return NoContent();
    }

    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequestDto request, CancellationToken cancellationToken)
    {
        var userIdRaw = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdRaw, out var userId))
        {
            return Unauthorized();
        }

        await _authService.ChangePasswordAsync(userId, request, cancellationToken);
        return NoContent();
    }
}

