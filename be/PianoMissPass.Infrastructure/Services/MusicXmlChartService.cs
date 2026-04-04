using System.Text.Json;
using System.IO.Compression;
using System.Xml.Linq;
using PianoMissPass.Application.Abstractions;

namespace PianoMissPass.Infrastructure.Services;

public class MusicXmlChartService : IMusicXmlChartService
{
    private const int DefaultDivisions = 1;
    private const int DefaultBeats = 4;
    private const int DefaultBeatUnit = 4;
    private const double DefaultBpm = 120d;
    private const int DefaultLaneCount = 12;

    public async Task<MusicXmlChartConversionResult> ConvertToChartAsync(Stream musicXmlStream, string fileName, CancellationToken cancellationToken = default)
    {
        var document = await LoadMusicXmlDocumentAsync(musicXmlStream, fileName, cancellationToken);
        var root = document.Root ?? throw new InvalidOperationException("Invalid MusicXML: root element is missing.");

        var parts = root.Elements().Where(x => x.Name.LocalName == "part").ToList();
        if (parts.Count == 0)
        {
            throw new InvalidOperationException("Invalid MusicXML: no part nodes were found.");
        }

        var bpm = ResolveInitialBpm(root);
        var beatsPerMeasure = ResolveInitialInt(root, "beats", DefaultBeats);
        var beatUnit = ResolveInitialInt(root, "beat-type", DefaultBeatUnit);

        var notes = new List<ChartNote>();

        for (var partIndex = 0; partIndex < parts.Count; partIndex++)
        {
            var part = parts[partIndex];
            var divisions = DefaultDivisions;
            double currentBeat = 0;
            double previousOnsetBeat = 0;
            var measureIndex = 0;

            foreach (var measure in part.Elements().Where(x => x.Name.LocalName == "measure"))
            {
                measureIndex++;

                var attributes = measure.Elements().FirstOrDefault(x => x.Name.LocalName == "attributes");
                if (attributes is not null)
                {
                    divisions = ParseInt(attributes.Elements().FirstOrDefault(x => x.Name.LocalName == "divisions")?.Value, divisions);
                }

                foreach (var noteElement in measure.Elements().Where(x => x.Name.LocalName == "note"))
                {
                    var isRest = noteElement.Elements().Any(x => x.Name.LocalName == "rest");
                    var isChord = noteElement.Elements().Any(x => x.Name.LocalName == "chord");
                    var durationDivisions = ParseInt(noteElement.Elements().FirstOrDefault(x => x.Name.LocalName == "duration")?.Value, 0);
                    if (durationDivisions <= 0)
                    {
                        continue;
                    }

                    var onsetBeat = isChord ? previousOnsetBeat : currentBeat;
                    var durationBeats = durationDivisions / (double)Math.Max(divisions, 1);

                    if (!isRest)
                    {
                        var pitch = noteElement.Elements().FirstOrDefault(x => x.Name.LocalName == "pitch");
                        if (pitch is not null && TryResolveMidi(pitch, out var midi))
                        {
                            var lane = Math.Abs(midi) % DefaultLaneCount;
                            var hitTimeMs = (int)Math.Round(onsetBeat * 60000d / bpm);
                            var holdMs = (int)Math.Round(durationBeats * 60000d / bpm);

                            notes.Add(new ChartNote(
                                lane,
                                hitTimeMs,
                                holdMs,
                                midi,
                                partIndex + 1,
                                measureIndex));
                        }
                    }

                    if (!isChord)
                    {
                        previousOnsetBeat = onsetBeat;
                        currentBeat += durationBeats;
                    }
                }
            }
        }

        var orderedNotes = notes
            .OrderBy(x => x.HitTimeMs)
            .ThenBy(x => x.Lane)
            .ToList();

        var chart = new ChartPayload(
            1,
            "musicxml",
            new ChartTiming(
                bpm,
                beatsPerMeasure,
                beatUnit),
            DefaultLaneCount,
            orderedNotes);

        var chartJson = JsonSerializer.Serialize(chart, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        });

