part of 'game_note_painter.dart';

_LockedBeamGeometry _notePainterBuildLockedBeamGeometry(
  List<_RenderNote> allNotes,
  List<int> indexes, {
  required double lineSpacing,
}) {
  final first = allNotes[indexes.first];
  final last = allNotes[indexes.last];
  final direction = first.stemDirection;

  final firstTip = _notePainterBeamStemTipForNote(
    first,
    direction: direction,
    spacing: lineSpacing,
  );
  final lastTip = _notePainterBeamStemTipForNote(
    last,
    direction: direction,
    spacing: lineSpacing,
  );

  final dx = (lastTip.dx - firstTip.dx).abs() < 1 ? 1.0 : lastTip.dx - firstTip.dx;
  final measuredSlope = (lastTip.dy - firstTip.dy) / dx;
  final legacySlope = _notePainterLegacyTargetBeamSlopeByPattern(
    allNotes,
    indexes,
    direction,
  );
  final maxSlope = _notePainterLegacyMaxBeamSlope(allNotes, indexes);
  var slope = measuredSlope * 0.2 + legacySlope * 0.8;
  if (slope > maxSlope) {
    slope = maxSlope;
  }
  if (slope < -maxSlope) {
    slope = -maxSlope;
  }

  return _LockedBeamGeometry(slope: slope, referenceStemTip: firstTip);
}

Offset _notePainterBeamStemTipForNote(
  _RenderNote note, {
  required _StemDirection direction,
  required double spacing,
}) {
  final stemHeight = (spacing * 3.2).clamp(34.0, 76.0);
  final stemX = note.stemXAxisDirection == _StemDirection.up
      ? note.x + spacing * 0.55
      : note.x - spacing * 0.55;
  final stemY = direction == _StemDirection.up
      ? note.y - stemHeight
      : note.y + stemHeight;
  return Offset(stemX, stemY);
}

List<List<int>> _notePainterBuildBeamGroups(List<_RenderNote> visible) {
  return _notePainterBuildExplicitBeamGroups(visible);
}

List<List<int>> _notePainterBuildExplicitBeamGroups(List<_RenderNote> visible) {
  final groups = <List<int>>[];
  final states = <String, _ExplicitBeamTrackState>{};

  final onsetTrackBuckets = <String, List<int>>{};
  for (var i = 0; i < visible.length; i++) {
    final note = visible[i];
    final onsetTrackKey =
        '${note.adjustedHitMs}-${note.isTreble ? 't' : 'b'}-${note.note.voice}';
    onsetTrackBuckets.putIfAbsent(onsetTrackKey, () => <int>[]).add(i);
  }

  int pickRepresentativeIndex(List<int> indexes) {
    var best = indexes.first;

    int score(_RenderNote n) {
      var value = 0;
      if (n.note.primaryBeam != null) {
        value += 10;
      }
      if (n.note.primaryBeam == 'begin' || n.note.primaryBeam == 'end') {
        value += 3;
      }
      if (n.durationType == _DurationType.eighth ||
          n.durationType == _DurationType.sixteenth) {
        value += 2;
      }
      return value;
    }

    var bestScore = score(visible[best]);
    for (final idx in indexes.skip(1)) {
      final candidateScore = score(visible[idx]);
      if (candidateScore > bestScore) {
        best = idx;
        bestScore = candidateScore;
      }
    }
    return best;
  }

  final representativeIndexes = onsetTrackBuckets.values
      .map(pickRepresentativeIndex)
      .toList()
    ..sort();

  _ExplicitBeamTrackState stateFor(_RenderNote note) {
    final key = '${note.isTreble ? 't' : 'b'}-${note.note.voice}';
    return states.putIfAbsent(key, _ExplicitBeamTrackState.new);
  }

  void flushState(_ExplicitBeamTrackState state) {
    if (state.current.length >= 2) {
      groups.add(List<int>.from(state.current));
    }
    state.current.clear();
  }

  for (final i in representativeIndexes) {
    final note = visible[i];
    final beam = note.note.primaryBeam;
    final canBeam =
        note.durationType == _DurationType.eighth ||
        note.durationType == _DurationType.sixteenth;
    final state = stateFor(note);

    if (!canBeam || beam == null) {
      flushState(state);
      state.measureIndex = note.note.measureIndex;
      continue;
    }

    if (state.current.isNotEmpty && state.measureIndex != note.note.measureIndex) {
      flushState(state);
    }
    state.measureIndex = note.note.measureIndex;

    switch (beam) {
      case 'begin':
        flushState(state);
        state.current.add(i);
        break;
      case 'continue':
        state.current.add(i);
        break;
      case 'end':
        state.current.add(i);
        flushState(state);
        break;
      case 'forward hook':
      case 'backward hook':
        flushState(state);
        break;
    }
  }

  for (final state in states.values) {
    flushState(state);
  }

  return groups;
}

