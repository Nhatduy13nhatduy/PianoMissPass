import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

class GameNotePainter {
  static const bool _enablePaintNoteDebugLog = false;
  static const double previewWindowMs = 9000;
  static const double cleanupWindowMs = 2500;
  static const double notePxPerMs = NoteTiming.notePxPerMs;
  static const int _trebleBottomLineStep = 30; // E4
  static const int _bassBottomLineStep = 18; // G2
  static const int _upperStableTrebleStep = 30; // E4+
  static const int _lowerStableBassStep = 26; // A3-
  static const int _middleSplitStep = 28; // C4 pivot
  static final Set<int> _debugLoggedNoteIndexes = <int>{};

  void paintNotes(
    Canvas canvas,
    Size size, {
    required ScoreData score,
    required int currentMs,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
    required double playheadX,
    required double trebleTop,
    required double bassTop,
    required double lineSpacing,
  }) {
    bool? previousIsTreble;
    final allNotes = <_RenderNote>[];

    for (var i = 0; i < score.notes.length; i++) {
      final note = score.notes[i];
      final adjustedHitMs = NoteTiming.adjustedHitTimeMs(note);
      final delta = adjustedHitMs - currentMs;
      if (delta > previewWindowMs) {
        continue;
      }

      final x = playheadX + delta * notePxPerMs;
      final isTreble =
          note.isTrebleFromMxl ??
          _chooseStaffForNote(
            note.staffStep,
            previousIsTreble: previousIsTreble,
          );
      previousIsTreble = isTreble;

      final staffTop = isTreble ? trebleTop : bassTop;
      final y = _yForStaffStep(note.staffStep, isTreble, staffTop, lineSpacing);
      final status = passedNoteIndexes.contains(i)
          ? _NoteJudge.pass
          : missedNoteIndexes.contains(i)
          ? _NoteJudge.miss
          : _NoteJudge.pending;
      final durationType = _durationTypeFromNote(note, score.bpm);
      final stemDirection = _stemDirectionFromNote(note, isTreble: isTreble);

      allNotes.add(
        _RenderNote(
          index: i,
          x: x,
          y: y,
          isTreble: isTreble,
          noteStep: note.staffStep,
          note: note,
          adjustedHitMs: adjustedHitMs,
          status: status,
          durationType: durationType,
          stemDirection: stemDirection,
        ),
      );
    }

    final beamGroupsForAnchors = _buildBeamGroups(allNotes);
    final beamAnchorByIndex = <int, int>{};
    for (final group in beamGroupsForAnchors) {
      final anchorIndex = group.last;
      final anchorTime = allNotes[anchorIndex].adjustedHitMs;
      for (final index in group) {
        beamAnchorByIndex[allNotes[index].index] = anchorTime;
      }
    }

    final visible = <_RenderNote>[];
    for (final item in allNotes) {
      final anchorTime = beamAnchorByIndex[item.index] ?? item.adjustedHitMs;
      final anchorDelta = anchorTime - currentMs;
      if (anchorDelta > previewWindowMs || anchorDelta < -cleanupWindowMs) {
        continue;
      }

      if (item.x < -30 || item.x > size.width + 30) {
        continue;
      }

      visible.add(item);
    }

    final beamGroups = _buildBeamGroups(visible);
    _normalizeBeamGroupStemDirections(visible, beamGroups);

    final beamedVisibleIndexes = <int>{};
    for (final group in beamGroups) {
      beamedVisibleIndexes.addAll(group);
    }

    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final item = visible[visibleIndex];
      final keyFifths = _activeKeyFifthsAt(score, item.note.hitTimeMs);
      final accidentalToRender = _accidentalToRender(
        item.note,
        keyFifths: keyFifths,
      );
      assert(() {
        if (!_enablePaintNoteDebugLog) {
          return true;
        }
        if (_debugLoggedNoteIndexes.contains(item.index)) {
          return true;
        }
        _debugLoggedNoteIndexes.add(item.index);
        debugPrint(
          'paintNote currentMs=$currentMs measure=${item.note.measureIndex + 1} '
          'voice=${item.note.voice} staff=${item.isTreble ? 1 : 2} '
          'x=${item.x.toStringAsFixed(1)} y=${item.y.toStringAsFixed(1)} '
          'midi=${item.note.midi} dur=${item.durationType}',
        );
        return true;
      }());
      _drawLedgerLines(
        canvas,
        centerX: item.x,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        staffTop: item.isTreble ? trebleTop : bassTop,
        spacing: lineSpacing,
      );

      _drawNoteGlyph(
        canvas,
        center: Offset(item.x, item.y),
        judge: item.status,
        isActive: (item.adjustedHitMs - currentMs).abs() <= 70,
        durationType: item.durationType,
        spacing: lineSpacing,
      );

      item.stemTip = _drawStem(
        canvas,
        center: Offset(item.x, item.y),
        direction: item.stemDirection,
        drawStem: item.durationType != _DurationType.whole,
        spacing: lineSpacing,
      );

      final isBeamed = beamedVisibleIndexes.contains(visibleIndex);
      if (!isBeamed) {
        _drawFlags(
          canvas,
          stemTip: item.stemTip!,
          direction: item.stemDirection,
          flagCount: _flagCountForDuration(item.durationType),
          spacing: lineSpacing,
        );
      }

      _drawAccidental(
        canvas,
        accidental: accidentalToRender,
        center: Offset(item.x - lineSpacing * 1.35, item.y),
        spacing: lineSpacing,
        color: const Color(0xFF0E1620),
      );
    }

