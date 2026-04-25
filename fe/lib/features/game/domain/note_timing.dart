import 'game_score.dart';

class NoteTiming {
  const NoteTiming._();

  static const double baseNotePxPerMs = 0.14;
  static const double defaultPlaybackSpeed = 1.0;
  static const double minPlaybackSpeed = 0.1;
  static const double maxPlaybackSpeed = 2.0;
  static const double defaultTimelineMultiplier = 1.0;
  static const double minTimelineMultiplier = 0.1;
  static const double maxTimelineMultiplier = 2.0;
  static const double timelineMultiplierStep = 0.1;
  static const int defaultTimelineMsPerDurationDivision = 600;
  static const int minTimelineMsPerDurationDivision = 80;
  static const int maxTimelineMsPerDurationDivision = 1600;
  static const int timelineMsPerDurationDivisionStep = 80;
  static final Expando<ScoreVisualTimelineMapper> _timelineMapperCache =
      Expando<ScoreVisualTimelineMapper>('score-visual-timeline-mapper');

  static double timelineMultiplierFromMsPerDurationDivision(
    int timelineMsPerDurationDivision,
  ) {
    return timelineMsPerDurationDivision / defaultTimelineMsPerDurationDivision;
  }

  static int timelineMsPerDurationDivisionFromMultiplier(double multiplier) {
    final normalizedMultiplier = multiplier.clamp(
      minTimelineMultiplier,
      maxTimelineMultiplier,
    );
    return (defaultTimelineMsPerDurationDivision * normalizedMultiplier)
        .round();
  }

  static double notePxPerMsForScore(
    ScoreData score, {
    required int timelineMsPerDurationDivision,
  }) {
    return notePxPerMsForTimeline(
      timelineMsPerDurationDivision: timelineMsPerDurationDivision,
    );
  }

  static double notePxPerMsForTimeline({
    required int timelineMsPerDurationDivision,
  }) {
    return baseNotePxPerMs *
        (timelineMsPerDurationDivision / defaultTimelineMsPerDurationDivision);
  }

  static ScoreVisualTimelineMapper visualTimelineForScore(ScoreData score) {
    final cached = _timelineMapperCache[score];
    if (cached != null) {
      return cached;
    }
    final mapper = ScoreVisualTimelineMapper._(score.measureSpans);
    _timelineMapperCache[score] = mapper;
    return mapper;
  }

  static int adjustedHitTimeMs(MusicNote note) {
    return note.hitTimeMs;
  }
}

class ScoreVisualTimelineMapper {
  ScoreVisualTimelineMapper._(List<ScoreMeasureSpan> measureSpans)
    : _measureSpans = List<ScoreMeasureSpan>.unmodifiable(
        List<ScoreMeasureSpan>.from(measureSpans)
          ..sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs)),
      ),
      _visualMeasureStartMs = _buildVisualMeasureStartMs(measureSpans);

  final List<ScoreMeasureSpan> _measureSpans;
  final List<double> _visualMeasureStartMs;

  double visualTimeForRealMs(num realMs) {
    if (_measureSpans.isEmpty) {
      return realMs.toDouble();
    }

    final spanIndex = _spanIndexForRealMs(realMs.toDouble());
    final span = _measureSpans[spanIndex];
    final visualStartMs = _visualMeasureStartMs[spanIndex];
    final visualDurationMs = visualMeasureDurationMs(span);
    final realDurationMs = (span.endTimeMs - span.startTimeMs).toDouble();
    if (realDurationMs <= 0 || visualDurationMs <= 0) {
      return visualStartMs;
    }

    final progress =
        ((realMs.toDouble() - span.startTimeMs) / realDurationMs).toDouble();
    return visualStartMs + (progress * visualDurationMs);
  }

  double visualMeasureDurationAtRealMs(num realMs) {
    if (_measureSpans.isEmpty) {
      return NoteTiming.defaultTimelineMsPerDurationDivision.toDouble();
    }
    return visualMeasureDurationMs(
      _measureSpans[_spanIndexForRealMs(realMs.toDouble())],
    );
  }

  double visualMeasureDurationMs(ScoreMeasureSpan span) {
    return _visualMeasureDurationMsForSpan(span);
  }

  int _spanIndexForRealMs(double realMs) {
    if (_measureSpans.length == 1) {
      return 0;
    }

    var low = 0;
    var high = _measureSpans.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_measureSpans[mid].endTimeMs <= realMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    if (low >= _measureSpans.length) {
      return _measureSpans.length - 1;
    }
    return low;
  }

  static List<double> _buildVisualMeasureStartMs(
    List<ScoreMeasureSpan> measureSpans,
  ) {
    if (measureSpans.isEmpty) {
      return const <double>[];
    }

    final spans = List<ScoreMeasureSpan>.from(measureSpans)
      ..sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
    final starts = <double>[];
    var current = 0.0;
    for (final span in spans) {
      starts.add(current);
      current += _visualMeasureDurationMsForSpan(span);
    }
    return List<double>.unmodifiable(starts);
  }

  static double _visualMeasureDurationMsForSpan(ScoreMeasureSpan span) {
    final effectiveQuarterCount =
        span.actualQuarterCount > 0
            ? span.actualQuarterCount
            : (span.beatsPerMeasure *
                  (4.0 / (span.beatUnit <= 0 ? 4 : span.beatUnit)));
    return effectiveQuarterCount *
        NoteTiming.defaultTimelineMsPerDurationDivision;
  }
}