void _notePainterNormalizeBeamGroupStemDirections(
  List<_RenderNote> visible,
  List<List<int>> groups,
) {
  for (final group in groups) {
    if (group.isEmpty) {
      continue;
    }

    final firstExplicit = visible[group.first].note.stemFromMxl;
    if (firstExplicit == 'up' || firstExplicit == 'down') {
      final explicitDirection =
          firstExplicit == 'up' ? _StemDirection.up : _StemDirection.down;
      for (final idx in group) {
        visible[idx].stemDirection = explicitDirection;
      }
      continue;
    }

    final first = visible[group.first];
    final bottomLine =
        first.isTreble ? GameNotePainter._trebleBottomLineStep : GameNotePainter._bassBottomLineStep;
    final middleLine = bottomLine + 4;

    var sum = 0.0;
    for (final idx in group) {
      sum += visible[idx].noteStep;
    }
    final avgStep = sum / group.length;
    final direction = avgStep >= middleLine ? _StemDirection.down : _StemDirection.up;

    for (final idx in group) {
      visible[idx].stemDirection = direction;
    }
  }
}

void _notePainterDrawBeamGroup(
  Canvas canvas,
  List<_RenderNote> visible,
  List<int> indexes, {
  required double lineSpacing,
  required double lockedSlope,
  required Offset lockedReferenceStemTip,
}) {
  final first = visible[indexes.first];
  final last = visible[indexes.last];
  if (first.stemTip == null || last.stemTip == null) {
    return;
  }

  final direction = first.stemDirection;
  final beamPaint = Paint()
    ..color = const Color(0xFF0E1620)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final beamThickness = (lineSpacing * 0.48).clamp(3.0, 6.0);

  final x1 = lockedReferenceStemTip.dx;
  final y1 = lockedReferenceStemTip.dy;

  double beamYAt(double x) => y1 + lockedSlope * (x - x1);

  final sign = direction == _StemDirection.up ? 1.0 : -1.0;
  final topEdgePoints = <Offset>[];
  final bottomEdgePoints = <Offset>[];

  for (final idx in indexes) {
    final item = visible[idx];
    final targetY = beamYAt(item.stemTip!.dx);
    final stemPaint = Paint()
      ..color = const Color(0xFF0E1620)
      ..strokeWidth = (lineSpacing * 0.17).clamp(1.6, 2.8)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(item.stemTip!, Offset(item.stemTip!.dx, targetY), stemPaint);
    item.stemTip = Offset(item.stemTip!.dx, targetY);

    topEdgePoints.add(Offset(item.stemTip!.dx, targetY));
    bottomEdgePoints.add(Offset(item.stemTip!.dx, targetY + beamThickness * sign));
  }

  final beamPath = Path()..moveTo(topEdgePoints.first.dx, topEdgePoints.first.dy);
  for (var i = 1; i < topEdgePoints.length; i++) {
    beamPath.lineTo(topEdgePoints[i].dx, topEdgePoints[i].dy);
  }
  for (var i = bottomEdgePoints.length - 1; i >= 0; i--) {
    beamPath.lineTo(bottomEdgePoints[i].dx, bottomEdgePoints[i].dy);
  }
  beamPath.close();
  canvas.drawPath(beamPath, beamPaint);

  final secondOffset = (beamThickness + (lineSpacing * 0.24).clamp(2.0, 4.0)) * sign;
  final hasExplicitSecondary = _notePainterDrawExplicitSecondaryBeams(
    canvas,
    visible,
    indexes,
    lineSpacing: lineSpacing,
    sign: sign,
    beamThickness: beamThickness,
    secondOffset: secondOffset,
    beamPaint: beamPaint,
    beamYAt: beamYAt,
    topEdgePoints: topEdgePoints,
  );

  final hasSecondBeam = !hasExplicitSecondary &&
      indexes.every((idx) => visible[idx].durationType == _DurationType.sixteenth);
  if (hasSecondBeam) {
    final secondTop = <Offset>[];
    final secondBottom = <Offset>[];
    for (final point in topEdgePoints) {
      secondTop.add(Offset(point.dx, point.dy + secondOffset));
      secondBottom.add(Offset(point.dx, point.dy + secondOffset + beamThickness * sign));
    }

    final secondPath = Path()..moveTo(secondTop.first.dx, secondTop.first.dy);
    for (var i = 1; i < secondTop.length; i++) {
      secondPath.lineTo(secondTop[i].dx, secondTop[i].dy);
    }
    for (var i = secondBottom.length - 1; i >= 0; i--) {
      secondPath.lineTo(secondBottom[i].dx, secondBottom[i].dy);
    }
    secondPath.close();
    canvas.drawPath(secondPath, beamPaint);
  }
}

