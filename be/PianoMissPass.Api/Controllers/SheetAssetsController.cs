using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PianoMissPass.Application.Abstractions;
using PianoMissPass.Application.DTOs;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Api.Controllers;

[Authorize(Policy = "UserOrAdmin")]
[ApiController]
[Route("api/[controller]")]
public class DataAssetsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ICloudStorageService _cloudStorageService;
    private readonly IMusicXmlChartService _musicXmlChartService;

    public DataAssetsController(
        AppDbContext db,
        ICloudStorageService cloudStorageService,
        IMusicXmlChartService musicXmlChartService)
    {
        _db = db;
        _cloudStorageService = cloudStorageService;
        _musicXmlChartService = musicXmlChartService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<DataAssetDto>>> GetAll()
    {
        var items = await _db.DataAssets.OrderBy(x => x.DisplayOrder).ToListAsync();
        return Ok(items.Select(x => x.ToDto()));
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<DataAssetDto>> GetById(string id)
    {
        var item = await _db.DataAssets.FindAsync(id);
        if (item is null) return NotFound();
        return Ok(item.ToDto());
    }

    [HttpPost]
    public async Task<ActionResult<DataAssetDto>> Create([FromBody] DataAssetRequestDto request)
    {
        if (!HasSingleOwner(request)) return BadRequest("Exactly one of sheetId, songId, or userId must be provided.");
        if (!await OwnerExistsAsync(request)) return BadRequest("Referenced owner does not exist.");

        var item = new DataAsset
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = request.AssetType,
            Url = request.Url,
            PublicId = request.PublicId,
            DisplayOrder = request.DisplayOrder
        };

        _db.DataAssets.Add(item);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPost("upload")]
    public async Task<ActionResult<DataAssetDto>> Upload([FromForm] DataAssetUploadForm request, CancellationToken cancellationToken)
    {
        if (request.File is null || request.File.Length == 0)
        {
            return BadRequest("file is required.");
        }

        var ownerRequest = new DataAssetRequestDto
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = request.AssetType,
            Url = string.Empty,
            DisplayOrder = request.DisplayOrder
        };

        if (!HasSingleOwner(ownerRequest)) return BadRequest("Exactly one of sheetId, songId, or userId must be provided.");
        if (!await OwnerExistsAsync(ownerRequest)) return BadRequest("Referenced owner does not exist.");

        await using var stream = request.File.OpenReadStream();
        var uploadResult = await _cloudStorageService.UploadAsync(stream, request.File.FileName, request.File.ContentType, cancellationToken);

        var item = new DataAsset
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = request.AssetType,
            Url = uploadResult.Url,
            PublicId = uploadResult.PublicId,
            DisplayOrder = request.DisplayOrder
        };

        _db.DataAssets.Add(item);
        await _db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item.ToDto());
    }

    [HttpPost("upload/mxl")]
    [HttpPost("upload/musicxml")]
    public async Task<ActionResult<MusicXmlUploadResultDto>> UploadMusicXml([FromForm] MusicXmlUploadForm request, CancellationToken cancellationToken)
    {
        if (request.File is null || request.File.Length == 0)
        {
            return BadRequest("file is required.");
        }

        var fileName = request.File.FileName.Trim();
        if (!IsMxlFile(fileName))
        {
            return BadRequest("Only .mxl files are supported.");
        }

        var ownerRequest = new DataAssetRequestDto
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = DataAssetType.MusicXml,
            Url = string.Empty,
            DisplayOrder = request.DisplayOrder
        };

        if (!HasSingleOwner(ownerRequest)) return BadRequest("Exactly one of sheetId, songId, or userId must be provided.");
        if (!await OwnerExistsAsync(ownerRequest)) return BadRequest("Referenced owner does not exist.");

        await using var fileStream = request.File.OpenReadStream();
        var conversion = await _musicXmlChartService.ConvertToChartAsync(fileStream, fileName, cancellationToken);

        fileStream.Position = 0;
        var xmlUpload = await _cloudStorageService.UploadAsync(fileStream, request.File.FileName, request.File.ContentType ?? "application/vnd.recordare.musicxml", cancellationToken);

        var chartFileName = BuildChartFileName(fileName);
        await using var chartStream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(conversion.ChartJson));
        var chartUpload = await _cloudStorageService.UploadAsync(chartStream, chartFileName, "application/json", cancellationToken);

        var xmlAsset = new DataAsset
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = DataAssetType.MusicXml,
            Url = xmlUpload.Url,
            PublicId = xmlUpload.PublicId,
            DisplayOrder = request.DisplayOrder
        };

        var chartAsset = new DataAsset
        {
            SheetId = request.SheetId,
            SongId = request.SongId,
            UserId = request.UserId,
            AssetType = DataAssetType.ChartJson,
            Url = chartUpload.Url,
            PublicId = chartUpload.PublicId,
            DisplayOrder = request.DisplayOrder + 1
        };

        _db.DataAssets.Add(xmlAsset);
        _db.DataAssets.Add(chartAsset);
        await _db.SaveChangesAsync(cancellationToken);

        return Ok(new MusicXmlUploadResultDto
        {
            MusicXmlAsset = xmlAsset.ToDto(),
            ChartAsset = chartAsset.ToDto(),
            NoteCount = conversion.NoteCount,
            LaneCount = conversion.LaneCount,
            Bpm = conversion.Bpm,
            BeatsPerMeasure = conversion.BeatsPerMeasure,
            BeatUnit = conversion.BeatUnit
        });
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, [FromBody] DataAssetRequestDto request)
    {
        var item = await _db.DataAssets.FindAsync(id);
        if (item is null) return NotFound();

        if (!HasSingleOwner(request)) return BadRequest("Exactly one of sheetId, songId, or userId must be provided.");
        if (!await OwnerExistsAsync(request)) return BadRequest("Referenced owner does not exist.");

        item.SheetId = request.SheetId;
        item.SongId = request.SongId;
        item.UserId = request.UserId;
        item.AssetType = request.AssetType;
        item.Url = request.Url;
        item.PublicId = request.PublicId;
        item.DisplayOrder = request.DisplayOrder;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var item = await _db.DataAssets.FindAsync(id);
        if (item is null) return NotFound();

        await _cloudStorageService.DeleteAsync(item.PublicId, item.Url);
        _db.DataAssets.Remove(item);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    private static bool HasSingleOwner(DataAssetRequestDto request)
    {
        var ownerCount = 0;
        if (!string.IsNullOrWhiteSpace(request.SheetId)) ownerCount++;
        if (!string.IsNullOrWhiteSpace(request.SongId)) ownerCount++;
        if (!string.IsNullOrWhiteSpace(request.UserId)) ownerCount++;
        return ownerCount == 1;
    }

    private async Task<bool> OwnerExistsAsync(DataAssetRequestDto request)
    {
        if (!string.IsNullOrWhiteSpace(request.SheetId))
        {
            return await _db.Sheets.AnyAsync(x => x.Id == request.SheetId);
        }

        if (!string.IsNullOrWhiteSpace(request.SongId))
        {
            return await _db.Songs.AnyAsync(x => x.Id == request.SongId);
        }

        if (!string.IsNullOrWhiteSpace(request.UserId))
        {
            return await _db.Users.AnyAsync(x => x.Id == request.UserId);
        }

        return false;
    }

    private static bool IsMxlFile(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
        {
            return false;
        }

        var extension = Path.GetExtension(fileName);
        return extension.Equals(".mxl", StringComparison.OrdinalIgnoreCase);
    }

    private static string BuildChartFileName(string sourceFileName)
    {
        var baseName = Path.GetFileNameWithoutExtension(sourceFileName);
        if (string.IsNullOrWhiteSpace(baseName))
        {
            baseName = "chart";
        }

        return $"{baseName}.chart.json";
    }

    public class DataAssetUploadForm
    {
        public string? SheetId { get; set; }
        public string? SongId { get; set; }
        public string? UserId { get; set; }
        public DataAssetType AssetType { get; set; } = DataAssetType.File;
        public int DisplayOrder { get; set; }
        public IFormFile? File { get; set; }
    }

    public class MusicXmlUploadForm
    {
        public string? SheetId { get; set; }
        public string? SongId { get; set; }
        public string? UserId { get; set; }
        public int DisplayOrder { get; set; }
        public IFormFile? File { get; set; }
    }

    public class MusicXmlUploadResultDto
    {
        public DataAssetDto MusicXmlAsset { get; set; } = new();
        public DataAssetDto ChartAsset { get; set; } = new();
        public int NoteCount { get; set; }
        public int LaneCount { get; set; }
        public double Bpm { get; set; }
        public int BeatsPerMeasure { get; set; }
        public int BeatUnit { get; set; }
    }
}


