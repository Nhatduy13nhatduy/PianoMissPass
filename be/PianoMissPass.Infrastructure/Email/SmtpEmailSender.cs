using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using PianoMissPass.Application.Abstractions;

namespace PianoMissPass.Infrastructure.Email;

public class SmtpEmailSender : IEmailSender
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(IConfiguration configuration, ILogger<SmtpEmailSender> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendAsync(string toEmail, string subject, string body, bool isHtml = false, CancellationToken cancellationToken = default)
    {
        var host = _configuration["Email:SmtpHost"];
        var portRaw = _configuration["Email:SmtpPort"];
        var username = _configuration["Email:SmtpUser"];
        var password = _configuration["Email:SmtpPass"];
        var fromEmail = _configuration["Email:From"] ?? username;

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(fromEmail) || string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
        {
            _logger.LogWarning("Email SMTP is not configured. Skipping send. To={ToEmail}, Subject={Subject}, Body={Body}", toEmail, subject, body);
            return;
        }

        var port = int.TryParse(portRaw, out var parsedPort) ? parsedPort : 587;

        using var client = new SmtpClient(host, port)
        {
            EnableSsl = true,
            Credentials = new NetworkCredential(username, password)
        };

        using var mail = new MailMessage(fromEmail, toEmail, subject, body)
        {
            IsBodyHtml = isHtml
        };

        cancellationToken.ThrowIfCancellationRequested();
        await client.SendMailAsync(mail);
    }
}
