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
  static const double _renderWindowPaddingMs = 1400;
  static const double _accidentalCollisionPaddingTuning = 1.0;
  static const double _accidentalCollisionPaddingScale = 0.04;
  static const double notePxPerMs = NoteTiming.notePxPerMs;
  static const int _trebleBottomLineStep = 30; // E4
  static const int _bassBottomLineStep = 18; // G2
  static const int _upperStableTrebleStep = 30; // E4+
  static const int _lowerStableBassStep = 26; // A3-
  static const int _middleSplitStep = 28; // C4 pivot
  static final Set<int> _debugLoggedNoteIndexes = <int>{};
  static final Expando<_PrecomputedScoreRenderData> _precomputedScoreCache =
      Expando<_PrecomputedScoreRenderData>('game-note-precomputed');

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
    final allNotes = <_RenderNote>[];
    final precomputedScore = _getPrecomputedScoreRenderData(score);
    final precomputedNotes = precomputedScore.notes;
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final preRenderRightPx = measureMs * notePxPerMs * _preRenderMeasuresRight;
    final windowStartMs = (currentMs - cleanupWindowMs - _renderWindowPaddingMs)
        .floor();
    final windowEndMs = (currentMs + previewWindowMs + _renderWindowPaddingMs)
        .ceil();
    final startIndex = _lowerBoundAdjustedHitMs(
      precomputedNotes,
      windowStartMs,
    );
    final endIndex = _upperBoundAdjustedHitMs(precomputedNotes, windowEndMs);

    for (var i = startIndex; i < endIndex; i++) {
      final note = score.notes[i];
      final precomputed = precomputedNotes[i];
      final adjustedHitMs = precomputed.adjustedHitMs;
      final delta = adjustedHitMs - currentMs;
      if (delta > previewWindowMs + _renderWindowPaddingMs) {
        break;
      }

      final x = playheadX + delta * notePxPerMs;
      final isUpperStaff = precomputed.isUpperStaff;
      final isTreble = precomputed.isTreble;
      final staffTop = isUpperStaff ? trebleTop : bassTop;
      final y = _yForStaffStep(note.staffStep, isTreble, staffTop, lineSpacing);
      final status = passedNoteIndexes.contains(i)
          ? _NoteJudge.pass
          : missedNoteIndexes.contains(i)
          ? _NoteJudge.miss
          : _NoteJudge.pending;
      final durationType = precomputed.durationType;
      final stemDirection = precomputed.stemDirection;

      allNotes.add(
        _RenderNote(
          index: i,
          x: x,
          y: y,
          isUpperStaff: isUpperStaff,
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
    final resolvedHeadDxByVisibleIndex = Map<int, double>.from(
      chordLayout.headDxByVisibleIndex,
    );

    for (var i = 0; i < visible.length; i++) {
      visible[i].headDx = resolvedHeadDxByVisibleIndex[i] ?? 0.0;
    }

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

            final anchorVisibleIndex = groupStemDirection == _StemDirection.up
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
        for (final visibleIndex in projected) {
          beamStemDirectionByVisibleIndex[visibleIndex] = groupStemDirection;
          final note = visible[visibleIndex];
          final layoutStemDirection =
              chordLayout.stemDirectionByVisibleIndex[visibleIndex] ??
              note.stemDirection;
          note.stemDirection = groupStemDirection;
          note.stemXAxisDirection = groupStemDirection != layoutStemDirection
              ? layoutStemDirection
              : groupStemDirection;
        }
        final lockedBeam = _buildLockedBeamGeometry(
          visible,
          projected,
          lineSpacing: lineSpacing,
        );
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

    for (final entry in chordVisibleIndexesByKey.entries) {
      final chordIndexes = entry.value;
      if (chordIndexes.length < 2) {
        continue;
      }

      _StemDirection? beamDirection;
      for (final visibleIndex in chordIndexes) {
        final direction = beamStemDirectionByVisibleIndex[visibleIndex];
        if (direction != null) {
          beamDirection = direction;
          break;
        }
      }

      if (beamDirection == null) {
        continue;
      }

      _applyClusterHeadDx(
        visible,
        chordIndexes,
        stemDirection: beamDirection,
        spacing: lineSpacing,
        headDxByVisibleIndex: resolvedHeadDxByVisibleIndex,
      );
    }

    for (var i = 0; i < visible.length; i++) {
      visible[i].headDx = resolvedHeadDxByVisibleIndex[i] ?? 0.0;
    }

    final accidentalByVisibleIndex = <int, String>{};
    final keyChanges = score.keySignatures;
    var keyChangeIndex = 0;
    var activeKeyFifths = 0;
    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final note = visible[visibleIndex];
      final noteTimeMs = note.note.hitTimeMs;
      while (keyChangeIndex < keyChanges.length &&
          keyChanges[keyChangeIndex].timeMs <= noteTimeMs) {
        activeKeyFifths = keyChanges[keyChangeIndex].fifths;
        keyChangeIndex++;
      }

      final accidentalToRender = _accidentalToRender(
        note.note,
        keyFifths: activeKeyFifths,
      );
      if (accidentalToRender != null) {
        accidentalByVisibleIndex[visibleIndex] = accidentalToRender;
      }
    }
    final accidentalCenterByVisibleIndex = _layoutAccidentals(
      visible,
      accidentalByVisibleIndex,
      noteHeadDxByVisibleIndex: resolvedHeadDxByVisibleIndex,
      spacing: lineSpacing,
    );
    final dotAnchorByVisibleIndex = _layoutDotAnchors(
      visible,
      chordLayout: chordLayout,
      chordVisibleIndexesByKey: chordVisibleIndexesByKey,
      headDxByVisibleIndex: resolvedHeadDxByVisibleIndex,
      spacing: lineSpacing,
    );
    final stemColorByVisibleIndex = <int, Color>{};
    final beamStemStartByVisibleIndex = <int, Offset>{};

    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final item = visible[visibleIndex];
      final accidentalToRender = accidentalByVisibleIndex[visibleIndex];
      final headDx = item.headDx;
      final center = Offset(item.x + headDx, item.y);
      final isActive = (item.adjustedHitMs - currentMs).abs() <= 70;
      final noteColor = _noteInkColor(item.status, isActive);
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
          'voice=${item.note.voice} staff=${item.isUpperStaff ? 1 : 2} '
          'x=${item.x.toStringAsFixed(1)} y=${item.y.toStringAsFixed(1)} '
          'midi=${item.note.midi} dur=${item.durationType}',
        );
        return true;
      }());
      _drawNoteGlyph(
        canvas,
        center: center,
        judge: item.status,
        isActive: isActive,
        durationType: item.durationType,
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
      final stemXOverride = chordLayout.stemXByAnchorVisibleIndex[visibleIndex];

      final ledgerColor = noteColor;

      _drawLedgerLines(
        canvas,
        centerX: center.dx,
        durationType: item.durationType,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        staffTop: item.isUpperStaff ? trebleTop : bassTop,
        spacing: lineSpacing,
        color: ledgerColor,
      );

      if (shouldHideTail && shouldDrawStem) {
        final stemStart = _stemStartForGeometry(
          center: center,
          direction: effectiveStemDirection,
          xAxisDirection: stemXAxisDirection,
          spacing: lineSpacing,
          extraOppositeStemHeight: chordOppositeStemHeight,
          stemXOverride: stemXOverride,
        );
        beamStemStartByVisibleIndex[visibleIndex] = stemStart;
        item.stemTip = stemStart;
      } else {
        item.stemTip = _drawStem(
          canvas,
          center: center,
          direction: effectiveStemDirection,
          xAxisDirection: stemXAxisDirection,
          drawStem: shouldDrawStem,
          spacing: lineSpacing,
          color: noteColor,
          extraOppositeStemHeight: chordOppositeStemHeight,
          stemXOverride: stemXOverride,
          useButtCap: shouldHideTail,
        );
      }

      if (!shouldHideTail && shouldDrawStem) {
        _drawFlags(
          canvas,
          stemTip: item.stemTip!,
          direction: effectiveStemDirection,
          flagCount: _flagCountForDuration(item.durationType),
          spacing: lineSpacing,
          color: noteColor,
        );
      }

      stemColorByVisibleIndex[visibleIndex] = noteColor;

      _drawAccidental(
        canvas,
        accidental: accidentalToRender,
        center:
            accidentalCenterByVisibleIndex[visibleIndex] ??
            Offset(item.x - lineSpacing * 1.08, item.y),
        spacing: lineSpacing,
        color: noteColor,
      );

      _drawDots(
        canvas,
        center: center,
        dotCount: item.note.dotCount,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        durationType: item.durationType,
        spacing: lineSpacing,
        judge: item.status,
        isActive: isActive,
        anchor: dotAnchorByVisibleIndex[visibleIndex],
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
        stemColorByVisibleIndex: stemColorByVisibleIndex,
        beamStemStartByVisibleIndex: beamStemStartByVisibleIndex,
      );
    }
  }

  _PrecomputedScoreRenderData _getPrecomputedScoreRenderData(ScoreData score) {
    final cached = _precomputedScoreCache[score];
    if (cached != null && cached.notes.length == score.notes.length) {
      return cached;
    }

    final clefChangesByStaff = _buildClefChangeTimelineByStaff(score);
    bool? previousIsUpperStaff;
    final precomputedNotes = <_PrecomputedRenderNote>[];
    for (final note in score.notes) {
      final isUpperStaff = note.staffNumber != null
          ? note.staffNumber == 1
          : _chooseStaffForNote(
              note.staffStep,
              previousIsUpperStaff: previousIsUpperStaff,
            );
      previousIsUpperStaff = isUpperStaff;

      final resolvedStaffNumber = note.staffNumber ?? (isUpperStaff ? 1 : 2);
      final fallbackIsTreble = note.isTrebleFromMxl ?? isUpperStaff;
      final isTreble = _resolveClefIsTrebleAtTime(
        clefChangesByStaff[resolvedStaffNumber],
        note.hitTimeMs,
        fallbackIsTreble: fallbackIsTreble,
      );

      precomputedNotes.add(
        _PrecomputedRenderNote(
          adjustedHitMs: NoteTiming.adjustedHitTimeMs(note),
          isUpperStaff: isUpperStaff,
          isTreble: isTreble,
          durationType: _durationTypeFromNote(note, score.bpm),
          stemDirection: _stemDirectionFromNote(note, isTreble: isTreble),
        ),
      );
    }

    final built = _PrecomputedScoreRenderData(notes: precomputedNotes);
    _precomputedScoreCache[score] = built;
    return built;
  }

  Map<int, List<(int, bool)>> _buildClefChangeTimelineByStaff(ScoreData score) {
    final byStaff = <int, List<(int, bool)>>{};
    for (final symbol in score.symbols) {
      final parsed = _parseClefSymbolLabel(symbol.label);
      if (parsed == null) {
        continue;
      }
      final (staffNumber, isTreble) = parsed;
      byStaff.putIfAbsent(staffNumber, () => <(int, bool)>[]).add((
        symbol.timeMs,
        isTreble,
      ));
    }
    for (final timeline in byStaff.values) {
      timeline.sort((a, b) => a.$1.compareTo(b.$1));
    }
    return byStaff;
  }

  (int, bool)? _parseClefSymbolLabel(String label) {
    if (!label.startsWith('Clef:')) {
      return null;
    }
    final parts = label.split(':');
    if (parts.length != 3) {
      return null;
    }
    final staffNumber = int.tryParse(parts[1]);
    final sign = parts[2].trim().toUpperCase();
    if (staffNumber == null || (sign != 'G' && sign != 'F')) {
      return null;
    }
    return (staffNumber, sign == 'G');
  }

  bool _resolveClefIsTrebleAtTime(
    List<(int, bool)>? timeline,
    int timeMs, {
    required bool fallbackIsTreble,
  }) {
    if (timeline == null || timeline.isEmpty) {
      return fallbackIsTreble;
    }

    var active = fallbackIsTreble;
    for (final point in timeline) {
      if (point.$1 > timeMs) {
        break;
      }
      active = point.$2;
    }
    return active;
  }

  int _lowerBoundAdjustedHitMs(List<_PrecomputedRenderNote> notes, int target) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].adjustedHitMs < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundAdjustedHitMs(List<_PrecomputedRenderNote> notes, int target) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].adjustedHitMs <= target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
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

  Map<int, Offset> _layoutDotAnchors(
    List<_RenderNote> visible, {
    required _ChordLayout chordLayout,
    required Map<String, List<int>> chordVisibleIndexesByKey,
    required Map<int, double> headDxByVisibleIndex,
    required double spacing,
  }) {
    final anchors = <int, Offset>{};
    final dotRadius = (spacing * 0.2).clamp(1.5, 3.5).toDouble();

    final dottedVisibleIndexes = <int>[
      for (var i = 0; i < visible.length; i++)
        if (visible[i].note.dotCount > 0) i,
    ];

    final groups = <String, List<int>>{};
    for (final visibleIndex in dottedVisibleIndexes) {
      final chordKey = chordLayout.chordKeyByVisibleIndex[visibleIndex];
      final groupKey = chordKey ?? 'single:$visibleIndex';
      groups.putIfAbsent(groupKey, () => <int>[]).add(visibleIndex);
    }

    for (final entry in groups.entries) {
      final group = entry.value;
      if (group.isEmpty) {
        continue;
      }

      final isSingleGroup = entry.key.startsWith('single:');
      final chordIndexes = isSingleGroup
          ? group
          : (chordVisibleIndexesByKey[entry.key] ?? group);

      final chordCenters = <int, Offset>{};
      var rightMostHeadX = double.negativeInfinity;
      for (final idx in chordIndexes) {
        final headDx = headDxByVisibleIndex[idx] ?? 0.0;
        final center = Offset(visible[idx].x + headDx, visible[idx].y);
        chordCenters[idx] = center;
        rightMostHeadX = math.max(rightMostHeadX, center.dx);
      }
      var chordDotGap = 0.0;
      for (final idx in chordIndexes) {
        chordDotGap = math.max(
          chordDotGap,
          _dotLeadingGapForDuration(visible[idx].durationType, spacing),
        );
      }

      final headRects = <Rect>[
        for (final center in chordCenters.values)
          Rect.fromCenter(
            center: center,
            width: spacing * 1.6,
            height: spacing * 1.3,
          ),
      ];

      final placedDotAnchors = <Offset>[];
      final sortedGroup = List<int>.from(group)
        ..sort((a, b) => visible[a].y.compareTo(visible[b].y));

      for (final idx in sortedGroup) {
        final note = visible[idx];
        final noteCenter =
            chordCenters[idx] ??
            Offset(note.x + (headDxByVisibleIndex[idx] ?? 0.0), note.y);

        final baseAnchor = _defaultDotAnchor(
          center: noteCenter,
          noteStep: note.noteStep,
          isTreble: note.isTreble,
          durationType: note.durationType,
          spacing: spacing,
        );

        final baseX = math.max(baseAnchor.dx, rightMostHeadX + chordDotGap);
        // Keep augmentation dots on spaces only (avoid staff lines).
        final candidateYs = <double>[
          baseAnchor.dy,
          baseAnchor.dy - spacing,
          baseAnchor.dy + spacing,
          baseAnchor.dy - spacing * 2,
          baseAnchor.dy + spacing * 2,
        ];

        Offset? chosenAnchor;
        for (var xShift = 0; xShift <= 3 && chosenAnchor == null; xShift++) {
          final candidateX = baseX + xShift * spacing * 0.36;
          for (final candidateY in candidateYs) {
            // If another note in this chord already uses the same space lane,
            // reuse that exact anchor so both notes share one visible dot.
            final sharedAnchor = placedDotAnchors.firstWhere(
              (other) => (other.dy - candidateY).abs() < spacing * 0.08,
              orElse: () => const Offset(double.nan, double.nan),
            );
            if (!sharedAnchor.dx.isNaN) {
              chosenAnchor = sharedAnchor;
              break;
            }

            final candidate = Offset(candidateX, candidateY);
            final candidateRect = Rect.fromCircle(
              center: candidate,
              radius: dotRadius + spacing * 0.08,
            );

            final overlapsHead = headRects.any(
              (headRect) => headRect.overlaps(candidateRect),
            );
            if (overlapsHead) {
              continue;
            }

            final overlapsPlacedDot = placedDotAnchors.any((other) {
              final dx = (other.dx - candidate.dx).abs();
              final dy = (other.dy - candidate.dy).abs();
              return dx < dotRadius * 2.4 && dy < spacing * 0.45;
            });
            if (overlapsPlacedDot) {
              continue;
            }

            chosenAnchor = candidate;
            break;
          }
        }

        if (chosenAnchor == null) {
          final fallbackY = _snapDotYToNearestSpace(
            baseAnchor.dy,
            baseSpaceY: baseAnchor.dy,
            spacing: spacing,
          );
          chosenAnchor = Offset(baseX + spacing * 1.1, fallbackY);
        }
        anchors[idx] = chosenAnchor;
        placedDotAnchors.add(chosenAnchor);
      }
    }

    return anchors;
  }

  double _snapDotYToNearestSpace(
    double y, {
    required double baseSpaceY,
    required double spacing,
  }) {
    if (spacing <= 0) {
      return y;
    }
    final step = ((y - baseSpaceY) / spacing).roundToDouble();
    return baseSpaceY + step * spacing;
  }

  double _accidentalScale(double spacing) {
    return _notePainterAccidentalScale(spacing);
  }

  void _applyClusterHeadDx(
    List<_RenderNote> visible,
    List<int> indexes, {
    required _StemDirection stemDirection,
    required double spacing,
    required Map<int, double> headDxByVisibleIndex,
  }) {
    if (indexes.isEmpty) {
      return;
    }

    final sortedIndexes = List<int>.from(indexes)
      ..sort((a, b) {
        final stepCompare = visible[a].noteStep.compareTo(visible[b].noteStep);
        if (stepCompare != 0) {
          return stepCompare;
        }
        return a.compareTo(b);
      });

    for (final idx in sortedIndexes) {
      headDxByVisibleIndex[idx] = 0.0;
    }

    var runStart = 0;
    while (runStart < sortedIndexes.length) {
      var runEnd = runStart;
      var prevStep = visible[sortedIndexes[runStart]].noteStep;

      while (runEnd + 1 < sortedIndexes.length) {
        final nextIndex = sortedIndexes[runEnd + 1];
        final nextStep = visible[nextIndex].noteStep;
        if (nextStep - prevStep != 1) {
          break;
        }

        prevStep = nextStep;
        runEnd++;
      }

      final runLength = runEnd - runStart + 1;
      if (runLength >= 2) {
        for (var i = runStart; i <= runEnd; i++) {
          final current = sortedIndexes[i];
          final offsetInRun = i - runStart;

          if (stemDirection == _StemDirection.up) {
            headDxByVisibleIndex[current] = offsetInRun.isOdd ? spacing : 0.0;
          } else {
            headDxByVisibleIndex[current] = offsetInRun.isEven ? -spacing : 0.0;
          }
        }
      }

      runStart = runEnd + 1;
    }
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
    final stemXByAnchorVisibleIndex = <int, double>{};

    final groups = <String, List<int>>{};
    for (var i = 0; i < visible.length; i++) {
      final note = visible[i];
      final key =
          '${note.adjustedHitMs}-${note.isUpperStaff ? 't' : 'b'}-${note.note.voice}';
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
        headDxByVisibleIndex[idx] = 0.0;
      }

      // Chỉ lệch notehead để tránh va chạm khi có khoảng cách 1 staff step.
      // Các cụm nốt liên tiếp được xếp so le. Với stem down, nốt đầu tiên
      // của cụm (nốt thấp nhất) lệch sang trái; với stem up, nốt thứ hai lệch
      // sang phải.
      _applyClusterHeadDx(
        visible,
        sortedIndexes,
        stemDirection: stemDirection,
        spacing: spacing,
        headDxByVisibleIndex: headDxByVisibleIndex,
      );

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

      final anchorColumnX = visible[anchor].x;

      stemXByAnchorVisibleIndex[anchor] = stemDirection == _StemDirection.up
          ? anchorColumnX + spacing * 0.55
          : anchorColumnX - spacing * 0.55;
    }

    return _ChordLayout(
      stemDirectionByVisibleIndex: stemDirectionByVisibleIndex,
      headDxByVisibleIndex: headDxByVisibleIndex,
      stemAnchorVisibleIndexes: stemAnchorVisibleIndexes,
      chordMemberVisibleIndexes: chordMemberVisibleIndexes,
      chordKeyByVisibleIndex: chordKeyByVisibleIndex,
      stemExtraHeightByAnchorVisibleIndex: stemExtraHeightByAnchorVisibleIndex,
      stemXByAnchorVisibleIndex: stemXByAnchorVisibleIndex,
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

  bool _chooseStaffForNote(
    int staffStep, {
    required bool? previousIsUpperStaff,
  }) {
    if (staffStep >= _upperStableTrebleStep) {
      return true;
    }
    if (staffStep <= _lowerStableBassStep) {
      return false;
    }
    if (previousIsUpperStaff != null) {
      return previousIsUpperStaff;
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
      (_DurationType.thirtySecond, 0.125),
    ];

    var best = candidates.first;
    var bestDelta = (beats - best.$2).abs();
    for (final candidate in candidates.skip(1)) {
      final delta = (beats - candidate.$2).abs();
      if (delta <= bestDelta) {
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
      _DurationType.thirtySecond => 3,
      _ => 0,
    };
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
    required _DurationType durationType,
    required int noteStep,
    required bool isTreble,
    required double staffTop,
    required double spacing,
    required Color color,
  }) {
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final topLine = bottomLine + 8;
    final ledgerPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    final halfLength = (spacing * 0.95).clamp(8.0, 14.0);
    final leftHalfLength = durationType == _DurationType.whole
        ? halfLength * 1.45
        : halfLength;

    if (noteStep > topLine) {
      for (
        var ledgerStep = topLine + 2;
        ledgerStep <= noteStep;
        ledgerStep += 2
      ) {
        final y = _yForStaffStep(ledgerStep, isTreble, staffTop, spacing);
        canvas.drawLine(
          Offset(centerX - leftHalfLength, y),
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
          Offset(centerX - leftHalfLength, y),
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
    final wholeTargetHeight = (spacing * 1.15).clamp(8.0, 20.0);
    final headTargetHeight = (spacing * 1.07).clamp(7.5, 18.0);
    final fillPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (spacing * 0.12).clamp(1.1, 1.9)
      ..isAntiAlias = true;

    if (durationType == _DurationType.whole) {
      final wholeHead = _wholeHeadTemplate();
      final refBounds = wholeHead.getBounds();
      final wholeScaledTargetHeight = (wholeTargetHeight * 1.2).clamp(
        9.6,
        24.0,
      );

      _drawTemplatePathAligned(
        canvas,
        wholeHead,
        referenceBounds: refBounds,
        center: center,
        targetHeight: wholeScaledTargetHeight,
        paint: fillPaint,
      );
      _drawTemplatePathAligned(
        canvas,
        wholeHead,
        referenceBounds: refBounds,
        center: center,
        targetHeight: wholeScaledTargetHeight,
        paint: borderPaint,
      );
      return;
    }

    if (durationType == _DurationType.half) {
      final halfHead = _halfHeadTemplate();
      final refBounds = halfHead.getBounds();
      final halfTargetHeight = (headTargetHeight * 1).clamp(9.0, 21.6);

      _drawTemplatePathAligned(
        canvas,
        halfHead,
        referenceBounds: refBounds,
        center: center,
        targetHeight: halfTargetHeight,
        paint: fillPaint,
      );

      _drawTemplatePathAligned(
        canvas,
        halfHead,
        referenceBounds: refBounds,
        center: center,
        targetHeight: halfTargetHeight,
        paint: borderPaint,
      );
      return;
    }

    final quarterHead = _quarterHeadTemplate();
    final refBounds = quarterHead.getBounds();
    final quarterTargetHeight = (headTargetHeight * 1).clamp(9.0, 21.6);

    _drawTemplatePathAligned(
      canvas,
      quarterHead,
      referenceBounds: refBounds,
      center: center,
      targetHeight: quarterTargetHeight,
      paint: fillPaint,
    );

    _drawTemplatePathAligned(
      canvas,
      quarterHead,
      referenceBounds: refBounds,
      center: center,
      targetHeight: quarterTargetHeight,
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

  Path _halfHeadTemplate() => _notePainterHalfHeadTemplate();

  Path _wholeHeadTemplate() => _notePainterWholeHeadTemplate();

  Path _buildLegacyFlagTemplate({required _StemDirection direction}) {
    return _notePainterBuildLegacyFlagTemplate(direction: direction);
  }

  Offset _stemTipForGeometry({
    required Offset center,
    required _StemDirection direction,
    required _StemDirection xAxisDirection,
    required double spacing,
    double extraOppositeStemHeight = 0,
    double? stemXOverride,
  }) {
    final baseStemHeight = _notePainterBaseStemHeight(spacing);
    final stemX =
        stemXOverride ??
        (xAxisDirection == _StemDirection.up
            ? center.dx + spacing * 0.55
            : center.dx - spacing * 0.55);
    return direction == _StemDirection.up
        ? Offset(stemX, center.dy - baseStemHeight)
        : Offset(stemX, center.dy + baseStemHeight);
  }

  double _resolveStemEntryOppositeReach(
    double extraOppositeStemHeight,
    double spacing,
  ) {
    if (extraOppositeStemHeight <= 0) {
      return 0.0;
    }

    // Với quãng 2 (hai nốt liền nhau), trục stem nên đi vào trung điểm
    // giữa hai tâm notehead thay vì chạm đúng tâm nốt đối diện.
    final adjacentStepHeight = spacing * 0.5;
    final tolerance = spacing * 0.12;
    if ((extraOppositeStemHeight - adjacentStepHeight).abs() <= tolerance) {
      return extraOppositeStemHeight * 0.5;
    }

    return extraOppositeStemHeight;
  }

  Offset _stemStartForGeometry({
    required Offset center,
    required _StemDirection direction,
    required _StemDirection xAxisDirection,
    required double spacing,
    double extraOppositeStemHeight = 0,
    double? stemXOverride,
  }) {
    final stemX =
        stemXOverride ??
        (xAxisDirection == _StemDirection.up
            ? center.dx + spacing * 0.55
            : center.dx - spacing * 0.55);
    final oppositeReach = _resolveStemEntryOppositeReach(
      extraOppositeStemHeight,
      spacing,
    );
    return direction == _StemDirection.up
        ? Offset(stemX, center.dy + oppositeReach)
        : Offset(stemX, center.dy - oppositeReach);
  }

  Offset _drawStem(
    Canvas canvas, {
    required Offset center,
    required _StemDirection direction,
    required _StemDirection xAxisDirection,
    required bool drawStem,
    required double spacing,
    required Color color,
    double extraOppositeStemHeight = 0,
    double? stemXOverride,
    bool useButtCap = false,
  }) {
    if (!drawStem) {
      return center;
    }

    final p = Paint()
      ..color = color
      ..strokeWidth = (spacing * 0.22).clamp(2.0, 3.6)
      ..strokeCap = useButtCap ? StrokeCap.butt : StrokeCap.round;

    final stemX =
        stemXOverride ??
        (xAxisDirection == _StemDirection.up
            ? center.dx + spacing * 0.55
            : center.dx - spacing * 0.55);
    final stemStart = _stemStartForGeometry(
      center: center,
      direction: direction,
      xAxisDirection: xAxisDirection,
      spacing: spacing,
      extraOppositeStemHeight: extraOppositeStemHeight,
      stemXOverride: stemXOverride,
    );
    final stemEnd = _stemTipForGeometry(
      center: center,
      direction: direction,
      xAxisDirection: xAxisDirection,
      spacing: spacing,
      extraOppositeStemHeight: extraOppositeStemHeight,
      stemXOverride: stemXOverride,
    );

    canvas.drawLine(stemStart, stemEnd, p);
    return stemEnd;
  }

  void _drawFlags(
    Canvas canvas, {
    required Offset stemTip,
    required _StemDirection direction,
    required int flagCount,
    required double spacing,
    required Color color,
  }) {
    if (flagCount <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stemDirectionNudge = spacing * 0.6;

    for (var i = 0; i < flagCount; i++) {
      final yOffset = i * (spacing * 0.72);
      final anchor = direction == _StemDirection.up
          ? Offset(stemTip.dx, stemTip.dy + stemDirectionNudge + yOffset)
          : Offset(stemTip.dx, stemTip.dy - stemDirectionNudge - yOffset);

      final template = _buildLegacyFlagTemplate(direction: direction);
      final bounds = template.getBounds();
      if (bounds.height == 0) {
        continue;
      }

      final flagTargetHeight = (spacing * 2.2).clamp(14.0, 30.0);
      final scale = flagTargetHeight / bounds.height;
      final matrix = Matrix4.identity()
        ..translate(anchor.dx, anchor.dy)
        ..scale(scale, scale);
      final path = template.transform(matrix.storage);
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
    required _DurationType durationType,
    required double spacing,
    required _NoteJudge judge,
    required bool isActive,
    Offset? anchor,
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

    final dotAnchor =
        anchor ??
        _defaultDotAnchor(
          center: center,
          noteStep: noteStep,
          isTreble: isTreble,
          durationType: durationType,
          spacing: spacing,
        );

    final firstDotX = dotAnchor.dx;
    final dotY = dotAnchor.dy;
    final interDotDx = _dotInterSpacingForDuration(durationType, spacing);
    for (var i = 0; i < dotCount; i++) {
      final dotX = firstDotX + (i * interDotDx);
      canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
    }
  }

  Offset _defaultDotAnchor({
    required Offset center,
    required int noteStep,
    required bool isTreble,
    required _DurationType durationType,
    required double spacing,
  }) {
    // If note head is on a staff line, shift dots up one note step so they stay visible.
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final onStaffLine = (noteStep - bottomLine).isEven;
    final dotBaseY = onStaffLine ? center.dy - (spacing / 2) : center.dy;
    final leadingGap = _dotLeadingGapForDuration(durationType, spacing);
    return Offset(center.dx + leadingGap, dotBaseY);
  }

  double _dotLeadingGapForDuration(_DurationType durationType, double spacing) {
    return switch (durationType) {
      _DurationType.whole => spacing * 1.42,
      _DurationType.half => spacing * 1.3,
      _DurationType.quarter ||
      _DurationType.eighth ||
      _DurationType.sixteenth ||
      _DurationType.thirtySecond => spacing * 1.18,
    };
  }

  double _dotInterSpacingForDuration(
    _DurationType durationType,
    double spacing,
  ) {
    return switch (durationType) {
      _DurationType.whole => spacing * 0.62,
      _DurationType.half => spacing * 0.6,
      _DurationType.quarter ||
      _DurationType.eighth ||
      _DurationType.sixteenth ||
      _DurationType.thirtySecond => spacing * 0.56,
    };
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
    required Map<int, Color> stemColorByVisibleIndex,
    required Map<int, Offset> beamStemStartByVisibleIndex,
  }) {
    _notePainterDrawBeamGroup(
      canvas,
      visible,
      indexes,
      lineSpacing: lineSpacing,
      lockedSlope: lockedSlope,
      lockedReferenceStemTip: lockedReferenceStemTip,
      stemColorByVisibleIndex: stemColorByVisibleIndex,
      beamStemStartByVisibleIndex: beamStemStartByVisibleIndex,
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
