import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
import '../notation/notation_metrics.dart';
import 'game_text_painter.dart';

part 'game_note_painter_models.dart';
part 'game_note_painter_paths.dart';
part 'game_note_painter_accidentals.dart';
part 'game_note_painter_beam.dart';
part 'game_note_painter_slur.dart';

class GameNotePainter {
  static const bool _enablePaintNoteDebugLog = false;
  static const String _bravuraFontFamily = 'Bravura';
  static const double previewWindowMs = 9000;
  static const double cleanupWindowMs = 2500;
  static const double _preRenderMeasuresRight = 20;
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
  static final Expando<Map<String, int>> _slurLaneCacheByScore =
      Expando<Map<String, int>>('game-note-slur-lane-cache');
  static final Expando<Map<String, double>>
  _slurBodyCollisionBoostCacheByScore = Expando<Map<String, double>>(
    'game-note-slur-body-collision-cache',
  );
  static final GameTextPainter _sharedTextPainter = GameTextPainter();
  static final Path _quarterHeadTemplateCached =
      _notePainterQuarterHeadTemplate();
  static final Rect _quarterHeadBoundsCached = _quarterHeadTemplateCached
      .getBounds();
  static final Path _halfHeadTemplateCached = _notePainterHalfHeadTemplate();
  static final Rect _halfHeadBoundsCached = _halfHeadTemplateCached.getBounds();
  static final Path _wholeHeadTemplateCached = _notePainterWholeHeadTemplate();
  static final Rect _wholeHeadBoundsCached = _wholeHeadTemplateCached
      .getBounds();
  static final Map<_StemDirection, Path> _flagTemplateByDirection =
      <_StemDirection, Path>{
        _StemDirection.up: _notePainterBuildLegacyFlagTemplate(
          direction: _StemDirection.up,
        ),
        _StemDirection.down: _notePainterBuildLegacyFlagTemplate(
          direction: _StemDirection.down,
        ),
      };
  static final Map<_StemDirection, Rect> _flagBoundsByDirection =
      <_StemDirection, Rect>{
        _StemDirection.up: _flagTemplateByDirection[_StemDirection.up]!
            .getBounds(),
        _StemDirection.down: _flagTemplateByDirection[_StemDirection.down]!
            .getBounds(),
      };

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
    required NotationMetrics metrics,
  }) {
    final lineSpacing = metrics.staffSpace;
    final precomputedScore = _getPrecomputedScoreRenderData(score);
    final precomputedNotes = precomputedScore.notes;
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final preRenderRightMs = measureMs * _preRenderMeasuresRight;
    final preRenderRightPx = measureMs * notePxPerMs * _preRenderMeasuresRight;
    final effectivePreviewWindowMs = math.max(
      previewWindowMs,
      preRenderRightMs,
    );
    final windowStartMs = (currentMs - cleanupWindowMs - _renderWindowPaddingMs)
        .floor();
    final windowEndMs =
        (currentMs + effectivePreviewWindowMs + _renderWindowPaddingMs).ceil();
    final startIndex = _lowerBoundAdjustedHitMs(
      precomputedNotes,
      windowStartMs,
    );
    final endIndex = _upperBoundAdjustedHitMs(precomputedNotes, windowEndMs);
    final visible = <_RenderNote>[];

    for (var i = startIndex; i < endIndex; i++) {
      final note = score.notes[i];
      final precomputed = precomputedNotes[i];
      final adjustedHitMs = precomputed.adjustedHitMs;
      final anchorTime =
          precomputedScore.beamAnchorAdjustedHitMsByScoreIndex[i] ??
          adjustedHitMs;
      final anchorDelta = anchorTime - currentMs;
      if (anchorDelta > effectivePreviewWindowMs ||
          anchorDelta < -cleanupWindowMs) {
        continue;
      }

      final status = passedNoteIndexes.contains(i)
          ? _NoteJudge.pass
          : missedNoteIndexes.contains(i)
          ? _NoteJudge.miss
          : _NoteJudge.pending;
      final x = playheadX + (adjustedHitMs - currentMs) * notePxPerMs;
      if (x < -30 || x > size.width + preRenderRightPx) {
        continue;
      }

      final isUpperStaff = precomputed.isUpperStaff;
      final isTreble = precomputed.isTreble;
      final staffTop = isUpperStaff ? trebleTop : bassTop;
      final y = _yForStaffStep(note.staffStep, isTreble, staffTop, lineSpacing);

      visible.add(
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
          durationType: precomputed.durationType,
          accidentalToRender: precomputed.accidentalToRender,
          stemDirection: precomputed.stemDirection,
          stemXAxisDirection: precomputed.stemDirection,
        ),
      );
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
    for (final group in precomputedScore.beamGroupsByScoreIndex) {
      final hasMissingBeamMember = group.any(
        (scoreIndex) => visibleIndexByScoreIndex[scoreIndex] == null,
      );
      if (hasMissingBeamMember) {
        continue;
      }

      final projected = <int>[];
      final projectedChordKeys = <String>{};
      final groupStemDirection = precomputedNotes[group.first].stemDirection;
      for (final scoreIndex in group) {
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
    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final accidentalToRender = visible[visibleIndex].accidentalToRender;
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
    final staccatoAnchorByVisibleIndex = _layoutStaccatoAnchors(
      visible,
      chordLayout: chordLayout,
      chordVisibleIndexesByKey: chordVisibleIndexesByKey,
      headDxByVisibleIndex: resolvedHeadDxByVisibleIndex,
      spacing: lineSpacing,
    );
    final beamEdgeYByVisibleIndex = _layoutBeamEdgeYByVisibleIndex(
      visible,
      beamGroups,
      spacing: lineSpacing,
    );
    final fingeringAnchorByVisibleIndex = _layoutFingeringAnchors(
      visible,
      chordLayout: chordLayout,
      chordVisibleIndexesByKey: chordVisibleIndexesByKey,
      headDxByVisibleIndex: resolvedHeadDxByVisibleIndex,
      staccatoAnchorByVisibleIndex: staccatoAnchorByVisibleIndex,
      beamEdgeYByVisibleIndex: beamEdgeYByVisibleIndex,
      trebleTop: trebleTop,
      bassTop: bassTop,
      spacing: lineSpacing,
    );
    final stemColorByVisibleIndex = <int, Color>{};
    final beamStemStartByVisibleIndex = <int, Offset>{};
    final pendingAccidentals =
        <({String accidental, Offset center, Color color})>[];
    final pendingDots =
        <
          ({
            Offset center,
            int dotCount,
            int noteStep,
            bool isTreble,
            _DurationType durationType,
            Color color,
            Offset? anchor,
          })
        >[];
    final pendingStaccatos =
        <
          ({
            Offset center,
            _StemDirection direction,
            int referenceNoteStep,
            bool isTreble,
            Color color,
          })
        >[];
    final pendingFingerings = <({String text, Offset center, Color color})>[];

    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final item = visible[visibleIndex];
      final accidentalToRender = item.accidentalToRender;
      final headDx = item.headDx;
      final center = Offset(item.x + headDx, item.y);
      final isActive = (item.adjustedHitMs - currentMs).abs() <= 70;
      final baseNoteColor = _noteInkColor(
        item.status,
        isActive,
        colors: score.colors,
      );
      final noteColor = _notePainterApplyOpacity(
        baseNoteColor,
        _notePainterLeftFadeOpacityAtX(center.dx, playheadX, metrics),
      );
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
        durationType: item.durationType,
        metrics: metrics,
        color: noteColor,
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
        playheadX: playheadX,
        metrics: metrics,
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

      stemColorByVisibleIndex[visibleIndex] = baseNoteColor;

      if (accidentalToRender != null) {
        pendingAccidentals.add((
          accidental: accidentalToRender,
          center:
              accidentalCenterByVisibleIndex[visibleIndex] ??
              Offset(item.x - lineSpacing * 1.08, item.y),
          color: _notePainterApplyOpacity(
            score.colors.accidentalAndSlur.accidental,
            _notePainterLeftFadeOpacityAtX(
              (accidentalCenterByVisibleIndex[visibleIndex] ??
                      Offset(item.x - lineSpacing * 1.08, item.y))
                  .dx,
              playheadX,
              metrics,
            ),
          ),
        ));
      }

      pendingDots.add((
        center: center,
        dotCount: item.note.dotCount,
        noteStep: item.noteStep,
        isTreble: item.isTreble,
        durationType: item.durationType,
        color: _notePainterApplyOpacity(
          baseNoteColor,
          _notePainterLeftFadeOpacityAtX(
            (dotAnchorByVisibleIndex[visibleIndex] ?? center).dx,
            playheadX,
            metrics,
          ),
        ),
        anchor: dotAnchorByVisibleIndex[visibleIndex],
      ));

      final chordIndexesForStaccato = chordKey != null
          ? chordVisibleIndexesByKey[chordKey]
          : null;
      final chordHasStaccato = chordIndexesForStaccato == null
          ? item.note.isStaccato
          : chordIndexesForStaccato.any((idx) => visible[idx].note.isStaccato);

      final shouldRenderStaccatoForThisItem = chordIndexesForStaccato == null
          ? chordHasStaccato
          : (() {
              if (!chordHasStaccato) {
                return false;
              }

              final representativeVisibleIndex =
                  effectiveStemDirection == _StemDirection.up
                  ? chordIndexesForStaccato.reduce(
                      (a, b) =>
                          visible[a].noteStep <= visible[b].noteStep ? a : b,
                    )
                  : chordIndexesForStaccato.reduce(
                      (a, b) =>
                          visible[a].noteStep >= visible[b].noteStep ? a : b,
                    );

              return representativeVisibleIndex == visibleIndex;
            })();

      if (shouldRenderStaccatoForThisItem) {
        final referenceVisibleIndex = chordIndexesForStaccato == null
            ? visibleIndex
            : (effectiveStemDirection == _StemDirection.up
                  ? chordIndexesForStaccato.reduce(
                      (a, b) =>
                          visible[a].noteStep <= visible[b].noteStep ? a : b,
                    )
                  : chordIndexesForStaccato.reduce(
                      (a, b) =>
                          visible[a].noteStep >= visible[b].noteStep ? a : b,
                    ));

        final referenceItem = visible[referenceVisibleIndex];
        final referenceCenter = Offset(
          referenceItem.x + referenceItem.headDx,
          referenceItem.y,
        );

        pendingStaccatos.add((
          center: referenceCenter,
          direction: effectiveStemDirection,
          referenceNoteStep: referenceItem.noteStep,
          isTreble: referenceItem.isTreble,
          color: _notePainterApplyOpacity(
            baseNoteColor,
            _notePainterLeftFadeOpacityAtX(
              referenceCenter.dx,
              playheadX,
              metrics,
            ),
          ),
        ));
      }

      final fingering = item.note.fingering;
      if (fingering != null && fingering.isNotEmpty) {
        final chordIndexesForFingering = chordKey != null
            ? chordVisibleIndexesByKey[chordKey]
            : null;

        final shouldRenderFingeringForThisItem =
            chordIndexesForFingering == null
            ? true
            : (() {
                final sortedChordIndexes =
                    List<int>.from(chordIndexesForFingering)..sort(
                      (a, b) =>
                          visible[a].noteStep.compareTo(visible[b].noteStep),
                    );
                return sortedChordIndexes.contains(visibleIndex);
              })();

        if (shouldRenderFingeringForThisItem) {
          final anchor = fingeringAnchorByVisibleIndex[visibleIndex];
          if (anchor != null) {
            pendingFingerings.add((
              text: fingering,
              center: anchor,
              color: _notePainterApplyOpacity(
                score.colors.fingering.text,
                _notePainterLeftFadeOpacityAtX(anchor.dx, playheadX, metrics),
              ),
            ));
          }
        }
      }
    }

    for (final group in beamGroups) {
      _drawBeamGroup(
        canvas,
        visible,
        group.indexes,
        lineSpacing: lineSpacing,
        lockedSlope: group.lockedSlope,
        lockedReferenceStemTip: group.lockedReferenceStemTip,
        colors: score.colors,
        stemColorByVisibleIndex: stemColorByVisibleIndex,
        beamStemStartByVisibleIndex: beamStemStartByVisibleIndex,
        playheadX: playheadX,
        metrics: metrics,
      );
    }

    for (final dot in pendingDots) {
      _drawDots(
        canvas,
        center: dot.center,
        dotCount: dot.dotCount,
        noteStep: dot.noteStep,
        isTreble: dot.isTreble,
        durationType: dot.durationType,
        spacing: lineSpacing,
        color: dot.color,
        anchor: dot.anchor,
      );
    }

    for (final staccato in pendingStaccatos) {
      _drawStaccatoMark(
        canvas,
        center: staccato.center,
        direction: staccato.direction,
        spacing: lineSpacing,
        color: staccato.color,
        referenceNoteStep: staccato.referenceNoteStep,
        isTreble: staccato.isTreble,
      );
    }

    for (final fingering in pendingFingerings) {
      _drawFingering(
        canvas,
        text: fingering.text,
        center: fingering.center,
        spacing: lineSpacing,
        color: fingering.color,
      );
    }

    for (final accidental in pendingAccidentals) {
      _drawAccidental(
        canvas,
        accidental: accidental.accidental,
        center: accidental.center,
        spacing: lineSpacing,
        color: accidental.color,
      );
    }

    this._drawSlurs(
      canvas,
      score: score,
      precomputedScore: precomputedScore,
      passedNoteIndexes: passedNoteIndexes,
      missedNoteIndexes: missedNoteIndexes,
      visible: visible,
      visibleIndexByScoreIndex: visibleIndexByScoreIndex,
      chordLayout: chordLayout,
      chordVisibleIndexesByKey: chordVisibleIndexesByKey,
      accidentalCenterByVisibleIndex: accidentalCenterByVisibleIndex,
      dotAnchorByVisibleIndex: dotAnchorByVisibleIndex,
      staccatoAnchorByVisibleIndex: staccatoAnchorByVisibleIndex,
      fingeringAnchorByVisibleIndex: fingeringAnchorByVisibleIndex,
      beamEdgeYByVisibleIndex: beamEdgeYByVisibleIndex,
      size: size,
      currentMs: currentMs,
      playheadX: playheadX,
      trebleTop: trebleTop,
      bassTop: bassTop,
      metrics: metrics,
    );
  }

  _PrecomputedScoreRenderData _getPrecomputedScoreRenderData(ScoreData score) {
    final cached = _precomputedScoreCache[score];
    if (cached != null && cached.notes.length == score.notes.length) {
      return cached;
    }

    final clefChangesByStaff = _buildClefChangeTimelineByStaff(score);
    final keyChanges = score.keySignatures;
    bool? previousIsUpperStaff;
    final precomputedNotes = <_PrecomputedRenderNote>[];
    var keyChangeIndex = 0;
    var activeKeyFifths = 0;
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
      while (keyChangeIndex < keyChanges.length &&
          keyChanges[keyChangeIndex].timeMs <= note.hitTimeMs) {
        activeKeyFifths = keyChanges[keyChangeIndex].fifths;
        keyChangeIndex++;
      }

      precomputedNotes.add(
        _PrecomputedRenderNote(
          adjustedHitMs: NoteTiming.adjustedHitTimeMs(note),
          isUpperStaff: isUpperStaff,
          isTreble: isTreble,
          durationType: _durationTypeFromNote(note, score.bpm),
          accidentalToRender: _accidentalToRender(
            note,
            keyFifths: activeKeyFifths,
          ),
          stemDirection: _stemDirectionFromNote(note, isTreble: isTreble),
        ),
      );
    }

    final beamSeedNotes = <_RenderNote>[
      for (var i = 0; i < score.notes.length; i++)
        _RenderNote(
          index: i,
          x: 0,
          y: 0,
          isUpperStaff: precomputedNotes[i].isUpperStaff,
          isTreble: precomputedNotes[i].isTreble,
          noteStep: score.notes[i].staffStep,
          note: score.notes[i],
          adjustedHitMs: precomputedNotes[i].adjustedHitMs,
          status: _NoteJudge.pending,
          durationType: precomputedNotes[i].durationType,
          accidentalToRender: precomputedNotes[i].accidentalToRender,
          stemDirection: precomputedNotes[i].stemDirection,
          stemXAxisDirection: precomputedNotes[i].stemDirection,
        ),
    ];
    final beamGroups = _buildBeamGroups(beamSeedNotes);
    _normalizeBeamGroupStemDirections(beamSeedNotes, beamGroups);
    final beamAnchorAdjustedHitMsByScoreIndex = List<int?>.filled(
      score.notes.length,
      null,
    );
    for (final group in beamGroups) {
      if (group.isEmpty) {
        continue;
      }
      final anchorTime = beamSeedNotes[group.last].adjustedHitMs;
      for (final scoreIndex in group) {
        beamAnchorAdjustedHitMsByScoreIndex[scoreIndex] = anchorTime;
      }
    }
    for (var i = 0; i < precomputedNotes.length; i++) {
      final precomputed = precomputedNotes[i];
      final normalizedStemDirection = beamSeedNotes[i].stemDirection;
      precomputedNotes[i] = _PrecomputedRenderNote(
        adjustedHitMs: precomputed.adjustedHitMs,
        isUpperStaff: precomputed.isUpperStaff,
        isTreble: precomputed.isTreble,
        durationType: precomputed.durationType,
        accidentalToRender: precomputed.accidentalToRender,
        stemDirection: normalizedStemDirection,
      );
    }

    final built = _PrecomputedScoreRenderData(
      notes: List<_PrecomputedRenderNote>.unmodifiable(precomputedNotes),
      beamGroupsByScoreIndex: List<List<int>>.unmodifiable(
        beamGroups.map((group) => List<int>.unmodifiable(group)),
      ),
      beamAnchorAdjustedHitMsByScoreIndex: List<int?>.unmodifiable(
        beamAnchorAdjustedHitMsByScoreIndex,
      ),
    );
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

  Map<int, Offset> _layoutStaccatoAnchors(
    List<_RenderNote> visible, {
    required _ChordLayout chordLayout,
    required Map<String, List<int>> chordVisibleIndexesByKey,
    required Map<int, double> headDxByVisibleIndex,
    required double spacing,
  }) {
    final anchors = <int, Offset>{};

    for (var visibleIndex = 0; visibleIndex < visible.length; visibleIndex++) {
      final item = visible[visibleIndex];
      final chordKey = chordLayout.chordKeyByVisibleIndex[visibleIndex];
      final chordIndexes = chordKey != null
          ? chordVisibleIndexesByKey[chordKey]
          : null;
      final chordHasStaccato = chordIndexes == null
          ? item.note.isStaccato
          : chordIndexes.any((idx) => visible[idx].note.isStaccato);

      if (!chordHasStaccato) {
        continue;
      }

      final referenceVisibleIndex = chordIndexes == null
          ? visibleIndex
          : (item.stemDirection == _StemDirection.up
                ? chordIndexes.reduce(
                    (a, b) =>
                        visible[a].noteStep <= visible[b].noteStep ? a : b,
                  )
                : chordIndexes.reduce(
                    (a, b) =>
                        visible[a].noteStep >= visible[b].noteStep ? a : b,
                  ));

      if (anchors.containsKey(referenceVisibleIndex)) {
        continue;
      }

      final referenceItem = visible[referenceVisibleIndex];
      final referenceCenter = Offset(
        referenceItem.x + (headDxByVisibleIndex[referenceVisibleIndex] ?? 0.0),
        referenceItem.y,
      );
      anchors[referenceVisibleIndex] = referenceCenter;
    }

    return anchors;
  }

  Map<int, double> _layoutBeamEdgeYByVisibleIndex(
    List<_RenderNote> visible,
    List<_ProjectedBeamGroup> beamGroups, {
    required double spacing,
  }) {
    final beamEdgeYByVisibleIndex = <int, double>{};

    for (final group in beamGroups) {
      final x1 = group.lockedReferenceStemTip.dx;
      final y1 = group.lockedReferenceStemTip.dy;

      double beamYAt(double x) => y1 + group.lockedSlope * (x - x1);

      for (final visibleIndex in group.indexes) {
        final item = visible[visibleIndex];
        final stemCenterX = item.x + item.headDx;
        final stemX = item.stemXAxisDirection == _StemDirection.up
            ? stemCenterX + spacing * 0.55
            : stemCenterX - spacing * 0.55;
        beamEdgeYByVisibleIndex[visibleIndex] = beamYAt(stemX);
      }
    }

    return beamEdgeYByVisibleIndex;
  }

  Map<int, Offset> _layoutFingeringAnchors(
    List<_RenderNote> visible, {
    required _ChordLayout chordLayout,
    required Map<String, List<int>> chordVisibleIndexesByKey,
    required Map<int, double> headDxByVisibleIndex,
    required Map<int, Offset> staccatoAnchorByVisibleIndex,
    required Map<int, double> beamEdgeYByVisibleIndex,
    required double trebleTop,
    required double bassTop,
    required double spacing,
  }) {
    final anchors = <int, Offset>{};

    final fingeringVisibleIndexes = <int>[
      for (var i = 0; i < visible.length; i++)
        if ((visible[i].note.fingering ?? '').isNotEmpty) i,
    ];

    final groups = <String, List<int>>{};
    for (final visibleIndex in fingeringVisibleIndexes) {
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
      if (chordIndexes.isEmpty) {
        continue;
      }

      final sortedByPitch = List<int>.from(chordIndexes)
        ..sort((a, b) => visible[a].noteStep.compareTo(visible[b].noteStep));

      final isUpperStaff = visible[chordIndexes.first].isUpperStaff;
      final staffTop = isUpperStaff ? trebleTop : bassTop;
      final staffBottom = staffTop + spacing * 4;

      final chordCenterX =
          chordIndexes
              .map((idx) => visible[idx].x + (headDxByVisibleIndex[idx] ?? 0.0))
              .reduce((a, b) => a + b) /
          chordIndexes.length;

      final staccatoAnchors = <Offset>[
        for (final idx in chordIndexes)
          if (staccatoAnchorByVisibleIndex[idx] != null)
            staccatoAnchorByVisibleIndex[idx]!,
      ];
      final staccatoClearance = spacing * 1.65;
      final beamClearance = spacing * 1.1;

      final beamYsForChord = <double>[
        for (final idx in chordIndexes)
          if (beamEdgeYByVisibleIndex[idx] != null)
            beamEdgeYByVisibleIndex[idx]!,
      ];

      if (isUpperStaff) {
        final staccatoTopY = staccatoAnchors.isEmpty
            ? null
            : staccatoAnchors
                  .map((anchor) => anchor.dy)
                  .reduce((a, b) => a < b ? a : b);
        final beamTopY = beamYsForChord.isEmpty
            ? null
            : beamYsForChord.reduce((a, b) => a < b ? a : b);

        for (var order = 0; order < sortedByPitch.length; order++) {
          final idx = sortedByPitch[sortedByPitch.length - 1 - order];
          final note = visible[idx];
          final isAboveStaff = note.y < staffTop;
          var anchorY = isAboveStaff
              ? note.y - spacing * 1.1 - order * spacing * 0.78
              : staffTop - spacing * 1.1 - order * spacing * 0.78;

          if (staccatoTopY != null) {
            final maxY =
                staccatoTopY - staccatoClearance - order * spacing * 0.78;
            if (anchorY > maxY) {
              anchorY = maxY;
            }
          }

          if (beamTopY != null) {
            final maxY = beamTopY - beamClearance - order * spacing * 0.78;
            if (anchorY > maxY) {
              anchorY = maxY;
            }
          }

          anchors[idx] = Offset(chordCenterX, anchorY);
        }
      } else {
        final staccatoBottomY = staccatoAnchors.isEmpty
            ? null
            : staccatoAnchors
                  .map((anchor) => anchor.dy)
                  .reduce((a, b) => a > b ? a : b);
        final beamBottomY = beamYsForChord.isEmpty
            ? null
            : beamYsForChord.reduce((a, b) => a > b ? a : b);

        for (var order = 0; order < sortedByPitch.length; order++) {
          final idx = sortedByPitch[order];
          final note = visible[idx];
          final isBelowStaff = note.y > staffBottom;
          var anchorY = isBelowStaff
              ? note.y + spacing * 1.1 + order * spacing * 0.78
              : staffBottom + spacing * 1.1 + order * spacing * 0.78;

          if (staccatoBottomY != null) {
            final minY =
                staccatoBottomY + staccatoClearance + order * spacing * 0.78;
            if (anchorY < minY) {
              anchorY = minY;
            }
          }

          if (beamBottomY != null) {
            final minY = beamBottomY + beamClearance + order * spacing * 0.78;
            if (anchorY < minY) {
              anchorY = minY;
            }
          }

          anchors[idx] = Offset(chordCenterX, anchorY);
        }
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
    required double playheadX,
    required NotationMetrics metrics,
  }) {
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final topLine = bottomLine + 8;
    final ledgerPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    final halfLength = (spacing * 1.12).clamp(9.4, 16.4);
    final leftHalfLength = durationType == _DurationType.whole
        ? halfLength * 1.49
        : halfLength;

    if (noteStep > topLine) {
      for (
        var ledgerStep = topLine + 2;
        ledgerStep <= noteStep;
        ledgerStep += 2
      ) {
        final y = _yForStaffStep(ledgerStep, isTreble, staffTop, spacing);
        final fadedPaint = Paint()
          ..color = color
          ..strokeWidth = ledgerPaint.strokeWidth;
        _notePainterApplyLeftFadeToPaint(
          fadedPaint,
          baseColor: color,
          bounds: Rect.fromLTRB(
            centerX - leftHalfLength,
            y - 1.0,
            centerX + halfLength,
            y + 1.0,
          ),
          playheadX: playheadX,
          metrics: metrics,
        );
        canvas.drawLine(
          Offset(centerX - leftHalfLength, y),
          Offset(centerX + halfLength, y),
          fadedPaint,
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
        final fadedPaint = Paint()
          ..color = color
          ..strokeWidth = ledgerPaint.strokeWidth;
        _notePainterApplyLeftFadeToPaint(
          fadedPaint,
          baseColor: color,
          bounds: Rect.fromLTRB(
            centerX - leftHalfLength,
            y - 1.0,
            centerX + halfLength,
            y + 1.0,
          ),
          playheadX: playheadX,
          metrics: metrics,
        );
        canvas.drawLine(
          Offset(centerX - leftHalfLength, y),
          Offset(centerX + halfLength, y),
          fadedPaint,
        );
      }
    }
  }

  void _drawNoteGlyph(
    Canvas canvas, {
    required Offset center,
    required _DurationType durationType,
    required NotationMetrics metrics,
    required Color color,
  }) {
    final strokeColor = color;
    final fillPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = metrics.noteHeadStrokeWidth
      ..isAntiAlias = true;

    if (durationType == _DurationType.whole) {
      _drawTemplatePathAligned(
        canvas,
        _wholeHeadTemplateCached,
        referenceBounds: _wholeHeadBoundsCached,
        center: center,
        targetHeight: metrics.wholeNoteHeadHeight,
        paint: fillPaint,
      );
      _drawTemplatePathAligned(
        canvas,
        _wholeHeadTemplateCached,
        referenceBounds: _wholeHeadBoundsCached,
        center: center,
        targetHeight: metrics.wholeNoteHeadHeight,
        paint: borderPaint,
      );
      return;
    }

    if (durationType == _DurationType.half) {
      _drawTemplatePathAligned(
        canvas,
        _halfHeadTemplateCached,
        referenceBounds: _halfHeadBoundsCached,
        center: center,
        targetHeight: metrics.noteHeadHeight,
        paint: fillPaint,
      );

      _drawTemplatePathAligned(
        canvas,
        _halfHeadTemplateCached,
        referenceBounds: _halfHeadBoundsCached,
        center: center,
        targetHeight: metrics.noteHeadHeight,
        paint: borderPaint,
      );
      return;
    }

    _drawTemplatePathAligned(
      canvas,
      _quarterHeadTemplateCached,
      referenceBounds: _quarterHeadBoundsCached,
      center: center,
      targetHeight: metrics.noteHeadHeight,
      paint: fillPaint,
    );

    _drawTemplatePathAligned(
      canvas,
      _quarterHeadTemplateCached,
      referenceBounds: _quarterHeadBoundsCached,
      center: center,
      targetHeight: metrics.noteHeadHeight,
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

      final template = _flagTemplateByDirection[direction]!;
      final bounds = _flagBoundsByDirection[direction]!;
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

    final glyphSize = _sharedTextPainter.measureText(
      smuflGlyph,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );

    _sharedTextPainter.paintText(
      canvas,
      Offset(
        center.dx - glyphSize.width / 2,
        center.dy - glyphSize.height * 0.53 + baselineNudge,
      ),
      smuflGlyph,
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      maxWidth: glyphSize.width + 2,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
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
    required Color color,
    Offset? anchor,
  }) {
    if (dotCount <= 0) {
      return;
    }

    final dotRadius = (spacing * 0.2).clamp(1.5, 3.5);
    final dotPaint = Paint()
      ..color = color
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

  void _drawFingering(
    Canvas canvas, {
    required String text,
    required Offset center,
    required double spacing,
    required Color color,
  }) {
    final fontSize = (spacing * 0.95).clamp(9.0, 16.0);
    final textSize = _sharedTextPainter.measureText(
      text,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );

    _sharedTextPainter.paintText(
      canvas,
      Offset(center.dx - textSize.width / 2, center.dy - textSize.height / 2),
      text,
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      maxWidth: textSize.width + 2,
      height: 1.0,
    );
  }

  void _drawStaccatoMark(
    Canvas canvas, {
    required Offset center,
    required _StemDirection direction,
    required double spacing,
    required Color color,
    required int referenceNoteStep,
    required bool isTreble,
  }) {
    final radius = (spacing * 0.16).clamp(1.2, 2.8).toDouble();

    var yOffset = direction == _StemDirection.up ? spacing : -spacing;

    // Xác định phạm vi staff (5 dòng)
    final bottomLine = isTreble ? _trebleBottomLineStep : _bassBottomLineStep;
    final topLine = bottomLine + 7;

    final isOutsideStaff =
        referenceNoteStep < bottomLine || referenceNoteStep > topLine;

    // Chỉ áp dụng shift khi nằm TRONG staff
    if (!isOutsideStaff) {
      final needsHalfStepShift = referenceNoteStep.isEven;

      if (needsHalfStepShift) {
        yOffset += direction == _StemDirection.up ? spacing / 2 : -spacing / 2;
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(center.dx, center.dy + yOffset), radius, paint);
  }

  Offset _defaultDotAnchor({
    required Offset center,
    required int noteStep,
    required bool isTreble,
    required _DurationType durationType,
    required double spacing,
  }) {
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
    required GameColorScheme colors,
    required Map<int, Color> stemColorByVisibleIndex,
    required Map<int, Offset> beamStemStartByVisibleIndex,
    required double playheadX,
    required NotationMetrics metrics,
  }) {
    _notePainterDrawBeamGroup(
      canvas,
      visible,
      indexes,
      lineSpacing: lineSpacing,
      lockedSlope: lockedSlope,
      lockedReferenceStemTip: lockedReferenceStemTip,
      colors: colors,
      stemColorByVisibleIndex: stemColorByVisibleIndex,
      beamStemStartByVisibleIndex: beamStemStartByVisibleIndex,
      playheadX: playheadX,
      metrics: metrics,
    );
  }

  Color _noteInkColor(
    _NoteJudge judge,
    bool isActive, {
    required GameColorScheme colors,
  }) {
    return switch (judge) {
      _NoteJudge.pass => colors.note.pass,
      _NoteJudge.miss => colors.note.miss,
      _NoteJudge.pending => isActive ? colors.note.active : colors.note.idle,
    };
  }
}

double _notePainterLeftFadeDistance(
  NotationMetrics metrics, {
  double multiplier = 1.0,
}) => ((metrics.staffSpace * 6.0) * multiplier).clamp(28.0, 160.0).toDouble();

double _notePainterLeftFadeOpacityAtX(
  double x,
  double playheadX,
  NotationMetrics metrics, {
  double fadeDistanceMultiplier = 1.0,
}) {
  if (x >= playheadX) {
    return 1.0;
  }
  final fadeDistance = _notePainterLeftFadeDistance(
    metrics,
    multiplier: fadeDistanceMultiplier,
  );
  final progress = ((playheadX - x) / fadeDistance).clamp(0.0, 1.0).toDouble();
  return 1.0 - progress;
}

Color _notePainterApplyOpacity(Color base, double opacity) {
  final alpha = (base.alpha * opacity.clamp(0.0, 1.0)).round();
  return base.withAlpha(alpha);
}

void _notePainterApplyLeftFadeToPaint(
  Paint paint, {
  required Color baseColor,
  required Rect bounds,
  required double playheadX,
  required NotationMetrics metrics,
  double fadeDistanceMultiplier = 1.0,
}) {
  if (bounds.isEmpty) {
    return;
  }
  if (bounds.left >= playheadX) {
    paint.shader = null;
    paint.color = baseColor;
    return;
  }

  if (bounds.right <= playheadX || (bounds.right - bounds.left).abs() < 0.001) {
    paint.shader = null;
    paint.color = _notePainterApplyOpacity(
      baseColor,
      _notePainterLeftFadeOpacityAtX(
        bounds.left,
        playheadX,
        metrics,
        fadeDistanceMultiplier: fadeDistanceMultiplier,
      ),
    );
    return;
  }

  final fadeDistance = _notePainterLeftFadeDistance(
    metrics,
    multiplier: fadeDistanceMultiplier,
  );
  final width = bounds.width;
  final fadeStartX = playheadX - fadeDistance;
  final fadeStartStop = ((fadeStartX - bounds.left) / width)
      .clamp(0.0, 1.0)
      .toDouble();
  final playheadStop = ((playheadX - bounds.left) / width)
      .clamp(0.0, 1.0)
      .toDouble();
  final leftOpacity = _notePainterLeftFadeOpacityAtX(
    bounds.left,
    playheadX,
    metrics,
    fadeDistanceMultiplier: fadeDistanceMultiplier,
  );

  paint.shader = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      _notePainterApplyOpacity(baseColor, leftOpacity),
      _notePainterApplyOpacity(baseColor, 0.0),
      baseColor,
      baseColor,
    ],
    stops: <double>[0.0, fadeStartStop, playheadStop, 1.0],
  ).createShader(bounds);
}