bool _notePainterDrawExplicitSecondaryBeams(
  Canvas canvas,
  List<_RenderNote> visible,
  List<int> indexes, {
  required double lineSpacing,
  required double sign,
  required double beamThickness,
  required double secondOffset,
  required Paint beamPaint,
  required double Function(double x) beamYAt,
  required List<Offset> topEdgePoints,
}) {
  var hasExplicitSecondary = false;
  int? openStartLocalIndex;

  for (var localIndex = 0; localIndex < indexes.length; localIndex++) {
    final beamValue = visible[indexes[localIndex]].note.secondaryBeam;
    if (beamValue == null) {
      openStartLocalIndex = null;
      continue;
    }

    hasExplicitSecondary = true;
    switch (beamValue) {
      case 'begin':
        openStartLocalIndex = localIndex;
        break;
      case 'continue':
        openStartLocalIndex ??= localIndex > 0 ? localIndex - 1 : null;
        break;
      case 'end':
        if (openStartLocalIndex != null && openStartLocalIndex < localIndex) {
          _notePainterDrawParallelBeamSegment(
            canvas,
            startX: topEdgePoints[openStartLocalIndex].dx,
            endX: topEdgePoints[localIndex].dx,
            beamYAt: beamYAt,
            secondOffset: secondOffset,
            beamThickness: beamThickness,
            sign: sign,
            beamPaint: beamPaint,
          );
        }
        openStartLocalIndex = null;
        break;
      case 'forward hook':
        _notePainterDrawSecondaryBeamHook(
          canvas,
          stemX: topEdgePoints[localIndex].dx,
          isForward: true,
          lineSpacing: lineSpacing,
          beamYAt: beamYAt,
          secondOffset: secondOffset,
          beamThickness: beamThickness,
          sign: sign,
          beamPaint: beamPaint,
        );
        openStartLocalIndex = null;
        break;
      case 'backward hook':
        _notePainterDrawSecondaryBeamHook(
          canvas,
          stemX: topEdgePoints[localIndex].dx,
          isForward: false,
          lineSpacing: lineSpacing,
          beamYAt: beamYAt,
          secondOffset: secondOffset,
          beamThickness: beamThickness,
          sign: sign,
          beamPaint: beamPaint,
        );
        openStartLocalIndex = null;
        break;
    }
  }

  return hasExplicitSecondary;
}

