import 'game_score.dart';

class NoteTiming {
  const NoteTiming._();

  // Shared horizontal speed so painters and gameplay timing stay in sync.
  static const double notePxPerMs = 0.14;

  static int adjustedHitTimeMs(MusicNote note) {
    return note.hitTimeMs;
  }
}