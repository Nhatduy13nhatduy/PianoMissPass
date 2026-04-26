import '../../domain/game_score.dart';

class TimedExpectedChord {
  const TimedExpectedChord({
    required this.hitTimeMs,
    required this.noteIndexes,
  });

  final int hitTimeMs;
  final List<int> noteIndexes;
}

class GameNoteJudgeEngine {
  GameNoteJudgeEngine({
    required this.lateHitWindowMs,
    required this.earlyHitWindowMs,
  });

  final int lateHitWindowMs;
  final int earlyHitWindowMs;
  List<TimedExpectedChord> _expectedChords = const <TimedExpectedChord>[];

  List<TimedExpectedChord> get expectedChords => _expectedChords;

  void loadScore(ScoreData score) {
    final chords = <TimedExpectedChord>[];
    var i = 0;
    while (i < score.notes.length) {
      final hitTimeMs = score.notes[i].hitTimeMs;
      final noteIndexes = <int>[];
      while (i < score.notes.length && score.notes[i].hitTimeMs == hitTimeMs) {
        noteIndexes.add(i);
        i++;
      }
      chords.add(
        TimedExpectedChord(
          hitTimeMs: hitTimeMs,
          noteIndexes: List<int>.unmodifiable(noteIndexes),
        ),
      );
    }
    _expectedChords = List<TimedExpectedChord>.unmodifiable(chords);
  }

  Set<int> candidateExpectedMidisAroundTime({
    required int currentMs,
    required ScoreData score,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
  }) {
    final windowStart = currentMs - lateHitWindowMs;
    final windowEnd = currentMs + earlyHitWindowMs;
    final startIndex = _lowerBoundChordHitTime(windowStart);
    final endIndex = _upperBoundChordHitTime(windowEnd);
    final candidateMidis = <int>{};

    for (var i = startIndex; i < endIndex; i++) {
      final chord = _expectedChords[i];
      for (final noteIndex in chord.noteIndexes) {
        if (passedNoteIndexes.contains(noteIndex) ||
            missedNoteIndexes.contains(noteIndex)) {
          continue;
        }
        candidateMidis.add(score.notes[noteIndex].midi);
      }
    }
    return candidateMidis;
  }

  Set<int>? judgeDetectedNotes({
    required int currentMs,
    required ScoreData score,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
    required Set<int> detectedMidis,
  }) {
    if (detectedMidis.isEmpty || _expectedChords.isEmpty) {
      return null;
    }

    final windowStart = currentMs - lateHitWindowMs;
    final windowEnd = currentMs + earlyHitWindowMs;
    final startIndex = _lowerBoundChordHitTime(windowStart);
    final endIndex = _upperBoundChordHitTime(windowEnd);

    List<int>? bestMatchingNoteIndexes;
    var bestDelta = 1 << 30;

    for (var i = startIndex; i < endIndex; i++) {
      final chord = _expectedChords[i];
      final remainingNoteIndexes = chord.noteIndexes
          .where(
            (index) =>
                !passedNoteIndexes.contains(index) &&
                !missedNoteIndexes.contains(index),
          )
          .toList(growable: false);
      if (remainingNoteIndexes.isEmpty) {
        continue;
      }

      final matchingNoteIndexes = remainingNoteIndexes
          .where((index) => detectedMidis.contains(score.notes[index].midi))
          .toList(growable: false);
      if (matchingNoteIndexes.isEmpty) {
        continue;
      }

      final delta = (chord.hitTimeMs - currentMs).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestMatchingNoteIndexes = matchingNoteIndexes;
      }
    }

    if (bestMatchingNoteIndexes == null) {
      return null;
    }

    final updatedPassed = Set<int>.from(passedNoteIndexes);
    for (final noteIndex in bestMatchingNoteIndexes) {
      updatedPassed.add(noteIndex);
    }
    return updatedPassed;
  }

  TimedExpectedChord? nearestUnresolvedChordWithinWindow({
    required int currentMs,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
  }) {
    if (_expectedChords.isEmpty) {
      return null;
    }

    final windowStart = currentMs - lateHitWindowMs;
    final windowEnd = currentMs + earlyHitWindowMs;
    final startIndex = _lowerBoundChordHitTime(windowStart);
    final endIndex = _upperBoundChordHitTime(windowEnd);
    TimedExpectedChord? bestChord;
    var bestDelta = 1 << 30;

    for (var i = startIndex; i < endIndex; i++) {
      final chord = _expectedChords[i];
      final hasRemainingNotes = chord.noteIndexes.any(
        (index) =>
            !passedNoteIndexes.contains(index) &&
            !missedNoteIndexes.contains(index),
      );
      if (!hasRemainingNotes) {
        continue;
      }

      final delta = (chord.hitTimeMs - currentMs).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestChord = chord;
      }
    }

    return bestChord;
  }

  int _lowerBoundChordHitTime(int targetMs) {
    var low = 0;
    var high = _expectedChords.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_expectedChords[mid].hitTimeMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundChordHitTime(int targetMs) {
    var low = 0;
    var high = _expectedChords.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_expectedChords[mid].hitTimeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
