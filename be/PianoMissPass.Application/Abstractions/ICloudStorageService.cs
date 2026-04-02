namespace PianoMissPass.Application.Abstractions;

public interface ICloudStorageService
{
    Task<CloudStorageUploadResult> UploadAsync(Stream stream, string fileName, string? contentType, CancellationToken cancellationToken = default);
    Task DeleteAsync(string? publicId, string? url, CancellationToken cancellationToken = default);
}

public sealed record CloudStorageUploadResult(string Url, string? PublicId);
