import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

part 'game_note_painter_models.dart';
part 'game_note_painter_paths.dart';
part 'game_note_painter_accidentals.dart';
part 'game_note_painter_beam.dart';

class GameNotePainter {
  static const bool _enablePaintNoteDebugLog = false;
  static const String _bravuraFontFamily = 'Bravura';
  static const double previewWindowMs = 9000;
  static const double cleanupWindowMs = 2500;
  static const double _preRenderMeasuresRight = 1.0;
  static const double _accidentalCollisionPaddingTuning = 1.0;
  static const double _accidentalCollisionPaddingScale = 0.04;
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
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final preRenderRightPx = measureMs * notePxPerMs * _preRenderMeasuresRight;

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
          stemXAxisDirection: stemDirection,
        ),
      );
    }

    final allBeamGroups = _buildBeamGroups(allNotes);
    _normalizeBeamGroupStemDirections(allNotes, allBeamGroups);

    final beamAnchorByIndex = <int, int>{};
    for (final group in allBeamGroups) {
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

      if (item.x < -30 || item.x > size.width + preRenderRightPx) {
        continue;
      }

      visible.add(item);
    }

    final chordLayout = _buildChordLayout(visible, spacing: lineSpacing);

    final visibleIndexByScoreIndex = <int, int>{};
    for (var i = 0; i < visible.length; i++) {
      visibleIndexByScoreIndex[visible[i].index] = i;
    }

    final chordVisibleIndexesByKey = <String, List<int>>{};
    for (var i = 0; i < visible.length; i++) {
      final chordKey = chordLayout.chordKeyByVisibleIndex[i];
      if (chordKey != null) {
        chordVisibleIndexesByKey.putIfAbsent(chordKey, () => <int>[]).add(i);
      }
    }

    final beamGroups = <_ProjectedBeamGroup>[];
    final beamStemDirectionByVisibleIndex = <int, _StemDirection>{};
    for (final group in allBeamGroups) {
      final projected = <int>[];
      final projectedChordKeys = <String>{};
      final groupStemDirection = allNotes[group.first].stemDirection;
      for (final allIndex in group) {
        final scoreIndex = allNotes[allIndex].index;
        final visibleIndex = visibleIndexByScoreIndex[scoreIndex];
        if (visibleIndex != null) {
          final isChordMember = chordLayout.chordMemberVisibleIndexes.contains(
            visibleIndex,
          );
          final chordKey = isChordMember
              ? chordLayout.chordKeyByVisibleIndex[visibleIndex]
              : null;
          if (chordKey != null && projectedChordKeys.contains(chordKey)) {
            continue;
          }
          if (chordKey != null) {
            projectedChordKeys.add(chordKey);
            final chordVisibleIndexes = chordVisibleIndexesByKey[chordKey];
            if (chordVisibleIndexes == null || chordVisibleIndexes.isEmpty) {
              continue;
            }

            final anchorVisibleIndex = groupStemDirection == _StemDirection.down
                ? chordVisibleIndexes.reduce(
                    (a, b) =>
                        visible[a].noteStep >= visible[b].noteStep ? a : b,
                  )
                : chordVisibleIndexes.reduce(
                    (a, b) =>
                        visible[a].noteStep <= visible[b].noteStep ? a : b,
                  );
            projected.add(anchorVisibleIndex);
            continue;
          }

          projected.add(visibleIndex);
        }
      }
      if (projected.length >= 2) {
        final lockedBeam = _buildLockedBeamGeometry(
          allNotes,
          group,
          lineSpacing: lineSpacing,
        );
        for (final visibleIndex in projected) {
          beamStemDirectionByVisibleIndex[visibleIndex] = groupStemDirection;
        }
        beamGroups.add(
          _ProjectedBeamGroup(
            indexes: projected,
            lockedSlope: lockedBeam.slope,
            lockedReferenceStemTip: lockedBeam.referenceStemTip,
          ),
        );
      }
    }

    final beamedVisibleIndexes = <int>{};
    final beamedChordKeys = <String>{};
    for (final group in beamGroups) {
      beamedVisibleIndexes.addAll(group.indexes);
      for (final visibleIndex in group.indexes) {
        final chordKey = chordLayout.chordKeyByVisibleIndex[visibleIndex];
        if (chordKey != null) {
          beamedChordKeys.add(chordKey);
        }
      }
    }

    final accidentalByVisibleIndex = <int, String>{};
    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final note = visible[visibleIndex];
      final keyFifths = _activeKeyFifthsAt(score, note.note.hitTimeMs);
      final accidentalToRender = _accidentalToRender(
        note.note,
        keyFifths: keyFifths,
      );
      if (accidentalToRender != null) {
        accidentalByVisibleIndex[visibleIndex] = accidentalToRender;
      }
    }
    final accidentalCenterByVisibleIndex = _layoutAccidentals(
      visible,
      accidentalByVisibleIndex,
      noteHeadDxByVisibleIndex: chordLayout.headDxByVisibleIndex,
      spacing: lineSpacing,
    );

    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final item = visible[visibleIndex];
      final accidentalToRender = accidentalByVisibleIndex[visibleIndex];
      final headDx = chordLayout.headDxByVisibleIndex[visibleIndex] ?? 0.0;
      final center = Offset(item.x + headDx, item.y);
      final layoutStemDirection =
          chordLayout.stemDirectionByVisibleIndex[visibleIndex] ??
          item.stemDirection;
      final beamStemDirection = beamStemDirectionByVisibleIndex[visibleIndex];
      final effectiveStemDirection = beamStemDirection ?? layoutStemDirection;
      final stemXAxisDirection =
          beamStemDirection != null && beamStemDirection != layoutStemDirection
          ? layoutStemDirection
          : effectiveStemDirection;
      item.stemDirection = effectiveStemDirection;
      item.stemXAxisDirection = stemXAxisDirection;
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
      _drawNoteGlyph(
        canvas,
        center: center,
        judge: item.status,
        isActive: (item.adjustedHitMs - currentMs).abs() <= 70,
        durationType: item.durationType,
        spacing: lineSpacing,
      );

      _drawLedgerLines(
        canvas,
        centerX: center.dx,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        staffTop: item.isTreble ? trebleTop : bassTop,
        spacing: lineSpacing,
      );

      final chordKey = chordLayout.chordKeyByVisibleIndex[visibleIndex];
      final isBeamed = beamedVisibleIndexes.contains(visibleIndex);
      final isChordMember = chordLayout.chordMemberVisibleIndexes.contains(
        visibleIndex,
      );
      final isChordInBeam =
          chordKey != null && beamedChordKeys.contains(chordKey);
      final shouldHideTail = isBeamed || isChordInBeam;
      final shouldDrawStem =
          item.durationType != _DurationType.whole &&
          (!isChordMember ||
              (isChordInBeam
                  ? isBeamed
                  : (isBeamed ||
                        chordLayout.stemAnchorVisibleIndexes.contains(
                          visibleIndex,
                        ))));
      final chordOppositeStemHeight =
          chordLayout.stemExtraHeightByAnchorVisibleIndex[visibleIndex] ?? 0.0;

      item.stemTip = _drawStem(
        canvas,
        center: center,
        direction: effectiveStemDirection,
        xAxisDirection: stemXAxisDirection,
        drawStem: shouldDrawStem,
        spacing: lineSpacing,
        extraOppositeStemHeight: chordOppositeStemHeight,
        useButtCap: shouldHideTail,
      );

      if (!shouldHideTail && shouldDrawStem) {
        _drawFlags(
          canvas,
          stemTip: item.stemTip!,
          direction: effectiveStemDirection,
          flagCount: _flagCountForDuration(item.durationType),
          spacing: lineSpacing,
        );
      }

      _drawAccidental(
        canvas,
        accidental: accidentalToRender,
        center:
            accidentalCenterByVisibleIndex[visibleIndex] ??
            Offset(item.x - lineSpacing * 1.08, item.y),
        spacing: lineSpacing,
        color: const Color(0xFF0E1620),
      );

      _drawDots(
        canvas,
        center: center,
        dotCount: item.note.dotCount,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        spacing: lineSpacing,
        judge: item.status,
        isActive: (item.adjustedHitMs - currentMs).abs() <= 70,
      );
    }

    _drawSlurs(
      canvas,
      score: score,
      visible: visible,
      lineSpacing: lineSpacing,
    );

    for (final group in beamGroups) {
      _drawBeamGroup(
        canvas,
        visible,
        group.indexes,
        lineSpacing: lineSpacing,
        lockedSlope: group.lockedSlope,
        lockedReferenceStemTip: group.lockedReferenceStemTip,
      );
    }
  }

  Map<int, Offset> _layoutAccidentals(
    List<_RenderNote> visible,
    Map<int, String> accidentalByVisibleIndex, {
    required Map<int, double> noteHeadDxByVisibleIndex,
    required double spacing,
  }) {
    return _notePainterLayoutAccidentals(
      visible,
      accidentalByVisibleIndex,
      noteHeadDxByVisibleIndex: noteHeadDxByVisibleIndex,
      spacing: spacing,
    );
  }

  double _accidentalScale(double spacing) {
    return _notePainterAccidentalScale(spacing);
  }

  _ChordLayout _buildChordLayout(
    List<_RenderNote> visible, {
    required double spacing,
  }) {
    final stemDirectionByVisibleIndex = <int, _StemDirection>{};
    final headDxByVisibleIndex = <int, double>{};
    final stemAnchorVisibleIndexes = <int>{};
    final chordMemberVisibleIndexes = <int>{};
    final chordKeyByVisibleIndex = <int, String>{};
    final stemExtraHeightByAnchorVisibleIndex = <int, double>{};

    final groups = <String, List<int>>{};
    for (var i = 0; i < visible.length; i++) {
      final note = visible[i];
      final key =
          '${note.adjustedHitMs}-${note.isTreble ? 't' : 'b'}-${note.note.voice}';
      groups.putIfAbsent(key, () => <int>[]).add(i);
      chordKeyByVisibleIndex[i] = key;
    }

    for (final indexes in groups.values) {
      if (indexes.length < 2) {
        continue;
      }

      chordMemberVisibleIndexes.addAll(indexes);

      final sortedIndexes = List<int>.from(indexes)
        ..sort((a, b) {
          final stepCompare = visible[a].noteStep.compareTo(
            visible[b].noteStep,
          );
          if (stepCompare != 0) {
            return stepCompare;
          }
          return a.compareTo(b);
        });

      _StemDirection stemDirection;
      final explicitStem = indexes
          .map((idx) => visible[idx].note.stemFromMxl)
          .firstWhere(
            (stem) => stem == 'up' || stem == 'down',
            orElse: () => null,
          );
      if (explicitStem == 'up') {
        stemDirection = _StemDirection.up;
      } else if (explicitStem == 'down') {
        stemDirection = _StemDirection.down;
      } else {
        final isTreble = visible[indexes.first].isTreble;
        final bottomLine = isTreble
            ? _trebleBottomLineStep
            : _bassBottomLineStep;
        final middleLine = bottomLine + 4;
        var minStep = visible[indexes.first].noteStep;
        var maxStep = minStep;
        for (final idx in indexes.skip(1)) {
          final step = visible[idx].noteStep;
          if (step < minStep) {
            minStep = step;
          }
          if (step > maxStep) {
            maxStep = step;
          }
        }
        final highDistance = (maxStep - middleLine).abs();
        final lowDistance = (middleLine - minStep).abs();
        stemDirection = highDistance > lowDistance
            ? _StemDirection.down
            : _StemDirection.up;
      }

      for (final idx in indexes) {
        stemDirectionByVisibleIndex[idx] = stemDirection;
      }

      var runEnd = sortedIndexes.length - 1;

      while (runEnd >= 0) {
        var runStart = runEnd;

        var prevStep = visible[sortedIndexes[runStart]].noteStep;

        while (runStart - 1 >= 0) {
          final prevIndex = sortedIndexes[runStart - 1];
          final prevStepCandidate = visible[prevIndex].noteStep;

          if (prevStep - prevStepCandidate != 1) break;

          prevStep = prevStepCandidate;
          runStart--;
        }

        final runLength = runEnd - runStart + 1;

        if (runLength >= 2) {
          final baseDx = spacing;
          final dir = stemDirection;

          int nextIndex = -1;
          int nextStepLocal = 0;

          for (var i = runEnd; i >= runStart; i--) {
            final current = sortedIndexes[i];
            final currentStep = visible[current].noteStep;

            double dx = 0.0;

            if (nextIndex != -1 && (currentStep - nextStepLocal).abs() == 1) {
              final positionInRun = runEnd - i;
              final isShifted = positionInRun.isOdd;
              dx = isShifted ? baseDx : 0.0;
            }

            headDxByVisibleIndex[current] = dx == 0.0
                ? 0.0
                : (dir == _StemDirection.up ? dx : -dx);

            nextIndex = current;
            nextStepLocal = currentStep;
          }
        }

        runEnd = runStart - 1;
      }

      final anchor = stemDirection == _StemDirection.up
          ? sortedIndexes.last
          : sortedIndexes.first;
      stemAnchorVisibleIndexes.add(anchor);

      var minY = double.infinity;
      var maxY = double.negativeInfinity;
      for (final idx in indexes) {
        final y = visible[idx].y;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      final chordSpanHeight = (maxY - minY).abs();
      stemExtraHeightByAnchorVisibleIndex[anchor] = chordSpanHeight;
    }

    return _ChordLayout(
      stemDirectionByVisibleIndex: stemDirectionByVisibleIndex,
      headDxByVisibleIndex: headDxByVisibleIndex,
      stemAnchorVisibleIndexes: stemAnchorVisibleIndexes,
      chordMemberVisibleIndexes: chordMemberVisibleIndexes,
      chordKeyByVisibleIndex: chordKeyByVisibleIndex,
      stemExtraHeightByAnchorVisibleIndex: stemExtraHeightByAnchorVisibleIndex,
    );
  }

  _LockedBeamGeometry _buildLockedBeamGeometry(
    List<_RenderNote> allNotes,
    List<int> indexes, {
    required double lineSpacing,
  }) {
    return _notePainterBuildLockedBeamGeometry(
      allNotes,
      indexes,
      lineSpacing: lineSpacing,
    );
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
    final halfLength = (spacing * 0.95).clamp(8.0, 14.0);

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

  Path _quarterHeadTemplate() => _notePainterQuarterHeadTemplate();

  Path _halfInnerTemplate() => _notePainterHalfInnerTemplate();

  Path _wholeOuterTemplate() => _notePainterWholeOuterTemplate();

  Path _wholeInnerTemplate() => _notePainterWholeInnerTemplate();

  Path _buildLegacyFlagTemplate({required _StemDirection direction}) {
    return _notePainterBuildLegacyFlagTemplate(direction: direction);
  }

  Path _buildPathFromTemplate(
    Path template, {
    required Offset center,
    required double targetHeight,
  }) {
    return _notePainterBuildPathFromTemplate(
      template,
      center: center,
      targetHeight: targetHeight,
    );
  }

  Offset _drawStem(
    Canvas canvas, {
    required Offset center,
    required _StemDirection direction,
    required _StemDirection xAxisDirection,
    required bool drawStem,
    required double spacing,
    double extraOppositeStemHeight = 0,
    bool useButtCap = false,
  }) {
    if (!drawStem) {
      return center;
    }

    final p = Paint()
      ..color = const Color(0xFF0E1620)
      ..strokeWidth = (spacing * 0.17).clamp(1.6, 2.8)
      ..strokeCap = useButtCap ? StrokeCap.butt : StrokeCap.round;

    final baseStemHeight = _notePainterBaseStemHeight(spacing);
    final stemX = xAxisDirection == _StemDirection.up
        ? center.dx + spacing * 0.55
        : center.dx - spacing * 0.55;
    final stemStart = direction == _StemDirection.up
        ? Offset(stemX, center.dy + extraOppositeStemHeight)
        : Offset(stemX, center.dy - extraOppositeStemHeight);
    final stemEnd = direction == _StemDirection.up
        ? Offset(stemX, center.dy - baseStemHeight)
        : Offset(stemX, center.dy + baseStemHeight);

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

  void _drawAccidental(
    Canvas canvas, {
    required String? accidental,
    required Offset center,
    required double spacing,
    required Color color,
    double scaleMultiplier = 1.0,
  }) {
    if (accidental == null) {
      return;
    }

    final smuflGlyph = switch (accidental) {
      '♯' => '\uE262',
      '♭' => '\uE260',
      '♮' => '\uE261',
      _ => null,
    };
    if (smuflGlyph == null) {
      return;
    }

    final scale = (_accidentalScale(spacing) * scaleMultiplier).clamp(0.2, 2.0);
    final fontSize = (68.0 * scale).clamp(10.0, 56.0);
    final baselineNudge = accidental == '♭' ? fontSize * 0.025 : 0.0;

    final tp = TextPainter(
      text: TextSpan(
        text: smuflGlyph,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          fontFamily: _bravuraFontFamily,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        center.dx - tp.width / 2,
        center.dy - tp.height * 0.53 + baselineNudge,
      ),
    );
  }

  void paintAccidentalGlyph(
    Canvas canvas, {
    required String accidental,
    required Offset center,
    required double spacing,
    Color color = const Color(0xFF0E1620),
    double scaleMultiplier = 1.0,
  }) {
    _drawAccidental(
      canvas,
      accidental: accidental,
      center: center,
      spacing: spacing,
      color: color,
      scaleMultiplier: scaleMultiplier,
    );
  }

  void _drawDots(
    Canvas canvas, {
    required Offset center,
    required int dotCount,
    required int noteStep,
    required bool isTreble,
    required double spacing,
    required _NoteJudge judge,
    required bool isActive,
  }) {
    if (dotCount <= 0) {
      return;
    }

    final dotRadius = (spacing * 0.2).clamp(1.5, 3.5);
    final fillColor = _noteInkColor(judge, isActive);
    final dotPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // If note head is on a staff line, shift dots up one note step so they stay visible.
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final onStaffLine = (noteStep - bottomLine).isEven;
    final dotBaseY = onStaffLine ? center.dy - (spacing / 2) : center.dy;

    // Draw dots to the right of the note head.
    final firstDotX = center.dx + spacing * 1.2;
    for (var i = 0; i < dotCount; i++) {
      final dotY = dotBaseY + (i * spacing * 0.6);
      canvas.drawCircle(Offset(firstDotX, dotY), dotRadius, dotPaint);
    }
  }

  List<List<int>> _buildBeamGroups(List<_RenderNote> visible) {
    return _notePainterBuildBeamGroups(visible);
  }

  void _normalizeBeamGroupStemDirections(
    List<_RenderNote> visible,
    List<List<int>> groups,
  ) {
    _notePainterNormalizeBeamGroupStemDirections(visible, groups);
  }

  void _drawBeamGroup(
    Canvas canvas,
    List<_RenderNote> visible,
    List<int> indexes, {
    required double lineSpacing,
    required double lockedSlope,
    required Offset lockedReferenceStemTip,
  }) {
    _notePainterDrawBeamGroup(
      canvas,
      visible,
      indexes,
      lineSpacing: lineSpacing,
      lockedSlope: lockedSlope,
      lockedReferenceStemTip: lockedReferenceStemTip,
    );
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
