import 'game_score.dart';

class NoteTiming {
  const NoteTiming._();

  static const double baseNotePxPerMs = 0.14;
  static const double defaultPlaybackSpeed = 1.0;
  static const double minPlaybackSpeed = 0.1;
  static const double maxPlaybackSpeed = 2.0;
  static const int defaultTimelineMsPerDurationDivision = 800;
  static const int minTimelineMsPerDurationDivision = 400;
  static const int maxTimelineMsPerDurationDivision = 1600;
  static const int timelineMsPerDurationDivisionStep = 100;

  static double notePxPerMsForScore(
    ScoreData score, {
    required int timelineMsPerDurationDivision,
  }) {
    if (score.bpm <= 0) {
      return baseNotePxPerMs;
    }

    final realQuarterMs = 60000.0 / score.bpm;
    if (realQuarterMs <= 0) {
      return baseNotePxPerMs;
    }

    return baseNotePxPerMs * (timelineMsPerDurationDivision / realQuarterMs);
  }

  static int adjustedHitTimeMs(MusicNote note) {
    return note.hitTimeMs;
  }
}
