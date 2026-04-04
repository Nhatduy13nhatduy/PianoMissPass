using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Infrastructure.Email;
using PianoMissPass.Infrastructure.Security;
using PianoMissPass.Infrastructure.Services;
using PianoMissPass.Infrastructure.Storage;

namespace PianoMissPass.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

        services.AddScoped<IPasswordHasher, PasswordHasher>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<ICloudStorageService, CloudinaryStorageService>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IMusicXmlChartService, MusicXmlChartService>();

        return services;
    }
}