void _notePainterDrawSecondaryBeamHook(
  Canvas canvas, {
  required double stemX,
  required bool isForward,
  required double lineSpacing,
  required double Function(double x) beamYAt,
  required double secondOffset,
  required double beamThickness,
  required double sign,
  required Paint beamPaint,
}) {
  final hookLength = (lineSpacing * 1.35).clamp(8.0, 20.0);
  final startX = isForward ? stemX : stemX - hookLength;
  final endX = isForward ? stemX + hookLength : stemX;

  _notePainterDrawParallelBeamSegment(
    canvas,
    startX: startX,
    endX: endX,
    beamYAt: beamYAt,
    secondOffset: secondOffset,
    beamThickness: beamThickness,
    sign: sign,
    beamPaint: beamPaint,
  );
}

void _notePainterDrawParallelBeamSegment(
  Canvas canvas, {
  required double startX,
  required double endX,
  required double Function(double x) beamYAt,
  required double secondOffset,
  required double beamThickness,
  required double sign,
  required Paint beamPaint,
}) {
  if ((endX - startX).abs() < 1) {
    return;
  }

  final topStart = Offset(startX, beamYAt(startX) + secondOffset);
  final topEnd = Offset(endX, beamYAt(endX) + secondOffset);
  final bottomEnd = Offset(
    endX,
    beamYAt(endX) + secondOffset + beamThickness * sign,
  );
  final bottomStart = Offset(
    startX,
    beamYAt(startX) + secondOffset + beamThickness * sign,
  );

  final path = Path()
    ..moveTo(topStart.dx, topStart.dy)
    ..lineTo(topEnd.dx, topEnd.dy)
    ..lineTo(bottomEnd.dx, bottomEnd.dy)
    ..lineTo(bottomStart.dx, bottomStart.dy)
    ..close();
  canvas.drawPath(path, beamPaint);
}

double _notePainterLegacyMaxBeamSlope(List<_RenderNote> visible, List<int> indexes) {
  final hasSixteenth = indexes.every(
    (idx) => visible[idx].durationType == _DurationType.sixteenth,
  );
  final degrees = hasSixteenth ? 16.0 : 8.0;
  return math.tan(degrees * math.pi / 180);
}

double _notePainterLegacyTargetBeamSlopeByPattern(
  List<_RenderNote> visible,
  List<int> indexes,
  _StemDirection direction,
) {
  final first = visible[indexes.first];
  final last = visible[indexes.last];
  final steps = indexes.map((idx) => visible[idx].noteStep).toList();

  var minStep = steps.first;
  var maxStep = steps.first;
  for (final step in steps.skip(1)) {
    if (step < minStep) {
      minStep = step;
    }
    if (step > maxStep) {
      maxStep = step;
    }
  }

  if (maxStep - minStep <= 1) {
    return 0;
  }

  final maxSlope = _notePainterLegacyMaxBeamSlope(visible, indexes);
  final stepDelta = last.noteStep - first.noteStep;
  final variationFactor = ((maxStep - minStep) / 6).clamp(0.45, 1.0);

  if (stepDelta.abs() <= 1 && indexes.length >= 3) {
    final middleIndexes = indexes.sublist(1, indexes.length - 1);
    var middleSum = 0.0;
    for (final idx in middleIndexes) {
      middleSum += visible[idx].noteStep;
    }
    final middleAvg = middleSum / middleIndexes.length;
    final edgeAvg = (first.noteStep + last.noteStep) / 2;
    final middleHigher = middleAvg > edgeAvg;

    if (direction == _StemDirection.up) {
      return (middleHigher ? -1 : 1) * maxSlope * 0.5 * variationFactor;
    }
    return (middleHigher ? 1 : -1) * maxSlope * 0.5 * variationFactor;
  }

  if (direction == _StemDirection.up) {
    return (stepDelta > 0 ? -1 : 1) * maxSlope * variationFactor;
  }
  return (stepDelta > 0 ? 1 : -1) * maxSlope * variationFactor;
}
