using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Configuration;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Domain.Exceptions;
using System.Text.RegularExpressions;

namespace PianoMissPass.Infrastructure.Storage;

public class CloudinaryStorageService : ICloudStorageService
{
    private readonly Cloudinary _cloudinary;
    private readonly string _folder;

    public CloudinaryStorageService(IConfiguration configuration)
    {
        var cloudName = configuration["Cloudinary:CloudName"];
        var apiKey = configuration["Cloudinary:ApiKey"];
        var apiSecret = configuration["Cloudinary:ApiSecret"];
        _folder = configuration["Cloudinary:Folder"] ?? "pianomisspass";

        if (string.IsNullOrWhiteSpace(cloudName) || string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(apiSecret))
        {
            throw new AppException("Cloudinary is not configured. Please set Cloudinary:CloudName, Cloudinary:ApiKey, Cloudinary:ApiSecret.", 500);
        }

        var account = new Account(cloudName, apiKey, apiSecret);
        _cloudinary = new Cloudinary(account)
        {
            Api = { Secure = true }
        };
    }

    public async Task<CloudStorageUploadResult> UploadAsync(Stream stream, string fileName, string? contentType, CancellationToken cancellationToken = default)
    {
        var uploadParams = new RawUploadParams
        {
            File = new FileDescription(fileName, stream),
            Folder = _folder,
            UseFilename = true,
            UniqueFilename = true,
            Overwrite = false
        };

        cancellationToken.ThrowIfCancellationRequested();
        var result = await _cloudinary.UploadAsync(uploadParams);
        if (result.Error is not null || string.IsNullOrWhiteSpace(result.SecureUrl?.ToString()))
        {
            var message = result.Error?.Message ?? "Cloudinary upload failed.";
            throw new AppException(message, 502);
        }

        return new CloudStorageUploadResult(result.SecureUrl!.ToString(), result.PublicId);
    }

    public async Task DeleteAsync(string? publicId, string? url, CancellationToken cancellationToken = default)
    {
        var resolvedPublicId = string.IsNullOrWhiteSpace(publicId) ? ExtractPublicIdFromCloudinaryUrl(url) : publicId;
        if (string.IsNullOrWhiteSpace(resolvedPublicId))
        {
            return;
        }

        cancellationToken.ThrowIfCancellationRequested();
        var deleteParams = new DeletionParams(resolvedPublicId)
        {
            ResourceType = ResourceType.Raw,
            Invalidate = true
        };

        var result = await _cloudinary.DestroyAsync(deleteParams);
        if (result.Error is not null)
        {
            throw new AppException(result.Error.Message, 502);
        }

        var deleteResult = result.Result?.Trim().ToLowerInvariant();
        if (deleteResult is "ok" or "not found")
        {
            return;
        }

        throw new AppException("Cloudinary delete failed.", 502);
    }

    private static string? ExtractPublicIdFromCloudinaryUrl(string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !Uri.TryCreate(url, UriKind.Absolute, out var uri))
        {
            return null;
        }

        if (!uri.Host.Contains("res.cloudinary.com", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var absolutePath = uri.AbsolutePath;
        var uploadMarkerIndex = absolutePath.IndexOf("/upload/", StringComparison.OrdinalIgnoreCase);
        if (uploadMarkerIndex < 0)
        {
            return null;
        }

        var afterUpload = absolutePath[(uploadMarkerIndex + "/upload/".Length)..].Trim('/');
        if (string.IsNullOrWhiteSpace(afterUpload))
        {
            return null;
        }

        afterUpload = Regex.Replace(afterUpload, @"^v\d+/", string.Empty, RegexOptions.IgnoreCase);
        if (string.IsNullOrWhiteSpace(afterUpload))
        {
            return null;
        }

        var lastDotIndex = afterUpload.LastIndexOf('.');
        if (lastDotIndex > 0)
        {
            afterUpload = afterUpload[..lastDotIndex];
        }

        return afterUpload;
    }
}