    _drawSlurs(
      canvas,
      score: score,
      visible: visible,
      lineSpacing: lineSpacing,
    );

    for (final group in beamGroups) {
      _drawBeamGroup(canvas, visible, group, lineSpacing: lineSpacing);
    }
  }

  void _drawSlurs(
    Canvas canvas, {
    required ScoreData score,
    required List<_RenderNote> visible,
    required double lineSpacing,
  }) {
    final byScoreIndex = <int, _RenderNote>{
      for (final note in visible) note.index: note,
    };

    for (final slur in score.slurs) {
      final start = byScoreIndex[slur.startNoteIndex];
      final end = byScoreIndex[slur.endNoteIndex];
      if (start == null || end == null) {
        continue;
      }

      final isUp =
          start.stemDirection == _StemDirection.down ||
          end.stemDirection == _StemDirection.down;
      final baseY = isUp
          ? (start.y < end.y ? start.y : end.y) - lineSpacing * 2.2
          : (start.y > end.y ? start.y : end.y) + lineSpacing * 2.2;
      final startX = start.x + lineSpacing * 0.7;
      final endX = end.x - lineSpacing * 0.7;
      final width = endX - startX;
      if (width < lineSpacing * 1.4) {
        continue;
      }

      final curvature = (width / 6).clamp(lineSpacing * 0.8, lineSpacing * 3);
      final topY = isUp ? baseY - curvature : baseY + curvature;
      final bottomOffset = lineSpacing * 0.22;

      final path = Path()
        ..moveTo(startX, baseY)
        ..cubicTo(
          startX + width * 0.25,
          topY,
          endX - width * 0.25,
          topY,
          endX,
          baseY,
        )
        ..cubicTo(
          endX - width * 0.25,
          topY + (isUp ? bottomOffset : -bottomOffset),
          startX + width * 0.25,
          topY + (isUp ? bottomOffset : -bottomOffset),
          startX,
          baseY,
        )
        ..close();

      final slurColor = switch (end.status) {
        _NoteJudge.pass => const Color(0xFF1E5D31),
        _NoteJudge.miss => const Color(0xFF98273B),
        _NoteJudge.pending => const Color(0xFF0E1620),
      };

      canvas.drawPath(
        path,
        Paint()
          ..color = slurColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  bool _chooseStaffForNote(int staffStep, {required bool? previousIsTreble}) {
    if (staffStep >= _upperStableTrebleStep) {
      return true;
    }
    if (staffStep <= _lowerStableBassStep) {
      return false;
    }
    if (previousIsTreble != null) {
      return previousIsTreble;
    }
    return staffStep >= _middleSplitStep;
  }

  _DurationType _durationTypeFromNote(MusicNote note, double bpm) {
    final beatMs = 60000.0 / bpm;
    final beats = note.notatedBeats ?? (note.holdMs / beatMs);

    final candidates = <(_DurationType type, double beats)>[
      (_DurationType.whole, 4.0),
      (_DurationType.half, 2.0),
      (_DurationType.quarter, 1.0),
      (_DurationType.eighth, 0.5),
      (_DurationType.sixteenth, 0.25),
    ];

    var best = candidates.first;
    var bestDelta = (beats - best.$2).abs();
    for (final candidate in candidates.skip(1)) {
      final delta = (beats - candidate.$2).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = candidate;
      }
    }
    return best.$1;
  }

  _StemDirection _stemDirectionForNote(
    int staffStep, {
    required bool isTreble,
  }) {
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final middleLine = bottomLine + 4;
    return staffStep >= middleLine ? _StemDirection.down : _StemDirection.up;
  }

  _StemDirection _stemDirectionFromNote(
    MusicNote note, {
    required bool isTreble,
  }) {
    if (note.stemFromMxl == 'up') {
      return _StemDirection.up;
    }
    if (note.stemFromMxl == 'down') {
      return _StemDirection.down;
    }
    return _stemDirectionForNote(note.staffStep, isTreble: isTreble);
  }

  int _flagCountForDuration(_DurationType type) {
    return switch (type) {
      _DurationType.eighth => 1,
      _DurationType.sixteenth => 2,
      _ => 0,
    };
  }

  int _activeKeyFifthsAt(ScoreData score, int timeMs) {
    var result = 0;
    for (final change in score.keySignatures) {
      if (change.timeMs <= timeMs) {
        result = change.fifths;
      } else {
        break;
      }
    }
    return result;
  }

  bool _usesKeySignature(int keyFifths) {
    return keyFifths.abs() >= 2;
  }

  String? _accidentalToRender(MusicNote note, {required int keyFifths}) {
    if (!_usesKeySignature(keyFifths)) {
      return note.accidental;
    }

    final stepIndex = note.staffStep % 7;
    final expectedAlter = _expectedAlterForStep(stepIndex, keyFifths);
    final actualAlter = _alterFromGlyph(note.accidental);

    if (actualAlter == expectedAlter) {
      return null;
    }

    if (actualAlter == 0 && expectedAlter != 0) {
      return '♮';
    }

    return note.accidental ?? '♮';
  }

  int _expectedAlterForStep(int stepIndex, int keyFifths) {
    const sharpOrder = [3, 0, 4, 1, 5, 2, 6]; // F C G D A E B
    const flatOrder = [6, 2, 5, 1, 4, 0, 3]; // B E A D G C F

    if (keyFifths > 0) {
      final count = keyFifths.clamp(0, 7);
      return sharpOrder.take(count).contains(stepIndex) ? 1 : 0;
    }
    if (keyFifths < 0) {
      final count = (-keyFifths).clamp(0, 7);
      return flatOrder.take(count).contains(stepIndex) ? -1 : 0;
    }
    return 0;
  }

  int _alterFromGlyph(String? glyph) {
    return switch (glyph) {
      '♯' => 1,
      '♭' => -1,
      '𝄪' => 2,
      '𝄫' => -2,
      '♮' => 0,
      _ => 0,
    };
  }

  double _yForStaffStep(
    int staffStep,
    bool isTreble,
    double staffTop,
    double spacing,
  ) {
    final refStep = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final diff = staffStep - refStep;
    return staffTop + spacing * 4 - diff * (spacing / 2);
  }

  void _drawLedgerLines(
    Canvas canvas, {
    required double centerX,
    required int noteStep,
    required bool isTreble,
    required double staffTop,
    required double spacing,
  }) {
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final topLine = bottomLine + 8;
    final ledgerPaint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 1.6;
    const halfLength = 16.0;

    if (noteStep > topLine) {
      for (
        var ledgerStep = topLine + 2;
        ledgerStep <= noteStep;
        ledgerStep += 2
      ) {
        final y = _yForStaffStep(ledgerStep, isTreble, staffTop, spacing);
        canvas.drawLine(
          Offset(centerX - halfLength, y),
          Offset(centerX + halfLength, y),
          ledgerPaint,
        );
      }
    }

    if (noteStep < bottomLine) {
      for (
        var ledgerStep = bottomLine - 2;
        ledgerStep >= noteStep;
        ledgerStep -= 2
      ) {
        final y = _yForStaffStep(ledgerStep, isTreble, staffTop, spacing);
        canvas.drawLine(
          Offset(centerX - halfLength, y),
          Offset(centerX + halfLength, y),
          ledgerPaint,
        );
      }
    }
  }

  void _drawNoteGlyph(
    Canvas canvas, {
    required Offset center,
    required _NoteJudge judge,
    required bool isActive,
    required _DurationType durationType,
    required double spacing,
  }) {
    final strokeColor = _noteInkColor(judge, isActive);
    final wholeTargetHeight = (spacing * 1.1).clamp(8.0, 20.0);
    final headTargetHeight = (spacing * 1.02).clamp(7.5, 18.0);
    final fillPaint = Paint()
      ..color =
          (durationType == _DurationType.whole ||
              durationType == _DurationType.half)
          ? const Color(0xFFFFFFFF)
          : strokeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (spacing * 0.12).clamp(1.1, 1.9)
      ..isAntiAlias = true;

    if (durationType == _DurationType.whole) {
      final outer = _wholeOuterTemplate();
      final inner = _wholeInnerTemplate();
      final refBounds = outer.getBounds();

      _drawTemplatePathAligned(
        canvas,
        outer,
        referenceBounds: refBounds,
        center: center,
        targetHeight: wholeTargetHeight,
        paint: fillPaint,
      );
      _drawTemplatePathAligned(
        canvas,
        inner,
        referenceBounds: refBounds,
        center: center,
        targetHeight: wholeTargetHeight,
        paint: Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      _drawTemplatePathAligned(
        canvas,
        outer,
        referenceBounds: refBounds,
        center: center,
        targetHeight: wholeTargetHeight,
        paint: borderPaint,
      );
      return;
    }

    final quarterHead = _quarterHeadTemplate();
    final refBounds = quarterHead.getBounds();

    _drawTemplatePathAligned(
      canvas,
      quarterHead,
      referenceBounds: refBounds,
      center: center,
      targetHeight: headTargetHeight,
      paint: fillPaint,
    );

    if (durationType == _DurationType.half) {
      final inner = _halfInnerTemplate();
      _drawTemplatePathAligned(
        canvas,
        inner,
        referenceBounds: refBounds,
        center: center,
        targetHeight: headTargetHeight,
        paint: Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    _drawTemplatePathAligned(
      canvas,
      quarterHead,
      referenceBounds: refBounds,
      center: center,
      targetHeight: headTargetHeight,
      paint: borderPaint,
    );
  }

  void _drawTemplatePathAligned(
    Canvas canvas,
    Path template, {
    required Rect referenceBounds,
    required Offset center,
    required double targetHeight,
    required Paint paint,
  }) {
    if (referenceBounds.height == 0) {
      return;
    }

    final scale = targetHeight / referenceBounds.height;
    final centerTemplate = referenceBounds.center;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-centerTemplate.dx, -centerTemplate.dy);
    canvas.drawPath(template, paint);
    canvas.restore();
  }

  Path _quarterHeadTemplate() {
    return Path()
      ..moveTo(27.32, 97.39)
      ..cubicTo(23.8, 92.15, 27.58, 84.61, 35.64, 80.57)
      ..cubicTo(43.7, 76.53, 53.15, 77.3, 56.68, 82.54)
      ..cubicTo(60.2, 87.78, 56.42, 95.32, 48.36, 99.47)
      ..cubicTo(40.3, 103.51, 30.85, 102.64, 27.32, 97.39)
      ..close();
  }

  Path _halfInnerTemplate() {
    return Path()
      ..moveTo(55.42, 83.19)
      ..cubicTo(54.03, 81.01, 46.98, 82.21, 39.67, 85.93)
      ..lineTo(39.42, 86.03)
      ..lineTo(39.17, 86.14)
      ..cubicTo(31.98, 89.86, 27.32, 94.55, 28.83, 96.63)
      ..cubicTo(30.22, 98.81, 37.28, 97.61, 44.58, 93.9)
      ..lineTo(44.83, 93.79)
      ..lineTo(44.96, 93.68)
      ..cubicTo(52.14, 90.08, 56.8, 85.38, 55.42, 83.19)
      ..close();
  }

  Path _wholeOuterTemplate() {
    return Path()
      ..moveTo(32.1, 100.51)
      ..cubicTo(26.45, 98.81, 22, 94.16, 22, 89.98)
      ..cubicTo(22, 78.16, 47.81, 73.48, 58.47, 83.37)
      ..cubicTo(70, 94.07, 51.19, 106.29, 32.1, 100.51)
      ..close();
  }

  Path _wholeInnerTemplate() {
    return Path()
      ..moveTo(49.31, 97.54)
      ..cubicTo(52.46, 92.83, 49.45, 83.49, 44.01, 81.05)
      ..cubicTo(36.03, 77.47, 31.13, 83.57, 34.46, 92.96)
      ..cubicTo(36.76, 99.45, 46.12, 102.34, 49.31, 97.54)
      ..close();
  }

  Offset _drawStem(
    Canvas canvas, {
    required Offset center,
    required _StemDirection direction,
    required bool drawStem,
    required double spacing,
  }) {
    if (!drawStem) {
      return center;
    }

    final p = Paint()
      ..color = const Color(0xFF0E1620)
      ..strokeWidth = (spacing * 0.17).clamp(1.6, 2.8)
      ..strokeCap = StrokeCap.round;

    final stemHeight = (spacing * 3.2).clamp(34.0, 76.0);
    final stemX = direction == _StemDirection.up
        ? center.dx + spacing * 0.55
        : center.dx - spacing * 0.55;
    final stemStart = Offset(stemX, center.dy);
    final stemEnd = direction == _StemDirection.up
        ? Offset(stemX, center.dy - stemHeight)
        : Offset(stemX, center.dy + stemHeight);

    canvas.drawLine(stemStart, stemEnd, p);
    return stemEnd;
  }

  void _drawFlags(
    Canvas canvas, {
    required Offset stemTip,
    required _StemDirection direction,
    required int flagCount,
    required double spacing,
  }) {
    if (flagCount <= 0) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFF0E1620)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < flagCount; i++) {
      final yOffset = i * (spacing * 0.72);
      final anchor = direction == _StemDirection.up
          ? Offset(stemTip.dx, stemTip.dy + yOffset)
          : Offset(stemTip.dx, stemTip.dy - yOffset);

      final template = _buildLegacyFlagTemplate(direction: direction);
      final path = _buildPathFromTemplate(
        template,
        center: anchor,
        targetHeight: (spacing * 1.7).clamp(12.0, 24.0),
      );
      canvas.drawPath(path, paint);
    }
  }

  Path _buildLegacyFlagTemplate({required _StemDirection direction}) {
    if (direction == _StemDirection.up) {
      return Path()
        ..moveTo(0, 0)
        ..cubicTo(1.64, 0.96, 3.22, 1.87, 4.73, 2.74)
        ..cubicTo(21.7, 12.5, 30.12, 17.34, 20.83, 36.79)
        ..cubicTo(34.09, 17.29, 26.89, 9.42, 15.88, -2.62)
        ..cubicTo(10.85, 8.12, 5.03, 14.48, 0, -23.21)
        ..close();
    }

    return Path()
      ..moveTo(0, 0)
      ..cubicTo(-1.64, -0.96, -3.22, -1.87, -4.73, -2.74)
      ..cubicTo(-21.7, -12.5, -30.12, -17.34, -20.83, -36.79)
      ..cubicTo(-34.09, -17.29, -26.89, -9.42, -15.88, 2.62)
      ..cubicTo(-10.85, 8.12, -5.03, 14.48, 0, 23.21)
      ..close();
  }

  Path _buildPathFromTemplate(
    Path template, {
    required Offset center,
    required double targetHeight,
  }) {
    final bounds = template.getBounds();
    if (bounds.height == 0) {
      return template;
    }

    final scale = targetHeight / bounds.height;
    final centerTemplate = bounds.center;
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(scale, scale)
      ..translate(-centerTemplate.dx, -centerTemplate.dy);
    return template.transform(matrix.storage);
  }

  void _drawAccidental(
    Canvas canvas, {
    required String? accidental,
    required Offset center,
    required double spacing,
    required Color color,
  }) {
    if (accidental == null) {
      return;
    }

    final scale = (spacing / 4.8).clamp(0.65, 1.05);
    Path? path;
    Paint paint;

    if (accidental == '♯') {
      path = _buildSharpPath(center, scale);
      paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    } else if (accidental == '♭') {
      path = _buildFlatPath(center, scale);
      paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    } else if (accidental == '♮') {
      path = _buildNaturalPath(center, scale);
      paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    } else {
      return;
    }

    canvas.drawPath(path, paint);
  }

  Path _buildSharpPath(Offset c, double s) {
    final x = c.dx - 10 * s;
    final y = c.dy - 34 * s;
    return Path()
      ..moveTo(x + 6.523 * s, y + 43.5 * s)
      ..lineTo(x + 6.523 * s, y + 26.659 * s)
      ..lineTo(x + 13.368 * s, y + 24.682 * s)
      ..lineTo(x + 13.368 * s, y + 41.438 * s)
      ..lineTo(x + 6.523 * s, y + 43.5 * s)
      ..moveTo(x + 20 * s, y + 39.426 * s)
      ..lineTo(x + 15.294 * s, y + 40.837 * s)
      ..lineTo(x + 15.294 * s, y + 24.081 * s)
      ..lineTo(x + 20 * s, y + 22.706 * s)
      ..lineTo(x + 20 * s, y + 15.746 * s)
      ..lineTo(x + 15.294 * s, y + 17.12 * s)
      ..lineTo(x + 15.294 * s, y)
      ..lineTo(x + 13.368 * s, y)
      ..lineTo(x + 13.368 * s, y + 17.64 * s)
      ..lineTo(x + 6.523 * s, y + 19.698 * s)
      ..lineTo(x + 6.523 * s, y + 3.05 * s)
      ..lineTo(x + 4.706 * s, y + 3.05 * s)
      ..lineTo(x + 4.706 * s, y + 20.332 * s)
      ..lineTo(x, y + 21.71 * s)
      ..lineTo(x, y + 28.685 * s)
      ..lineTo(x + 4.706 * s, y + 27.31 * s)
      ..lineTo(x + 4.706 * s, y + 44.034 * s)
      ..lineTo(x, y + 45.405 * s)
      ..lineTo(x, y + 52.351 * s)
      ..lineTo(x + 4.706 * s, y + 50.976 * s)
      ..lineTo(x + 4.706 * s, y + 68 * s)
      ..lineTo(x + 6.523 * s, y + 68 * s)
      ..lineTo(x + 6.523 * s, y + 50.368 * s)
      ..lineTo(x + 13.368 * s, y + 48.398 * s)
      ..lineTo(x + 13.368 * s, y + 64.96 * s)
      ..lineTo(x + 15.294 * s, y + 64.96 * s)
      ..lineTo(x + 15.294 * s, y + 47.775 * s)
      ..lineTo(x + 20 * s, y + 46.397 * s)
      ..lineTo(x + 20 * s, y + 39.426 * s)
      ..close();
  }

  Path _buildFlatPath(Offset c, double s) {
    final x = c.dx - 10 * s;
    final y = c.dy - 26 * s;
    return Path()
      ..moveTo(x + 2.475 * s, y)
      ..lineTo(x + 2.475 * s, y + 31.091 * s)
      ..lineTo(x + 2.475 * s, y + 33.186 * s)
      ..lineTo(x + 2.475 * s, y + 37.378 * s)
      ..cubicTo(
        x + 5.332 * s,
        y + 34.693 * s,
        x + 8.537 * s,
        y + 33.317 * s,
        x + 12.091 * s,
        y + 33.252 * s,
      )
      ..cubicTo(
        x + 14.313 * s,
        y + 33.252 * s,
        x + 16.217 * s,
        y + 34.201 * s,
        x + 17.804 * s,
        y + 36.101 * s,
      )
      ..cubicTo(
        x + 19.2 * s,
        y + 37.869 * s,
        x + 19.93 * s,
        y + 39.834 * s,
        x + 19.994 * s,
        y + 41.995 * s,
      )
      ..cubicTo(
        x + 20.057 * s,
        y + 43.698 * s,
        x + 19.645 * s,
        y + 45.662 * s,
        x + 18.756 * s,
        y + 47.889 * s,
      )
      ..cubicTo(
        x + 18.439 * s,
        y + 48.806 * s,
        x + 17.74 * s,
        y + 49.788 * s,
        x + 16.661 * s,
        y + 50.836 * s,
      )
      ..cubicTo(
        x + 15.836 * s,
        y + 51.622 * s,
        x + 14.979 * s,
        y + 52.441 * s,
        x + 14.091 * s,
        y + 53.292 * s,
      )
      ..cubicTo(
        x + 9.394 * s,
        y + 56.829 * s,
        x + 4.697 * s,
        y + 60.398 * s,
        x,
        y + 64 * s,
      )
      ..lineTo(x, y)
      ..lineTo(x + 2.475 * s, y)
      ..close();
  }

  Path _buildNaturalPath(Offset c, double s) {
    final x = c.dx - 8.5 * s;
    final y = c.dy - 34 * s;
    return Path()
      ..moveTo(x + 17.0 * s, y + 16.64 * s)
      ..lineTo(x + 17.0 * s, y + 68.0 * s)
      ..lineTo(x + 14.794 * s, y + 68.0 * s)
      ..lineTo(x + 14.794 * s, y + 48.751 * s)
      ..lineTo(x + 3.0 * s, y + 51.989 * s)
      ..lineTo(x + 3.0 * s, y + 0.0 * s)
      ..lineTo(x + 5.121 * s, y + 0.0 * s)
      ..lineTo(x + 5.121 * s, y + 20.058 * s)
      ..lineTo(x + 17.0 * s, y + 16.64 * s)
      ..moveTo(x + 5.121 * s, y + 28.693 * s)
      ..lineTo(x + 5.121 * s, y + 42.815 * s)
      ..lineTo(x + 14.794 * s, y + 40.116 * s)
      ..lineTo(x + 14.794 * s, y + 25.995 * s)
      ..lineTo(x + 5.121 * s, y + 28.693 * s)
      ..close();
  }

  List<List<int>> _buildBeamGroups(List<_RenderNote> visible) {
    return _buildExplicitBeamGroups(visible);
  }

  List<List<int>> _buildExplicitBeamGroups(List<_RenderNote> visible) {
    final groups = <List<int>>[];
    final states = <String, _ExplicitBeamTrackState>{};

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

    for (var i = 0; i < visible.length; i++) {
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

      if (state.current.isNotEmpty &&
          state.measureIndex != note.note.measureIndex) {
        flushState(state);
      }
      state.measureIndex = note.note.measureIndex;

      switch (beam) {
        case 'begin':
          flushState(state);
          state.current.add(i);
          break;
        case 'continue':
          if (state.current.isEmpty) {
            state.current.add(i);
          } else {
            state.current.add(i);
          }
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

  void _normalizeBeamGroupStemDirections(
    List<_RenderNote> visible,
    List<List<int>> groups,
  ) {
    for (final group in groups) {
      if (group.isEmpty) {
        continue;
      }

      final firstExplicit = visible[group.first].note.stemFromMxl;
      if (firstExplicit == 'up' || firstExplicit == 'down') {
        final explicitDirection = firstExplicit == 'up'
            ? _StemDirection.up
            : _StemDirection.down;
        for (final idx in group) {
          visible[idx].stemDirection = explicitDirection;
        }
        continue;
      }

      final first = visible[group.first];
      final bottomLine = first.isTreble
          ? _trebleBottomLineStep
          : _bassBottomLineStep;
      final middleLine = bottomLine + 4;

      var sum = 0.0;
      for (final idx in group) {
        sum += visible[idx].noteStep;
      }
      final avgStep = sum / group.length;
      final direction = avgStep >= middleLine
          ? _StemDirection.down
          : _StemDirection.up;

      for (final idx in group) {
        visible[idx].stemDirection = direction;
      }
    }
  }

  void _drawBeamGroup(
    Canvas canvas,
    List<_RenderNote> visible,
    List<int> indexes, {
    required double lineSpacing,
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

    final x1 = first.stemTip!.dx;
    final y1 = first.stemTip!.dy;
    final x2 = last.stemTip!.dx;
    final y2 = last.stemTip!.dy;
    final dx = (x2 - x1).abs() < 1 ? 1.0 : x2 - x1;
    final measuredSlope = (y2 - y1) / dx;
    final legacySlope = _legacyTargetBeamSlopeByPattern(
      visible,
      indexes,
      direction,
    );
    final maxSlope = _legacyMaxBeamSlope(visible, indexes);
    var slope = measuredSlope * 0.2 + legacySlope * 0.8;
    if (slope > maxSlope) {
      slope = maxSlope;
    }
    if (slope < -maxSlope) {
      slope = -maxSlope;
    }

    double beamYAt(double x) => y1 + slope * (x - x1);

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
      canvas.drawLine(
        item.stemTip!,
        Offset(item.stemTip!.dx, targetY),
        stemPaint,
      );
      item.stemTip = Offset(item.stemTip!.dx, targetY);

      topEdgePoints.add(Offset(item.stemTip!.dx, targetY));
      bottomEdgePoints.add(
        Offset(item.stemTip!.dx, targetY + beamThickness * sign),
      );
    }

    final beamPath = Path()
      ..moveTo(topEdgePoints.first.dx, topEdgePoints.first.dy);
    for (var i = 1; i < topEdgePoints.length; i++) {
      beamPath.lineTo(topEdgePoints[i].dx, topEdgePoints[i].dy);
    }
    for (var i = bottomEdgePoints.length - 1; i >= 0; i--) {
      beamPath.lineTo(bottomEdgePoints[i].dx, bottomEdgePoints[i].dy);
    }
    beamPath.close();
    canvas.drawPath(beamPath, beamPaint);

    final secondOffset =
        (beamThickness + (lineSpacing * 0.24).clamp(2.0, 4.0)) * sign;
    final hasExplicitSecondary = _drawExplicitSecondaryBeams(
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

    final hasSecondBeam = !hasExplicitSecondary && indexes.every(
      (idx) => visible[idx].durationType == _DurationType.sixteenth,
    );
    if (hasSecondBeam) {
      final secondTop = <Offset>[];
      final secondBottom = <Offset>[];
      for (final point in topEdgePoints) {
        secondTop.add(Offset(point.dx, point.dy + secondOffset));
        secondBottom.add(
          Offset(point.dx, point.dy + secondOffset + beamThickness * sign),
        );
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

  bool _drawExplicitSecondaryBeams(
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
            _drawParallelBeamSegment(
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
          _drawSecondaryBeamHook(
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
          _drawSecondaryBeamHook(
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

  void _drawSecondaryBeamHook(
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

    _drawParallelBeamSegment(
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

  void _drawParallelBeamSegment(
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

  double _legacyMaxBeamSlope(List<_RenderNote> visible, List<int> indexes) {
    final hasSixteenth = indexes.every(
      (idx) => visible[idx].durationType == _DurationType.sixteenth,
    );
    final degrees = hasSixteenth ? 16.0 : 8.0;
    return math.tan(degrees * math.pi / 180);
  }

  double _legacyTargetBeamSlopeByPattern(
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

    // Pattern 1: beam should be visually flat when pitch is effectively equal.
    if (maxStep - minStep <= 1) {
      return 0;
    }

    final maxSlope = _legacyMaxBeamSlope(visible, indexes);
    final stepDelta = last.noteStep - first.noteStep;
    final variationFactor = ((maxStep - minStep) / 6).clamp(0.45, 1.0);

    // Pattern 2: arch/valley shape (first ~ last, middle bends).
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

    // Pattern 3: clear upward/downward contour across the group.
    if (direction == _StemDirection.up) {
      return (stepDelta > 0 ? -1 : 1) * maxSlope * variationFactor;
    }
    return (stepDelta > 0 ? 1 : -1) * maxSlope * variationFactor;
  }

  Color _noteInkColor(_NoteJudge judge, bool isActive) {
    return switch (judge) {
      _NoteJudge.pass => const Color(0xFF1E5D31),
      _NoteJudge.miss => const Color(0xFF98273B),
      _NoteJudge.pending =>
        isActive ? const Color(0xFF1F3B56) : const Color(0xFF0E1620),
    };
  }
}

class _RenderNote {
  _RenderNote({
    required this.index,
    required this.x,
    required this.y,
    required this.isTreble,
    required this.noteStep,
    required this.note,
    required this.adjustedHitMs,
    required this.status,
    required this.durationType,
    required this.stemDirection,
  });

  final int index;
  final double x;
  final double y;
  final bool isTreble;
  final int noteStep;
  final MusicNote note;
  final int adjustedHitMs;
  final _NoteJudge status;
  final _DurationType durationType;
  _StemDirection stemDirection;
  Offset? stemTip;
}

class _ExplicitBeamTrackState {
  final List<int> current = <int>[];
  int measureIndex = -1;
}

enum _NoteJudge { pending, pass, miss }

enum _DurationType { whole, half, quarter, eighth, sixteenth }

enum _StemDirection { up, down }
