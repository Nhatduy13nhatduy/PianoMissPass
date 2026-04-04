namespace PianoMissPass.Application.Abstractions;

public interface IMusicXmlChartService
{
    Task<MusicXmlChartConversionResult> ConvertToChartAsync(Stream musicXmlStream, string fileName, CancellationToken cancellationToken = default);
}

public sealed record MusicXmlChartConversionResult(
    string ChartJson,
    int NoteCount,
    int LaneCount,
    double Bpm,
    int BeatsPerMeasure,
    int BeatUnit
);