        return new MusicXmlChartConversionResult(
            chartJson,
            orderedNotes.Count,
            DefaultLaneCount,
            bpm,
            beatsPerMeasure,
            beatUnit);
    }

    private static async Task<XDocument> LoadMusicXmlDocumentAsync(Stream sourceStream, string fileName, CancellationToken cancellationToken)
    {
        await using var buffer = new MemoryStream();
        await sourceStream.CopyToAsync(buffer, cancellationToken);
        buffer.Position = 0;

        if (IsMxlFile(fileName) || IsZipArchive(buffer))
        {
            return await LoadFromMxlArchiveAsync(buffer, cancellationToken);
        }

        buffer.Position = 0;
        return await XDocument.LoadAsync(buffer, LoadOptions.None, cancellationToken);
    }

    private static bool IsMxlFile(string fileName)
    {
        return Path.GetExtension(fileName).Equals(".mxl", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsZipArchive(Stream stream)
    {
        if (!stream.CanSeek || stream.Length < 4)
        {
            return false;
        }

        var originalPosition = stream.Position;
        Span<byte> signature = stackalloc byte[4];
        var bytesRead = stream.Read(signature);
        stream.Position = originalPosition;

        return bytesRead == 4
            && signature[0] == 0x50
            && signature[1] == 0x4B
            && signature[2] == 0x03
            && signature[3] == 0x04;
    }

    private static async Task<XDocument> LoadFromMxlArchiveAsync(Stream archiveStream, CancellationToken cancellationToken)
    {
        archiveStream.Position = 0;

        using var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read, leaveOpen: true);
        var rootPath = await ResolveRootFilePathAsync(archive, cancellationToken);

        var musicEntry = !string.IsNullOrWhiteSpace(rootPath)
            ? archive.GetEntry(rootPath)
            : null;

        musicEntry ??= archive.Entries
            .Where(e => !string.IsNullOrWhiteSpace(e.Name))
            .Where(e => e.FullName.EndsWith(".musicxml", StringComparison.OrdinalIgnoreCase)
                || e.FullName.EndsWith(".xml", StringComparison.OrdinalIgnoreCase))
            .Where(e => !e.FullName.StartsWith("META-INF/", StringComparison.OrdinalIgnoreCase))
            .OrderBy(e => e.FullName.EndsWith(".musicxml", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .FirstOrDefault();

        if (musicEntry is null)
        {
            throw new InvalidOperationException("Invalid MXL: no MusicXML entry was found in archive.");
        }

        await using var entryStream = musicEntry.Open();
        return await XDocument.LoadAsync(entryStream, LoadOptions.None, cancellationToken);
    }

    private static async Task<string?> ResolveRootFilePathAsync(ZipArchive archive, CancellationToken cancellationToken)
    {
        var containerEntry = archive.Entries.FirstOrDefault(e =>
            e.FullName.Equals("META-INF/container.xml", StringComparison.OrdinalIgnoreCase));

        if (containerEntry is null)
        {
            return null;
        }

        await using var containerStream = containerEntry.Open();
        var containerDocument = await XDocument.LoadAsync(containerStream, LoadOptions.None, cancellationToken);

        var rootFilePath = containerDocument
            .Descendants()
            .FirstOrDefault(x => x.Name.LocalName == "rootfile")
            ?.Attribute("full-path")
            ?.Value;

        return string.IsNullOrWhiteSpace(rootFilePath)
            ? null
            : rootFilePath.Replace('\\', '/');
    }

    private static double ResolveInitialBpm(XElement root)
    {
        var tempoNode = root
            .Descendants()
            .FirstOrDefault(x => x.Name.LocalName == "sound" && x.Attribute("tempo") is not null);

        var tempoText = tempoNode?.Attribute("tempo")?.Value;
        if (double.TryParse(tempoText, out var bpm) && bpm > 0)
        {
            return bpm;
        }

        return DefaultBpm;
    }

    private static int ResolveInitialInt(XElement root, string localName, int fallback)
    {
        var node = root.Descendants().FirstOrDefault(x => x.Name.LocalName == localName);
        return ParseInt(node?.Value, fallback);
    }

    private static int ParseInt(string? text, int fallback)
    {
        return int.TryParse(text, out var value) && value > 0 ? value : fallback;
    }

    private static bool TryResolveMidi(XElement pitchElement, out int midi)
    {
        midi = 0;

        var step = pitchElement.Elements().FirstOrDefault(x => x.Name.LocalName == "step")?.Value;
        var octaveText = pitchElement.Elements().FirstOrDefault(x => x.Name.LocalName == "octave")?.Value;
        var alterText = pitchElement.Elements().FirstOrDefault(x => x.Name.LocalName == "alter")?.Value;

        if (string.IsNullOrWhiteSpace(step) || !int.TryParse(octaveText, out var octave))
        {
            return false;
        }

        var semitone = step.Trim().ToUpperInvariant() switch
        {
            "C" => 0,
            "D" => 2,
            "E" => 4,
            "F" => 5,
            "G" => 7,
            "A" => 9,
            "B" => 11,
            _ => -1
        };

        if (semitone < 0)
        {
            return false;
        }

        var alter = int.TryParse(alterText, out var alterValue) ? alterValue : 0;
        midi = (octave + 1) * 12 + semitone + alter;
        return true;
    }

    private sealed record ChartPayload(
        int Version,
        string SourceFormat,
        ChartTiming Timing,
        int LaneCount,
        IReadOnlyList<ChartNote> Notes);

    private sealed record ChartTiming(
        double Bpm,
        int BeatsPerMeasure,
        int BeatUnit);

    private sealed record ChartNote(
        int Lane,
        int HitTimeMs,
        int HoldMs,
        int Midi,
        int Part,
        int Measure);
}
