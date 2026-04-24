part of 'game_note_painter.dart';

extension on GameNotePainter {
  void _drawSlurs(
    Canvas canvas, {
    required ScoreData score,
    required _PrecomputedScoreRenderData precomputedScore,
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
    required List<_RenderNote> visible,
    required Map<int, int> visibleIndexByScoreIndex,
    required _ChordLayout chordLayout,
    required Map<String, List<int>> chordVisibleIndexesByKey,
    required Map<int, Offset> accidentalCenterByVisibleIndex,
    required Map<int, Offset> dotAnchorByVisibleIndex,
    required Map<int, Offset> staccatoAnchorByVisibleIndex,
    required Map<int, Offset> fingeringAnchorByVisibleIndex,
    required Map<int, double> beamEdgeYByVisibleIndex,
    required Size size,
    required int currentMs,
    required double playheadX,
    required double trebleTop,
    required double bassTop,
    required NotationMetrics metrics,
    required double notePxPerMs,
  }) {
    if (score.slurs.isEmpty || visible.isEmpty) {
      return;
    }

    final spacing = metrics.staffSpace;
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final leftInvisibleMeasurePx = measureMs * notePxPerMs;
    final slurLaneCache =
        GameNotePainter._slurLaneCacheByScore[score] ?? <String, int>{};
    GameNotePainter._slurLaneCacheByScore[score] = slurLaneCache;
    final slurBodyCollisionBoostCache =
        GameNotePainter._slurBodyCollisionBoostCacheByScore[score] ??
        <String, double>{};
    GameNotePainter._slurBodyCollisionBoostCacheByScore[score] =
        slurBodyCollisionBoostCache;
    final pendingLayouts =
        <
          ({
            String segmentKey,
            int startScoreIndex,
            int endScoreIndex,
            int? startVisibleIndex,
            int? endVisibleIndex,
            SlurEvent startEvent,
            SlurEvent endEvent,
            Offset startAnchor,
            Offset endAnchor,
            bool isAbove,
            bool isUpperStaff,
            bool isCrossSystemContinuation,
            double minX,
            double maxX,
          })
        >[];
    final seenChordToChordSlurKeys = <String>{};

    for (final span in score.slurs) {
      for (final segment in span.segments) {
        final startEvent = span.events[segment.startEventIndex];
        final endEvent = span.events[segment.endEventIndex];
        final startVisibleIndex =
            visibleIndexByScoreIndex[segment.startNoteIndex];
        final endVisibleIndex = visibleIndexByScoreIndex[segment.endNoteIndex];
        final projectedStart = _projectSlurRenderNote(
          score: score,
          precomputedScore: precomputedScore,
          scoreIndex: segment.startNoteIndex,
          currentMs: currentMs,
          playheadX: playheadX,
          trebleTop: trebleTop,
          bassTop: bassTop,
          metrics: metrics,
          notePxPerMs: notePxPerMs,
        );
        final projectedEnd = _projectSlurRenderNote(
          score: score,
          precomputedScore: precomputedScore,
          scoreIndex: segment.endNoteIndex,
          currentMs: currentMs,
          playheadX: playheadX,
          trebleTop: trebleTop,
          bassTop: bassTop,
          metrics: metrics,
          notePxPerMs: notePxPerMs,
        );
        if (projectedEnd.x <
            -(leftInvisibleMeasurePx + metrics.staffSpace * 2.0)) {
          continue;
        }
        if (projectedStart.x > size.width + metrics.staffSpace * 2.0) {
          continue;
        }

        final startRenderNote = projectedStart;
        final endRenderNote = projectedEnd;

        final slurAbove = _resolveSlurIsAbove(
          startEvent,
          endEvent,
          startVisible: startRenderNote,
          endVisible: endRenderNote,
        );
        final startChordKey = startVisibleIndex == null
            ? null
            : chordLayout.chordKeyByVisibleIndex[startVisibleIndex];
        final endChordKey = endVisibleIndex == null
            ? null
            : chordLayout.chordKeyByVisibleIndex[endVisibleIndex];
        final isChordToChord = startChordKey != null && endChordKey != null;
        if (isChordToChord) {
          final dedupeKey =
              '$startChordKey->$endChordKey:${slurAbove ? 'above' : 'below'}';
          if (!seenChordToChordSlurKeys.add(dedupeKey)) {
            continue;
          }
        }
        final startAnchor = _resolveProjectedSlurAnchor(
          note: projectedStart,
          event: startEvent,
          isAbove: slurAbove,
          isStart: true,
          chordVisibleIndexes: startChordKey == null
              ? null
              : chordVisibleIndexesByKey[startChordKey],
          visible: visible,
          metrics: metrics,
        );
        final endAnchor = _resolveProjectedSlurAnchor(
          note: projectedEnd,
          event: endEvent,
          isAbove: slurAbove,
          isStart: false,
          chordVisibleIndexes: endChordKey == null
              ? null
              : chordVisibleIndexesByKey[endChordKey],
          visible: visible,
          metrics: metrics,
        );

        final minX = math.min(startAnchor.dx, endAnchor.dx);
        final maxX = math.max(startAnchor.dx, endAnchor.dx);
        if ((maxX - minX).abs() < spacing * 0.9) {
          continue;
        }

        pendingLayouts.add((
          segmentKey:
              '${span.partId}:${span.number}:${segment.startEventIndex}:${segment.endEventIndex}:${segment.startNoteIndex}:${segment.endNoteIndex}:${slurAbove ? 'above' : 'below'}',
          startScoreIndex: segment.startNoteIndex,
          endScoreIndex: segment.endNoteIndex,
          startVisibleIndex: startVisibleIndex,
          endVisibleIndex: endVisibleIndex,
          startEvent: startEvent,
          endEvent: endEvent,
          startAnchor: startAnchor,
          endAnchor: endAnchor,
          isAbove: slurAbove,
          isUpperStaff: startRenderNote.isUpperStaff,
          isCrossSystemContinuation: segment.isCrossSystemContinuation,
          minX: minX,
          maxX: maxX,
        ));
      }
    }

    pendingLayouts.sort((a, b) {
      final sideComparison = a.isAbove == b.isAbove ? 0 : (a.isAbove ? -1 : 1);
      if (sideComparison != 0) {
        return sideComparison;
      }
      final staffComparison = (a.isUpperStaff ? 0 : 1).compareTo(
        b.isUpperStaff ? 0 : 1,
      );
      if (staffComparison != 0) {
        return staffComparison;
      }
      final widthComparison = (a.maxX - a.minX).compareTo(b.maxX - b.minX);
      if (widthComparison != 0) {
        return widthComparison;
      }
      final xComparison = a.minX.compareTo(b.minX);
      if (xComparison != 0) {
        return xComparison;
      }
      return a.maxX.compareTo(b.maxX);
    });

    final occupiedIntervalsByLaneKey =
        <String, List<List<({double minX, double maxX})>>>{};
    for (final layout in pendingLayouts) {
      final laneKey =
          '${layout.isUpperStaff ? 'upper' : 'lower'}:${layout.isAbove ? 'above' : 'below'}';
      final occupiedLanes = occupiedIntervalsByLaneKey.putIfAbsent(
        laneKey,
        () => <List<({double minX, double maxX})>>[],
      );
      final paddedMinX = layout.minX - metrics.slurStackOverlapPadding;
      final paddedMaxX = layout.maxX + metrics.slurStackOverlapPadding;

      bool laneIsAvailable(int lane) {
        if (lane >= occupiedLanes.length) {
          return true;
        }
        return !occupiedLanes[lane].any(
          (interval) =>
              paddedMinX <= interval.maxX && paddedMaxX >= interval.minX,
        );
      }

      final laneCacheKey = '$laneKey:${layout.segmentKey}';
      final preferredLane = slurLaneCache[laneCacheKey];
      var lane = preferredLane ?? 0;
      if (!laneIsAvailable(lane)) {
        lane = 0;
        while (!laneIsAvailable(lane)) {
          lane++;
        }
      }
      slurLaneCache[laneCacheKey] = lane;

      if (lane == occupiedLanes.length) {
        occupiedLanes.add(<({double minX, double maxX})>[
          (minX: paddedMinX, maxX: paddedMaxX),
        ]);
      } else {
        occupiedLanes[lane].add((minX: paddedMinX, maxX: paddedMaxX));
      }

      final direction = layout.isAbove ? -1.0 : 1.0;
      final laneOffsetY = direction * lane * metrics.slurStackGap;
      final startAnchor = layout.startAnchor.translate(0.0, laneOffsetY);
      final endAnchor = layout.endAnchor.translate(0.0, laneOffsetY);
      final dx = endAnchor.dx - startAnchor.dx;
      if (dx.abs() < spacing * 0.9) {
        continue;
      }

      final spanWidth = dx.abs();
      final baseArcLift = (spanWidth * metrics.slurArcHeightRatio).toDouble();
      final shortSpanProgress =
          (1.0 - (spanWidth / metrics.slurShortSpanBoostThreshold))
              .clamp(0.0, 1.0)
              .toDouble();
      final shortSpanBoost =
          metrics.slurShortSpanBoostMax *
          math.pow(shortSpanProgress, 1.35).toDouble();
      final slopeProgress =
          (((endAnchor.dy - startAnchor.dy).abs() / metrics.staffSpace)
              .clamp(0.0, 1.7)
              .toDouble()) /
          1.7;
      final slopeBoost =
          metrics.slurSlopeBoostMax * math.pow(slopeProgress, 1.0).toDouble();
      final spanLimitedArcMax = math.max(
        metrics.slurArcHeightMin,
        spanWidth * metrics.slurArcHeightSpanRatioCap,
      );
      final arcLift =
          (math.max(baseArcLift, metrics.slurArcHeightMin) +
                  shortSpanBoost +
                  slopeBoost)
              .clamp(
                metrics.slurArcHeightMin,
                math.min(metrics.slurArcHeightMax, spanLimitedArcMax),
              )
              .toDouble();
      final segmentHang = layout.isCrossSystemContinuation
          ? arcLift * metrics.slurPartialHangRatio
          : 0.0;
      final anchorMidY = (startAnchor.dy + endAnchor.dy) * 0.5;
      final anchorMidX = (startAnchor.dx + endAnchor.dx) * 0.5;
      final quadraticControl = Offset(
        anchorMidX,
        anchorMidY + direction * arcLift + direction * segmentHang,
      );

      var control1 = Offset(
        startAnchor.dx + (2.0 / 3.0) * (quadraticControl.dx - startAnchor.dx),
        startAnchor.dy + (2.0 / 3.0) * (quadraticControl.dy - startAnchor.dy),
      );
      var control2 = Offset(
        endAnchor.dx + (2.0 / 3.0) * (quadraticControl.dx - endAnchor.dx),
        endAnchor.dy + (2.0 / 3.0) * (quadraticControl.dy - endAnchor.dy),
      );

      control1 = _overrideSlurControlPoint(
        fallback: control1,
        anchor: startAnchor,
        event: layout.startEvent,
        isOutgoing: true,
      );
      control2 = _overrideSlurControlPoint(
        fallback: control2,
        anchor: endAnchor,
        event: layout.endEvent,
        isOutgoing: false,
      );

      final bodyCollisionBoostCacheKey = layout.segmentKey;
      final bodyCollisionBoost =
          slurBodyCollisionBoostCache[bodyCollisionBoostCacheKey] ??
          _resolveSlurBodyCollisionArcLiftBoost(
            visible: visible,
            chordLayout: chordLayout,
            startVisibleIndex: layout.startVisibleIndex,
            endVisibleIndex: layout.endVisibleIndex,
            startAnchor: startAnchor,
            control1: control1,
            control2: control2,
            endAnchor: endAnchor,
            isAbove: layout.isAbove,
            metrics: metrics,
          );
      slurBodyCollisionBoostCache[bodyCollisionBoostCacheKey] =
          bodyCollisionBoost;
      if (bodyCollisionBoost > 0) {
        final adjustedQuadraticControl = Offset(
          anchorMidX,
          anchorMidY + direction * (arcLift + segmentHang + bodyCollisionBoost),
        );
        control1 = Offset(
          startAnchor.dx +
              (2.0 / 3.0) * (adjustedQuadraticControl.dx - startAnchor.dx),
          startAnchor.dy +
              (2.0 / 3.0) * (adjustedQuadraticControl.dy - startAnchor.dy),
        );
        control2 = Offset(
          endAnchor.dx +
              (2.0 / 3.0) * (adjustedQuadraticControl.dx - endAnchor.dx),
          endAnchor.dy +
              (2.0 / 3.0) * (adjustedQuadraticControl.dy - endAnchor.dy),
        );

        control1 = _overrideSlurControlPoint(
          fallback: control1,
          anchor: startAnchor,
          event: layout.startEvent,
          isOutgoing: true,
        );
        control2 = _overrideSlurControlPoint(
          fallback: control2,
          anchor: endAnchor,
          event: layout.endEvent,
          isOutgoing: false,
        );
      }

      final slurPath = _buildSlurPath(
        startAnchor: startAnchor,
        control1: control1,
        control2: control2,
        endAnchor: endAnchor,
        endThickness: metrics.slurEndThickness,
        middleThickness: metrics.slurMiddleThickness,
        outerThicknessRatio: metrics.slurOuterThicknessRatio,
        innerThicknessRatio: metrics.slurInnerThicknessRatio,
        isAbove: layout.isAbove,
      );
      final judgedSlurColor = _slurColorForSegment(
        _slurJudgeForScoreIndex(
          layout.startScoreIndex,
          passedNoteIndexes: passedNoteIndexes,
          missedNoteIndexes: missedNoteIndexes,
        ),
        _slurJudgeForScoreIndex(
          layout.endScoreIndex,
          passedNoteIndexes: passedNoteIndexes,
          missedNoteIndexes: missedNoteIndexes,
        ),
        colors: score.colors,
      );
      final baseSlurPaint = Paint()
        ..color = score.colors.accidentalAndSlur.slurIdle
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      _notePainterApplyLeftFadeToPaint(
        baseSlurPaint,
        baseColor: score.colors.accidentalAndSlur.slurIdle,
        bounds: slurPath.getBounds(),
        playheadX: playheadX,
        metrics: metrics,
      );
      canvas.drawPath(slurPath, baseSlurPaint);

      if (judgedSlurColor != score.colors.accidentalAndSlur.slurIdle) {
        final judgedPaint = Paint()
          ..color = judgedSlurColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        _notePainterApplyLeftFadeToPaint(
          judgedPaint,
          baseColor: judgedSlurColor,
          bounds: slurPath.getBounds(),
          playheadX: playheadX,
          metrics: metrics,
        );
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(-100000, -100000, playheadX, 100000));
        canvas.drawPath(slurPath, judgedPaint);
        canvas.restore();
      }
    }
  }

  _RenderNote _projectSlurRenderNote({
    required ScoreData score,
    required _PrecomputedScoreRenderData precomputedScore,
    required int scoreIndex,
    required int currentMs,
    required double playheadX,
    required double trebleTop,
    required double bassTop,
    required NotationMetrics metrics,
    required double notePxPerMs,
  }) {
    final note = score.notes[scoreIndex];
    final precomputed = precomputedScore.notes[scoreIndex];
    final x = playheadX + (precomputed.adjustedHitMs - currentMs) * notePxPerMs;
    final staffTop = precomputed.isUpperStaff ? trebleTop : bassTop;
    final y = _yForStaffStep(
      note.staffStep,
      precomputed.isTreble,
      staffTop,
      metrics.staffSpace,
    );
    return _RenderNote(
      index: scoreIndex,
      x: x,
      y: y,
      isUpperStaff: precomputed.isUpperStaff,
      isTreble: precomputed.isTreble,
      noteStep: note.staffStep,
      note: note,
      adjustedHitMs: precomputed.adjustedHitMs,
      status: _NoteJudge.pending,
      durationType: precomputed.durationType,
      accidentalToRender: precomputed.accidentalToRender,
      stemDirection: precomputed.stemDirection,
      stemXAxisDirection: precomputed.stemDirection,
    );
  }

  Offset _resolveProjectedSlurAnchor({
    required _RenderNote note,
    required SlurEvent event,
    required bool isAbove,
    required bool isStart,
    required List<int>? chordVisibleIndexes,
    required List<_RenderNote> visible,
    required NotationMetrics metrics,
  }) {
    final center = Offset(note.x + note.headDx, note.y);
    var chordTopY = center.dy;
    var chordBottomY = center.dy;
    final isChordAnchor =
        chordVisibleIndexes != null && chordVisibleIndexes.length > 1;
    if (isChordAnchor) {
      for (final visibleIndex in chordVisibleIndexes) {
        final chordNoteY = visible[visibleIndex].y;
        if (chordNoteY < chordTopY) {
          chordTopY = chordNoteY;
        }
        if (chordNoteY > chordBottomY) {
          chordBottomY = chordNoteY;
        }
      }
    }
    final baseResolution = _resolveBaseSlurAnchorResolution(
      note: note,
      center: center,
      isAbove: isAbove,
      isStart: isStart,
      isChordAnchor: isChordAnchor,
      chordTopY: chordTopY,
      chordBottomY: chordBottomY,
      hasNearbyAccidental: note.accidentalToRender != null,
      hasNearbyDot: note.note.dotCount > 0,
      hasNearbyStaccato: note.note.isStaccato,
      hasNearbyFingering:
          note.note.fingering != null && note.note.fingering!.isNotEmpty,
      metrics: metrics,
    );
    return baseResolution.anchor + _musicXmlVisualOffset(event);
  }

  bool _resolveSlurIsAbove(
    SlurEvent startEvent,
    SlurEvent endEvent, {
    required _RenderNote startVisible,
    required _RenderNote endVisible,
  }) {
    final placement = startEvent.placement ?? endEvent.placement;
    if (placement == 'above') {
      return true;
    }
    if (placement == 'below') {
      return false;
    }

    final orientation = startEvent.orientation ?? endEvent.orientation;
    if (orientation == 'over') {
      return true;
    }
    if (orientation == 'under') {
      return false;
    }

    if (startEvent.voice != endEvent.voice) {
      return startEvent.voice <= endEvent.voice;
    }

    final sameStemDirection =
        startVisible.stemDirection == endVisible.stemDirection;
    if (sameStemDirection) {
      return startVisible.stemDirection == _StemDirection.down;
    }
    return startEvent.voice <= 1;
  }

  _SlurAnchorResolution _resolveBaseSlurAnchorResolution({
    required _RenderNote note,
    required Offset center,
    required bool isAbove,
    required bool isStart,
    required bool isChordAnchor,
    required double chordTopY,
    required double chordBottomY,
    required bool hasNearbyAccidental,
    required bool hasNearbyDot,
    required bool hasNearbyStaccato,
    required bool hasNearbyFingering,
    required NotationMetrics metrics,
  }) {
    final horizontalSign = isStart ? 1.0 : -1.0;
    final isStemSide = isAbove == (note.stemDirection == _StemDirection.up);
    final hasStemSideGeometry =
        note.durationType != _DurationType.whole && note.stemTip != null;
    final preferOutsideHead =
        isChordAnchor ||
        note.durationType == _DurationType.whole ||
        hasNearbyAccidental ||
        hasNearbyDot ||
        hasNearbyStaccato ||
        hasNearbyFingering;
    final mode = isStemSide
        ? _SlurAnchorMode.stemSide
        : (preferOutsideHead || hasStemSideGeometry)
        ? _SlurAnchorMode.outsideHead
        : _SlurAnchorMode.center;
    final horizontalInset = switch (mode) {
      _SlurAnchorMode.stemSide =>
        isStart
            ? metrics.slurStartAnchorHorizontalInset
            : metrics.slurEndAnchorHorizontalInset,
      _SlurAnchorMode.outsideHead =>
        metrics.slurOutsideHeadHorizontalInset +
            (isChordAnchor ? metrics.slurChordHorizontalInsetExtra : 0.0),
      _SlurAnchorMode.center => 0.0,
    };
    final anchorBaseY = isChordAnchor
        ? (isAbove ? chordTopY : chordBottomY)
        : center.dy;

    final anchor = Offset(
      mode == _SlurAnchorMode.center
          ? center.dx
          : center.dx + horizontalSign * horizontalInset,
      anchorBaseY +
          (isAbove
              ? -(metrics.slurAnchorVerticalInset +
                    (isChordAnchor ? metrics.slurChordVerticalInsetExtra : 0.0))
              : metrics.slurAnchorVerticalInset +
                    (isChordAnchor
                        ? metrics.slurChordVerticalInsetExtra
                        : 0.0)),
    );
    return _SlurAnchorResolution(anchor: anchor, mode: mode);
  }

  double _resolveSlurBodyCollisionArcLiftBoost({
    required List<_RenderNote> visible,
    required _ChordLayout chordLayout,
    required int? startVisibleIndex,
    required int? endVisibleIndex,
    required Offset startAnchor,
    required Offset control1,
    required Offset control2,
    required Offset endAnchor,
    required bool isAbove,
    required NotationMetrics metrics,
  }) {
    final noteHeadHeight = metrics.noteHeadHeight;
    final noteHeadHalfWidth = noteHeadHeight * 0.68;
    final clearance = metrics.slurBodyNoteClearance;
    final minX = math.min(startAnchor.dx, endAnchor.dx);
    final maxX = math.max(startAnchor.dx, endAnchor.dx);
    final startChordKey = startVisibleIndex == null
        ? null
        : chordLayout.chordKeyByVisibleIndex[startVisibleIndex];
    final endChordKey = endVisibleIndex == null
        ? null
        : chordLayout.chordKeyByVisibleIndex[endVisibleIndex];
    var requiredBoost = 0.0;

    for (var i = 0; i < visible.length; i++) {
      if (i == startVisibleIndex || i == endVisibleIndex) {
        continue;
      }
      final chordKey = chordLayout.chordKeyByVisibleIndex[i];
      if (chordKey != null &&
          (chordKey == startChordKey || chordKey == endChordKey)) {
        continue;
      }

      final noteCenter = Offset(visible[i].x + visible[i].headDx, visible[i].y);
      final noteMinX = noteCenter.dx - noteHeadHalfWidth;
      final noteMaxX = noteCenter.dx + noteHeadHalfWidth;
      if (noteMaxX < minX || noteMinX > maxX) {
        continue;
      }

      final noteTop = noteCenter.dy - noteHeadHeight * 0.56;
      final noteBottom = noteCenter.dy + noteHeadHeight * 0.56;
      const samples = 28;
      for (var step = 0; step <= samples; step++) {
        final progress = step / samples;
        final t = 0.2 + progress * 0.6;
        final point = _cubicPointAt(
          t,
          p0: startAnchor,
          p1: control1,
          p2: control2,
          p3: endAnchor,
        );
        if (point.dx < noteMinX || point.dx > noteMaxX) {
          continue;
        }
        if (isAbove) {
          final overlap = point.dy - (noteTop - clearance);
          if (overlap > requiredBoost) {
            requiredBoost = overlap;
          }
        } else {
          final overlap = (noteBottom + clearance) - point.dy;
          if (overlap > requiredBoost) {
            requiredBoost = overlap;
          }
        }
      }
    }

    if (requiredBoost <= 0) {
      return 0.0;
    }

    return (requiredBoost * metrics.slurBodyNoteArcLiftWeight)
        .clamp(0.0, metrics.slurBodyNoteArcLiftMax)
        .toDouble();
  }

  Offset _overrideSlurControlPoint({
    required Offset fallback,
    required Offset anchor,
    required SlurEvent event,
    required bool isOutgoing,
  }) {
    final useX = isOutgoing ? event.bezierX2 ?? event.bezierX : event.bezierX;
    final useY = isOutgoing ? event.bezierY2 ?? event.bezierY : event.bezierY;
    if (useX == null && useY == null) {
      return fallback;
    }
    return anchor + _musicXmlOffset(useX ?? 0.0, useY ?? 0.0);
  }

  Offset _musicXmlVisualOffset(SlurEvent event) {
    final dx = (event.defaultX ?? 0.0) + (event.relativeX ?? 0.0);
    final dy = (event.defaultY ?? 0.0) + (event.relativeY ?? 0.0);
    return _musicXmlOffset(dx, dy);
  }

  Offset _musicXmlOffset(double dx, double dy) => Offset(dx, -dy);

  Path _buildSlurPath({
    required Offset startAnchor,
    required Offset control1,
    required Offset control2,
    required Offset endAnchor,
    required double endThickness,
    required double middleThickness,
    required double outerThicknessRatio,
    required double innerThicknessRatio,
    required bool isAbove,
  }) {
    final fallbackDirection = Offset(
      endAnchor.dx >= startAnchor.dx ? 1.0 : -1.0,
      0.0,
    );
    final startTangent = _normalizeOffset(
      control1 - startAnchor,
      fallback: fallbackDirection,
    );
    final endTangent = _normalizeOffset(
      endAnchor - control2,
      fallback: fallbackDirection,
    );
    final midTangent = _normalizeOffset(
      _cubicTangentAt(
        0.5,
        p0: startAnchor,
        p1: control1,
        p2: control2,
        p3: endAnchor,
      ),
      fallback: fallbackDirection,
    );

    final startNormal = isAbove
        ? Offset(startTangent.dy, -startTangent.dx)
        : Offset(-startTangent.dy, startTangent.dx);
    final endNormal = isAbove
        ? Offset(endTangent.dy, -endTangent.dx)
        : Offset(-endTangent.dy, endTangent.dx);
    final midNormal = isAbove
        ? Offset(midTangent.dy, -midTangent.dx)
        : Offset(-midTangent.dy, midTangent.dx);

    final outerStart =
        startAnchor + startNormal * (endThickness * outerThicknessRatio);
    final outerEnd =
        endAnchor + endNormal * (endThickness * outerThicknessRatio);
    final innerStart =
        startAnchor - startNormal * (endThickness * innerThicknessRatio);
    final innerEnd =
        endAnchor - endNormal * (endThickness * innerThicknessRatio);

    final outerControl1 =
        control1 + (startNormal * 0.62 + midNormal * 0.38) * middleThickness;
    final outerControl2 =
        control2 + (endNormal * 0.62 + midNormal * 0.38) * middleThickness;
    final innerControl2 =
        control2 - (endNormal * 0.62 + midNormal * 0.38) * middleThickness;
    final innerControl1 =
        control1 - (startNormal * 0.62 + midNormal * 0.38) * middleThickness;

    return Path()
      ..moveTo(outerStart.dx, outerStart.dy)
      ..cubicTo(
        outerControl1.dx,
        outerControl1.dy,
        outerControl2.dx,
        outerControl2.dy,
        outerEnd.dx,
        outerEnd.dy,
      )
      ..lineTo(innerEnd.dx, innerEnd.dy)
      ..cubicTo(
        innerControl2.dx,
        innerControl2.dy,
        innerControl1.dx,
        innerControl1.dy,
        innerStart.dx,
        innerStart.dy,
      )
      ..close();
  }

  Offset _cubicPointAt(
    double t, {
    required Offset p0,
    required Offset p1,
    required Offset p2,
    required Offset p3,
  }) {
    final mt = 1.0 - t;
    final mt2 = mt * mt;
    final t2 = t * t;
    return Offset(
      mt2 * mt * p0.dx +
          3 * mt2 * t * p1.dx +
          3 * mt * t2 * p2.dx +
          t2 * t * p3.dx,
      mt2 * mt * p0.dy +
          3 * mt2 * t * p1.dy +
          3 * mt * t2 * p2.dy +
          t2 * t * p3.dy,
    );
  }

  Offset _cubicTangentAt(
    double t, {
    required Offset p0,
    required Offset p1,
    required Offset p2,
    required Offset p3,
  }) {
    final mt = 1.0 - t;
    final a = (p1 - p0) * (3 * mt * mt);
    final b = (p2 - p1) * (6 * mt * t);
    final c = (p3 - p2) * (3 * t * t);
    return a + b + c;
  }

  Offset _normalizeOffset(Offset value, {required Offset fallback}) {
    final length = value.distance;
    if (length <= 0.0001) {
      return fallback;
    }
    return Offset(value.dx / length, value.dy / length);
  }

  Color _slurColorForSegment(
    _NoteJudge start,
    _NoteJudge end, {
    required GameColorScheme colors,
  }) {
    if (start == _NoteJudge.miss || end == _NoteJudge.miss) {
      return colors.accidentalAndSlur.slurMiss;
    }
    if (start == _NoteJudge.pass || end == _NoteJudge.pass) {
      return colors.accidentalAndSlur.slurPass;
    }
    return colors.accidentalAndSlur.slurIdle;
  }

  _NoteJudge _slurJudgeForScoreIndex(
    int scoreIndex, {
    required Set<int> passedNoteIndexes,
    required Set<int> missedNoteIndexes,
  }) {
    if (missedNoteIndexes.contains(scoreIndex)) {
      return _NoteJudge.miss;
    }
    if (passedNoteIndexes.contains(scoreIndex)) {
      return _NoteJudge.pass;
    }
    return _NoteJudge.pending;
  }
}
