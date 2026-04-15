part of 'game_note_painter.dart';

Map<int, Offset> _notePainterLayoutAccidentals(
  List<_RenderNote> visible,
  Map<int, String> accidentalByVisibleIndex, {
  required Map<int, double> noteHeadDxByVisibleIndex,
  required double spacing,
}) {
  final centers = <int, Offset>{};
  final occupied = <Rect>[];
  final groupsByTime = <int, List<int>>{};
  for (final visibleIndex in accidentalByVisibleIndex.keys) {
    final time = visible[visibleIndex].adjustedHitMs;
    groupsByTime.putIfAbsent(time, () => <int>[]).add(visibleIndex);
  }
  final sortedTimes = groupsByTime.keys.toList()..sort();

  for (final time in sortedTimes) {
    final chordIndexes = groupsByTime[time]!;
    chordIndexes.sort((a, b) => visible[a].y.compareTo(visible[b].y));
    final accidentalCountInChord = chordIndexes.length;
    final isDenseAccidentalChord = accidentalCountInChord >= 2;
    final noteStepsInChord = chordIndexes
        .map((visibleIndex) => visible[visibleIndex].noteStep)
        .toSet();

    final chordRects = <Rect>[];
    final localShiftStep = isDenseAccidentalChord
        ? spacing * 0.38
        : spacing * 0.58;
    final localPadding = isDenseAccidentalChord
        ? _notePainterAccidentalCollisionPadding(spacing) * 0.68
        : _notePainterAccidentalCollisionPadding(spacing);
    for (final visibleIndex in chordIndexes) {
      final note = visible[visibleIndex];
      final accidental = accidentalByVisibleIndex[visibleIndex]!;
      final headDx = noteHeadDxByVisibleIndex[visibleIndex] ?? 0.0;
      final hasConsecutiveAccidentalNeighbor =
          noteStepsInChord.contains(note.noteStep - 1) ||
          noteStepsInChord.contains(note.noteStep + 1);
      final extraLeftShift = hasConsecutiveAccidentalNeighbor
          ? spacing * (isDenseAccidentalChord ? 0.52 : 0.66)
          : 0.0;
      final accidentalBaseGap = note.durationType == _DurationType.whole
          ? (isDenseAccidentalChord ? spacing * 1.16 : spacing * 1.32)
          : (isDenseAccidentalChord ? spacing * 0.94 : spacing * 1.08);
      final baseCenter = Offset(
        note.x + headDx - accidentalBaseGap - extraLeftShift,
        note.y,
      );

      var resolvedCenter = baseCenter;
      var resolvedBounds = _notePainterAccidentalBounds(
        accidental,
        resolvedCenter,
        spacing,
      );
      for (var column = 0; column <= 8; column++) {
        final candidateCenter = Offset(
          baseCenter.dx - column * localShiftStep,
          baseCenter.dy,
        );
        final candidateBounds = _notePainterAccidentalBounds(
          accidental,
          candidateCenter,
          spacing,
        );
        if (!_notePainterOverlapsAny(candidateBounds, chordRects) &&
            !_notePainterOverlapsAny(candidateBounds, occupied)) {
          resolvedCenter = candidateCenter;
          resolvedBounds = candidateBounds;
          break;
        }
      }

      centers[visibleIndex] = resolvedCenter;
      final padded = resolvedBounds.inflate(localPadding);
      chordRects.add(padded);
      occupied.add(padded);
    }
  }

  return centers;
}

bool _notePainterOverlapsAny(Rect rect, List<Rect> others) {
  for (final other in others) {
    if (rect.overlaps(other)) {
      return true;
    }
  }
  return false;
}

Rect _notePainterAccidentalBounds(
  String accidental,
  Offset center,
  double spacing,
) {
  final scale = _notePainterAccidentalScale(spacing);
  return switch (accidental) {
    '♯' => Rect.fromLTWH(
      center.dx - 10 * scale,
      center.dy - 34 * scale,
      20 * scale,
      68 * scale,
    ),
    '♭' => Rect.fromLTWH(
      center.dx - 10 * scale,
      center.dy - 26 * scale,
      20 * scale,
      64 * scale,
    ),
    '♮' => Rect.fromLTWH(
      center.dx - 8.5 * scale,
      center.dy - 34 * scale,
      17 * scale,
      68 * scale,
    ),
    _ => Rect.fromLTWH(
      center.dx - 10 * scale,
      center.dy - 34 * scale,
      20 * scale,
      68 * scale,
    ),
  };
}

double _notePainterAccidentalScale(double spacing) {
  const accidentalScaleFactor = 1.02;
  return ((spacing / 7.0) * accidentalScaleFactor).clamp(0.4, 0.74);
}

double _notePainterAccidentalCollisionPadding(double spacing) {
  final padding =
      spacing *
      GameNotePainter._accidentalCollisionPaddingScale *
      GameNotePainter._accidentalCollisionPaddingTuning;
  return padding.clamp(0.2, 2.0);
}
