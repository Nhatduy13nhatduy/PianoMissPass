import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/game_score.dart';
import '../notation/notation_metrics.dart';
import '../cubit/game_prototype_cubit.dart';
import '../cubit/game_prototype_state.dart';
import '../painters/game_keyboard_painter.dart';
import '../painters/game_note_painter.dart';
import '../painters/game_staff_painter.dart';
import '../painters/game_text_painter.dart';

class GamePrototypePage extends StatelessWidget {
  const GamePrototypePage({super.key, this.assetMxlPath, this.songTitle});

  final String? assetMxlPath;
  final String? songTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          GamePrototypeCubit(assetMxlPath: assetMxlPath, songTitle: songTitle)
            ..initialize(),
      child: const _GamePrototypeChromeScope(),
    );
  }
}

class _GamePrototypeChromeScope extends StatefulWidget {
  const _GamePrototypeChromeScope();

  @override
  State<_GamePrototypeChromeScope> createState() =>
      _GamePrototypeChromeScopeState();
}

class _GamePrototypeChromeScopeState extends State<_GamePrototypeChromeScope> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GamePrototypeCubit>();
    return Scaffold(
      body: BlocBuilder<GamePrototypeCubit, GamePrototypeState>(
        buildWhen: (previous, current) =>
            previous.isLoading != current.isLoading ||
            previous.errorMessage != current.errorMessage ||
            previous.score != current.score ||
            previous.passedNoteIndexes != current.passedNoteIndexes ||
            previous.missedNoteIndexes != current.missedNoteIndexes,
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null) {
            return _ErrorView(
              error: state.errorMessage!,
              onRetry: () => context.read<GamePrototypeCubit>().retry(),
            );
          }

          final score = state.score;
          if (score == null) {
            return const SizedBox.shrink();
          }

          return Stack(
            children: [
              CustomPaint(
                painter: _StaffScrollerPainter(
                  score: score,
                  elapsedMsListenable: cubit.elapsedMsListenable,
                  passedNoteIndexes: state.passedNoteIndexes,
                  missedNoteIndexes: state.missedNoteIndexes,
                ),
                child: const SizedBox.expand(),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _PlaybackButton(
                  isPlaying: state.isPlaying,
                  onPressed: cubit.togglePlayback,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: cubit.elapsedMsListenable,
                  builder: (context, elapsedMs, _) {
                    final safeMaxDuration = cubit.maxDurationMs <= 0
                        ? 1
                        : cubit.maxDurationMs;
                    final progress = (elapsedMs / safeMaxDuration)
                        .clamp(0.0, 1.0)
                        .toDouble();
                    return _TopProgressLine(
                      progress: progress,
                      color: score.colors.progress.line,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopProgressLine extends StatelessWidget {
  const _TopProgressLine({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(120),
                      blurRadius: 7,
                      spreadRadius: 0.4,
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC0E1620),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  isPlaying ? 'Pause' : 'Play',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          const Text('Khong tai duoc file MXL mau'),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thu lai')),
        ],
      ),
    );
  }
}

class _StaffScrollerPainter extends CustomPainter {
  static const bool _debugHideLowerStaff = false;
  static const String _bravuraFontFamily = 'Bravura';
  static const int _clefTransitionMs = 700;
  static final Expando<_PrecomputedScoreVisuals> _scoreVisualsCache =
      Expando<_PrecomputedScoreVisuals>('game-prototype-score-visuals');

  _StaffScrollerPainter({
    required this.score,
    required this.elapsedMsListenable,
    required this.passedNoteIndexes,
    required this.missedNoteIndexes,
  }) : super(repaint: elapsedMsListenable);

  final ScoreData score;
  final ValueListenable<int> elapsedMsListenable;
  final Set<int> passedNoteIndexes;
  final Set<int> missedNoteIndexes;

  final GameStaffPainter _staffPainter = GameStaffPainter();
  final GameTextPainter _textPainter = GameTextPainter();
  final GameNotePainter _notePainter = GameNotePainter();
  final GameKeyboardPainter _keyboardPainter = GameKeyboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = elapsedMsListenable.value;
    final visuals = _getPrecomputedScoreVisuals(score);
    final metrics = NotationMetrics.fromCanvasSize(size);
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final leftInvisibleMeasurePx = measureMs * GameNotePainter.notePxPerMs;
    final topPadding = metrics.topPadding;
    final staffHeight = metrics.staffHeight;
    final staffGap = metrics.staffGap;

    final trebleTop = topPadding;
    final bassTop = trebleTop + staffHeight + staffGap;
    final effectiveBassTop = _debugHideLowerStaff
        ? size.height + 1000
        : bassTop;
    final stavesBottomY = _debugHideLowerStaff
        ? trebleTop + staffHeight
        : bassTop + staffHeight;
    final lineSpacing = metrics.staffSpace;
    final staffLeftInset = metrics.staffLeftInset;
    final staffWidth = size.width - staffLeftInset;

    _staffPainter.paint(
      canvas,
      Rect.fromLTWH(staffLeftInset, trebleTop, staffWidth, staffHeight),
      lineSpacing,
      colors: score.colors,
    );
    if (!_debugHideLowerStaff) {
      _staffPainter.paint(
        canvas,
        Rect.fromLTWH(staffLeftInset, bassTop, staffWidth, staffHeight),
        lineSpacing,
        colors: score.colors,
      );
    }

    final trebleMainClefX = metrics.trebleMainClefX;
    final bassMainClefX = metrics.bassMainClefX;
    final trebleClefY = trebleTop + metrics.clefBaselineOffsetY;
    final bassClefY = bassTop + metrics.clefBaselineOffsetY;

    final activeKeyFifths = _activeKeyFifths(score, currentMs);
    final keySignatureEndX = _paintKeySignature(
      canvas,
      fifths: activeKeyFifths,
      colors: score.colors,
      metrics: metrics,
      trebleTop: trebleTop,
      bassTop: bassTop,
      drawBass: !_debugHideLowerStaff,
    );
    final timeSignatureEndX = _paintTimeSignature(
      canvas,
      top: score.beatsPerMeasure,
      bottom: score.beatUnit,
      startX: keySignatureEndX + metrics.keyToTimeSignatureGap,
      colors: score.colors,
      metrics: metrics,
      trebleTop: trebleTop,
      bassTop: bassTop,
      drawBass: !_debugHideLowerStaff,
    );
    final playheadX = timeSignatureEndX + metrics.timeSignatureToPlayheadGap;

    final symbolPaint = Paint()
      ..color = score.colors.staff.judgeLine
      ..strokeWidth = metrics.playheadStrokeWidth;
    final measureLinePaint = Paint()
      ..color = score.colors.staff.measureLine
      ..strokeWidth = metrics.measureLineStrokeWidth;
    final measureLineOffsetX = metrics.measureLineOffsetX;

    final trebleActiveClef = _mainClefSignForStaffAtAnchor(
      visuals.clefEventsByStaff[1] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      fallback: 'G',
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: trebleMainClefX,
    );
    final trebleMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[1] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: trebleMainClefX,
    );
    final bassActiveClef = _mainClefSignForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      fallback: 'F',
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: bassMainClefX,
    );
    final bassMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: bassMainClefX,
    );
    _textPainter.paintClef(
      canvas,
      Offset(trebleMainClefX, trebleClefY),
      _glyphForClefSign(trebleActiveClef),
      metrics.clefFontSize,
      color: _withOpacity(score.colors.notation.clef, trebleMainClefOpacity),
    );
    if (!_debugHideLowerStaff) {
      _textPainter.paintClef(
        canvas,
        Offset(bassMainClefX, bassClefY),
        _glyphForClefSign(bassActiveClef),
        metrics.clefFontSize,
        color: _withOpacity(score.colors.notation.clef, bassMainClefOpacity),
      );
    }

    final visibleStartTime = (currentMs - GameNotePainter.cleanupWindowMs)
        .floor();
    final visibleEndTime = (currentMs + GameNotePainter.previewWindowMs).ceil();
    final visibleStartIndex = _lowerBoundPreparedSymbols(
      visuals.timedSymbols,
      visibleStartTime,
    );
    final visibleEndIndex = _upperBoundPreparedSymbols(
      visuals.timedSymbols,
      visibleEndTime,
    );

    for (
      var symbolIndex = visibleStartIndex;
      symbolIndex < visibleEndIndex;
      symbolIndex++
    ) {
      final symbol = visuals.timedSymbols[symbolIndex];
      final x =
          playheadX + (symbol.timeMs - currentMs) * GameNotePainter.notePxPerMs;

      if (symbol.kind == _PreparedSymbolKind.barline) {
        if (symbol.timeMs <= 0) {
          continue;
        }
        final measureX = x + measureLineOffsetX;
        if (measureX < 10 || measureX > size.width - 10) {
          continue;
        }
        canvas.drawLine(
          Offset(measureX, trebleTop),
          Offset(measureX, stavesBottomY),
          measureLinePaint,
        );
        continue;
      }

      if (symbol.kind == _PreparedSymbolKind.keySignature) {
        continue;
      }

      if (symbol.kind == _PreparedSymbolKind.rest) {
        final rest = symbol.restSymbol;
        if (rest == null) {
          continue;
        }
        final isTrebleStaff = rest.staffNumber == 1;
        if (!isTrebleStaff && _debugHideLowerStaff) {
          continue;
        }

        final glyph = _smuflRestGlyph(rest.restType);
        final targetHeight = _restGlyphTargetHeight(
          rest.restType,
          metrics: metrics,
        );
        final baseFontSize = _smuflFontSizeForTargetHeight(
          glyph,
          targetHeight: targetHeight,
        );
        final isWholeRest = rest.restType == 'whole';
        final isWholeOrHalfRest =
            rest.restType == 'whole' || rest.restType == 'half';
        final restX = isWholeRest
            ? _centeredWholeRestX(
                restTimeMs: symbol.timeMs,
                measureStartTimes: visuals.measureStartTimes,
                playheadX: playheadX,
                currentMs: currentMs,
                barlineOffsetX: measureLineOffsetX,
              )
            : x;
        final leftCullX = -(leftInvisibleMeasurePx + metrics.staffSpace * 2.0);
        if (restX < leftCullX || restX > size.width - 10) {
          continue;
        }

        final scaleFactor = isWholeOrHalfRest
            ? metrics.restWholeHalfScaleFactor
            : metrics.restOtherScaleFactor;
        final minSize = isWholeOrHalfRest
            ? metrics.restWholeHalfMinFontSize
            : metrics.restOtherMinFontSize;
        final maxSize = isWholeOrHalfRest
            ? metrics.restWholeHalfMaxFontSize
            : metrics.restOtherMaxFontSize;
        final fontSize = (baseFontSize * scaleFactor).clamp(minSize, maxSize);

        final staffTop = isTrebleStaff ? trebleTop : bassTop;
        final restStep = _restStaffStep(rest.restType, isTreble: isTrebleStaff);
        final restY = _yForStaffStep(
          restStep,
          isTreble: isTrebleStaff,
          staffTop: staffTop,
          spacing: lineSpacing,
        );
        final baselineNudge = _restBaselineNudge(
          rest.restType,
          metrics: metrics,
        );
        final xOffsetFactor = _restXOffsetFactor(rest.restType);
        _textPainter.paintText(
          canvas,
          Offset(
            restX - fontSize * xOffsetFactor,
            restY - fontSize * 0.55 + baselineNudge,
          ),
          glyph,
          color: _withOpacity(
            score.colors.rest.glyph,
            _leftFadeOpacityAtX(restX, playheadX, metrics),
          ),
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          maxWidth: fontSize * 1.5,
          fontFamily: _bravuraFontFamily,
          height: 1.0,
        );
        continue;
      }

      if (x < 10 || x > size.width - 10) {
        continue;
      }

      if (symbol.kind == _PreparedSymbolKind.clef) {
        final clef = symbol.clefSymbol;
        if (clef == null) {
          continue;
        }
        if (symbol.timeMs <= 0) {
          continue;
        }
        final isTrebleStaff = clef.staffNumber == 1;
        if (!isTrebleStaff && _debugHideLowerStaff) {
          continue;
        }
        final glyph = _glyphForClefSign(clef.sign);
        final clefX = x + measureLineOffsetX + metrics.movingClefOffsetX;
        final y = isTrebleStaff ? trebleClefY : bassClefY;
        final mainClefX = isTrebleStaff ? trebleMainClefX : bassMainClefX;
        if (clefX <= mainClefX) {
          continue;
        }
        final passedPlayheadMs = currentMs - symbol.timeMs;
        final fadeInProgress = (passedPlayheadMs / _clefTransitionMs)
            .clamp(0.0, 1.0)
            .toDouble();
        final movingOpacity = 0.5 + (0.5 * fadeInProgress);
        _textPainter.paintClef(
          canvas,
          Offset(clefX, y),
          glyph,
          metrics.clefFontSize,
          color: _withOpacity(score.colors.notation.clef, movingOpacity),
        );
        continue;
      }
    }

    _notePainter.paintNotes(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      passedNoteIndexes: passedNoteIndexes,
      missedNoteIndexes: missedNoteIndexes,
      playheadX: playheadX,
      trebleTop: trebleTop,
      bassTop: effectiveBassTop,
      metrics: metrics,
    );

    canvas.drawLine(
      Offset(playheadX, trebleTop),
      Offset(playheadX, stavesBottomY),
      symbolPaint,
    );

    _keyboardPainter.paintKeyboard(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      keyboardTop: size.height - metrics.keyboardTopInset,
      metrics: metrics,
    );
  }

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.elapsedMsListenable != elapsedMsListenable ||
        oldDelegate.passedNoteIndexes != passedNoteIndexes ||
        oldDelegate.missedNoteIndexes != missedNoteIndexes;
  }

  int _activeKeyFifths(ScoreData score, int timeMs) {
    if (score.keySignatures.isEmpty) {
      return 0;
    }

    if (timeMs < score.keySignatures.first.timeMs) {
      return score.keySignatures.first.fifths;
    }

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

  bool _shouldUseKeySignature(int fifths) {
    return fifths.abs() >= 2;
  }

  _PrecomputedScoreVisuals _getPrecomputedScoreVisuals(ScoreData score) {
    final cached = _scoreVisualsCache[score];
    if (cached != null) {
      return cached;
    }

    final measureStartTimes = <int>[];
    final timedSymbols = <_PreparedTimedSymbol>[];
    final clefEventsByStaff = <int, List<_ClefSymbolEvent>>{};

    for (final symbol in score.symbols) {
      final label = symbol.label;
      if (label == '|') {
        measureStartTimes.add(symbol.timeMs);
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: symbol.timeMs,
            label: label,
            kind: _PreparedSymbolKind.barline,
          ),
        );
        continue;
      }

      if (label.startsWith('Key ')) {
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: symbol.timeMs,
            label: label,
            kind: _PreparedSymbolKind.keySignature,
          ),
        );
        continue;
      }

      final rest = _parseRestSymbol(label);
      if (rest != null) {
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: symbol.timeMs,
            label: label,
            kind: _PreparedSymbolKind.rest,
            restSymbol: rest,
          ),
        );
        continue;
      }

      final clef = _parseClefSymbol(label);
      if (clef != null) {
        clefEventsByStaff
            .putIfAbsent(clef.staffNumber, () => <_ClefSymbolEvent>[])
            .add(_ClefSymbolEvent(timeMs: symbol.timeMs, sign: clef.sign));
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: symbol.timeMs,
            label: label,
            kind: _PreparedSymbolKind.clef,
            clefSymbol: clef,
          ),
        );
        continue;
      }

      timedSymbols.add(
        _PreparedTimedSymbol(
          timeMs: symbol.timeMs,
          label: label,
          kind: _PreparedSymbolKind.other,
        ),
      );
    }

    measureStartTimes.sort();
    timedSymbols.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    for (final entry in clefEventsByStaff.entries) {
      entry.value.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    }

    final visuals = _PrecomputedScoreVisuals(
      measureStartTimes: List<int>.unmodifiable(measureStartTimes),
      timedSymbols: List<_PreparedTimedSymbol>.unmodifiable(timedSymbols),
      clefEventsByStaff: Map<int, List<_ClefSymbolEvent>>.unmodifiable(
        clefEventsByStaff.map(
          (key, value) =>
              MapEntry(key, List<_ClefSymbolEvent>.unmodifiable(value)),
        ),
      ),
    );
    _scoreVisualsCache[score] = visuals;
    return visuals;
  }

  int _lowerBoundPreparedSymbols(
    List<_PreparedTimedSymbol> symbols,
    int targetMs,
  ) {
    var low = 0;
    var high = symbols.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (symbols[mid].timeMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundPreparedSymbols(
    List<_PreparedTimedSymbol> symbols,
    int targetMs,
  ) {
    var low = 0;
    var high = symbols.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (symbols[mid].timeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  String _mainClefSignForStaffAtAnchor(
    List<_ClefSymbolEvent> changes, {
    required int currentMs,
    required String fallback,
    required double playheadX,
    required NotationMetrics metrics,
    required double mainClefX,
  }) {
    if (changes.isEmpty) {
      return fallback;
    }

    var activeSign = fallback;
    for (final change in changes) {
      final arrivalMs = _clefArrivalMsAtMainAnchor(
        symbolTimeMs: change.timeMs,
        playheadX: playheadX,
        metrics: metrics,
        mainClefX: mainClefX,
      );
      if (currentMs >= arrivalMs) {
        activeSign = change.sign;
      } else {
        break;
      }
    }
    return activeSign;
  }

  double _mainClefOpacityForStaffAtAnchor(
    List<_ClefSymbolEvent> changes, {
    required int currentMs,
    required double playheadX,
    required NotationMetrics metrics,
    required double mainClefX,
  }) {
    if (changes.isEmpty) {
      return 1.0;
    }

    for (final change in changes) {
      final arrivalMs = _clefArrivalMsAtMainAnchor(
        symbolTimeMs: change.timeMs,
        playheadX: playheadX,
        metrics: metrics,
        mainClefX: mainClefX,
      );
      if (currentMs >= arrivalMs) {
        continue;
      }

      final fadeStartMs = arrivalMs - _clefTransitionMs;
      if (currentMs <= fadeStartMs) {
        return 1.0;
      }

      final progress = ((currentMs - fadeStartMs) / _clefTransitionMs)
          .clamp(0.0, 1.0)
          .toDouble();
      return 1.0 - progress;
    }

    return 1.0;
  }

  int _clefArrivalMsAtMainAnchor({
    required int symbolTimeMs,
    required double playheadX,
    required NotationMetrics metrics,
    required double mainClefX,
  }) {
    final clefOffsetX = metrics.measureLineOffsetX + metrics.movingClefOffsetX;
    final distanceToMain = (playheadX + clefOffsetX) - mainClefX;
    final travelMs = distanceToMain / GameNotePainter.notePxPerMs;
    return symbolTimeMs + travelMs.round();
  }

  _ClefSymbol? _parseClefSymbol(String label) {
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

    return _ClefSymbol(staffNumber: staffNumber, sign: sign);
  }

  _RestSymbol? _parseRestSymbol(String label) {
    if (label == 'rest') {
      return const _RestSymbol(staffNumber: 1, restType: 'quarter');
    }
    if (!label.startsWith('Rest:')) {
      return null;
    }

    final parts = label.split(':');
    if (parts.length != 3) {
      return null;
    }

    final staffNumber = int.tryParse(parts[1]);
    if (staffNumber == null || (staffNumber != 1 && staffNumber != 2)) {
      return null;
    }

    final restType = parts[2].trim().toLowerCase();
    if (!_isSupportedRestType(restType)) {
      return null;
    }
    return _RestSymbol(staffNumber: staffNumber, restType: restType);
  }

  bool _isSupportedRestType(String type) {
    return type == 'whole' ||
        type == 'half' ||
        type == 'quarter' ||
        type == '8th' ||
        type == '16th' ||
        type == '32th' ||
        type == '32nd';
  }

  String _smuflRestGlyph(String restType) {
    return switch (restType) {
      'whole' => '\uE4E3',
      'half' => '\uE4E4',
      'quarter' => '\uE4E5',
      '8th' => '\uE4E6',
      '16th' => '\uE4E7',
      '32th' || '32nd' => '\uE4E8',
      _ => '\uE4E5',
    };
  }

  double _restGlyphTargetHeight(
    String restType, {
    required NotationMetrics metrics,
  }) {
    final lineSpacing = metrics.staffSpace;
    return switch (restType) {
      'whole' => (lineSpacing * 1.7).clamp(14.0, 26.0),
      'half' => (lineSpacing * 1.7).clamp(14.0, 26.0),
      'quarter' => (lineSpacing * 2.3).clamp(18.0, 36.0),
      '8th' => (lineSpacing * 2.55).clamp(20.0, 40.0),
      '16th' => (lineSpacing * 2.8).clamp(22.0, 43.0),
      '32th' || '32nd' => (lineSpacing * 3.05).clamp(24.0, 46.0),
      _ => (lineSpacing * 2.3).clamp(18.0, 36.0),
    };
  }

  int _restStaffStep(String restType, {required bool isTreble}) {
    final bottomLine = isTreble ? 30 : 18;
    return switch (restType) {
      'whole' => bottomLine + 6,
      'half' => bottomLine + 4,
      'quarter' => bottomLine + 4,
      '8th' => bottomLine + 4,
      '16th' => bottomLine + 4,
      '32th' || '32nd' => bottomLine + 4,
      _ => bottomLine + 4,
    };
  }

  double _restBaselineNudge(
    String restType, {
    required NotationMetrics metrics,
  }) {
    final lineSpacing = metrics.staffSpace;
    return switch (restType) {
      // Whole rest hangs from the 4th line; half rest sits on the middle line.
      'whole' => lineSpacing * 0.28,
      'half' => lineSpacing * 0.22,
      'quarter' => lineSpacing * 0.05,
      '8th' => lineSpacing * 0.0,
      '16th' => -lineSpacing * 0.05,
      '32th' || '32nd' => -lineSpacing * 0.11,
      _ => lineSpacing * 0.04,
    };
  }

  double _restXOffsetFactor(String restType) {
    return switch (restType) {
      'whole' => 0.17,
      'half' => 0.17,
      'quarter' => 0.17,
      '8th' => 0.17,
      '16th' => 0.17,
      '32th' || '32nd' => 0.17,
      _ => 0.35,
    };
  }

  double _centeredWholeRestX({
    required int restTimeMs,
    required List<int> measureStartTimes,
    required double playheadX,
    required int currentMs,
    required double barlineOffsetX,
  }) {
    final centerTimeMs = _measureCenterTimeMs(restTimeMs, measureStartTimes);
    return playheadX +
        (centerTimeMs - currentMs) * GameNotePainter.notePxPerMs +
        barlineOffsetX;
  }

  double _measureCenterTimeMs(int timeMs, List<int> measureStartTimes) {
    if (measureStartTimes.isEmpty) {
      return timeMs.toDouble();
    }

    var currentIndex = 0;
    for (var i = 0; i < measureStartTimes.length; i++) {
      if (measureStartTimes[i] <= timeMs) {
        currentIndex = i;
      } else {
        break;
      }
    }

    final currentMeasureStart = measureStartTimes[currentIndex];
    if (currentIndex + 1 < measureStartTimes.length) {
      final nextMeasureStart = measureStartTimes[currentIndex + 1];
      return (currentMeasureStart + nextMeasureStart) / 2.0;
    }

    if (currentIndex > 0) {
      final previousMeasureStart = measureStartTimes[currentIndex - 1];
      final lastMeasureSpan = currentMeasureStart - previousMeasureStart;
      if (lastMeasureSpan > 0) {
        return currentMeasureStart + (lastMeasureSpan / 2.0);
      }
    }

    return timeMs.toDouble();
  }

  String _glyphForClefSign(String sign) {
    return sign == 'F' ? '𝄢' : '𝄞';
  }

  String _smuflAccidentalGlyph(bool isSharp) {
    return isSharp ? '\uE262' : '\uE260';
  }

  String _smuflTimeSigDigits(int value) {
    final digits = value.abs().toString().split('');
    final buffer = StringBuffer();
    for (final digit in digits) {
      final n = int.tryParse(digit);
      if (n == null || n < 0 || n > 9) {
        continue;
      }
      buffer.writeCharCode(0xE080 + n);
    }
    if (buffer.isEmpty) {
      return String.fromCharCode(0xE080);
    }
    return buffer.toString();
  }

  Size _measureSmuflTextSize(String text, {required double fontSize}) {
    return _textPainter.measureText(
      text,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );
  }

  double _smuflFontSizeForTargetHeight(
    String text, {
    required double targetHeight,
  }) {
    const probeSize = 100.0;
    final measuredHeight = _measureSmuflTextSize(
      text,
      fontSize: probeSize,
    ).height;
    if (measuredHeight <= 0) {
      return targetHeight;
    }
    return probeSize * (targetHeight / measuredHeight);
  }

  double _paintKeySignature(
    Canvas canvas, {
    required int fifths,
    required GameColorScheme colors,
    required NotationMetrics metrics,
    required double trebleTop,
    required double bassTop,
    bool drawBass = true,
  }) {
    final lineSpacing = metrics.staffSpace;
    final startX = metrics.keySignatureStartX;
    if (!_shouldUseKeySignature(fifths)) {
      return startX;
    }

    final count = fifths.abs().clamp(0, 7);
    final isSharp = fifths > 0;
    final glyph = _smuflAccidentalGlyph(isSharp);
    final glyphFontSize = metrics.keySignatureGlyphFontSize;
    final glyphBaselineNudge = isSharp
        ? metrics.keySignatureBaselineNudgeSharp
        : metrics.keySignatureBaselineNudgeFlat;
    final spacingX = metrics.keySignatureSpacingX;

    final trebleSteps = isSharp
        ? const [38, 35, 39, 36, 33, 37, 34]
        : const [34, 37, 33, 36, 32, 35, 31];
    final bassSteps = isSharp
        ? const [24, 21, 25, 22, 19, 23, 20]
        : const [20, 23, 19, 22, 18, 21, 17];

    for (var i = 0; i < count; i++) {
      final x = startX + i * spacingX;
      final trebleY = _yForStaffStep(
        trebleSteps[i],
        isTreble: true,
        staffTop: trebleTop,
        spacing: lineSpacing,
      );
      final bassY = _yForStaffStep(
        bassSteps[i],
        isTreble: false,
        staffTop: bassTop,
        spacing: lineSpacing,
      );

      _textPainter.paintText(
        canvas,
        Offset(x, trebleY - glyphFontSize * 0.55 + glyphBaselineNudge),
        glyph,
        color: colors.notation.keySignature,
        fontSize: glyphFontSize,
        fontWeight: FontWeight.w400,
        maxWidth: glyphFontSize * 1.4,
        fontFamily: _bravuraFontFamily,
        height: 1.0,
      );
      if (drawBass) {
        _textPainter.paintText(
          canvas,
          Offset(x, bassY - glyphFontSize * 0.55 + glyphBaselineNudge),
          glyph,
          color: colors.notation.keySignature,
          fontSize: glyphFontSize,
          fontWeight: FontWeight.w400,
          maxWidth: glyphFontSize * 1.4,
          fontFamily: _bravuraFontFamily,
          height: 1.0,
        );
      }
    }

    return startX + count * spacingX + metrics.keySignatureTrailingGap;
  }

  double _paintTimeSignature(
    Canvas canvas, {
    required int top,
    required int bottom,
    required double startX,
    required GameColorScheme colors,
    required NotationMetrics metrics,
    required double trebleTop,
    required double bassTop,
    bool drawBass = true,
  }) {
    final topText = _smuflTimeSigDigits(top);
    final bottomText = _smuflTimeSigDigits(bottom);
    final targetDigitHeight = metrics.timeSignatureTargetDigitHeight;
    final topSizeProbe = _smuflFontSizeForTargetHeight(
      topText,
      targetHeight: targetDigitHeight,
    );
    final bottomSizeProbe = _smuflFontSizeForTargetHeight(
      bottomText,
      targetHeight: targetDigitHeight,
    );
    final fontSize =
        (topSizeProbe > bottomSizeProbe ? topSizeProbe : bottomSizeProbe)
            .clamp(
              metrics.timeSignatureMinFontSize /
                  metrics.timeSignatureVisualScale,
              metrics.timeSignatureMaxFontSize /
                  metrics.timeSignatureVisualScale,
            )
            .toDouble() *
        metrics.timeSignatureVisualScale;
    final effectiveFontSize = fontSize
        .clamp(
          metrics.timeSignatureMinFontSize,
          metrics.timeSignatureMaxFontSize,
        )
        .toDouble();

    final topSize = _measureSmuflTextSize(topText, fontSize: effectiveFontSize);
    final bottomSize = _measureSmuflTextSize(
      bottomText,
      fontSize: effectiveFontSize,
    );
    final topWidth = topSize.width;
    final bottomWidth = bottomSize.width;
    final topHeight = topSize.height;
    final bottomHeight = bottomSize.height;
    final blockWidth = topWidth > bottomWidth ? topWidth : bottomWidth;

    final centerX = startX + blockWidth / 2;
    final topX = centerX - topWidth / 2;
    final bottomX = centerX - bottomWidth / 2;
    final trebleTopY =
        trebleTop + metrics.timeSignatureTopCenterOffset - topHeight / 2;
    final trebleBottomY =
        trebleTop + metrics.timeSignatureBottomCenterOffset - bottomHeight / 2;

    _textPainter.paintText(
      canvas,
      Offset(topX, trebleTopY),
      topText,
      color: colors.notation.timeSignature,
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.w400,
      maxWidth: blockWidth + metrics.timeSignatureMaxWidthPadding,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );
    _textPainter.paintText(
      canvas,
      Offset(bottomX, trebleBottomY),
      bottomText,
      color: colors.notation.timeSignature,
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.w400,
      maxWidth: blockWidth + metrics.timeSignatureMaxWidthPadding,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );

    final blockRightX = centerX + blockWidth / 2;

    if (!drawBass) {
      return blockRightX;
    }

    final bassTopY =
        bassTop + metrics.timeSignatureTopCenterOffset - topHeight / 2;
    final bassBottomY =
        bassTop + metrics.timeSignatureBottomCenterOffset - bottomHeight / 2;
    _textPainter.paintText(
      canvas,
      Offset(topX, bassTopY),
      topText,
      color: colors.notation.timeSignature,
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.w400,
      maxWidth: blockWidth + metrics.timeSignatureMaxWidthPadding,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );
    _textPainter.paintText(
      canvas,
      Offset(bottomX, bassBottomY),
      bottomText,
      color: colors.notation.timeSignature,
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.w400,
      maxWidth: blockWidth + metrics.timeSignatureMaxWidthPadding,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );

    return blockRightX + metrics.timeSignatureMaxWidthPadding * 0.5;
  }

  double _yForStaffStep(
    int staffStep, {
    required bool isTreble,
    required double staffTop,
    required double spacing,
  }) {
    final refStep = isTreble ? 30 : 18;
    final diff = staffStep - refStep;
    return staffTop + spacing * 4 - diff * (spacing / 2);
  }

  Color _withOpacity(Color base, double opacity) {
    final alpha = (255 * opacity.clamp(0.0, 1.0)).round();
    return base.withAlpha(alpha);
  }

  double _leftFadeOpacityAtX(
    double x,
    double playheadX,
    NotationMetrics metrics,
  ) {
    if (x >= playheadX) {
      return 1.0;
    }
    final fadeDistance = ((metrics.staffSpace * 6.0)).clamp(28.0, 160.0);
    final progress = ((playheadX - x) / fadeDistance).clamp(0.0, 1.0);
    return 1.0 - progress;
  }
}

class _ClefSymbolEvent {
  const _ClefSymbolEvent({required this.timeMs, required this.sign});

  final int timeMs;
  final String sign;
}

class _ClefSymbol {
  const _ClefSymbol({required this.staffNumber, required this.sign});

  final int staffNumber;
  final String sign;
}

class _RestSymbol {
  const _RestSymbol({required this.staffNumber, required this.restType});

  final int staffNumber;
  final String restType;
}

class _PrecomputedScoreVisuals {
  const _PrecomputedScoreVisuals({
    required this.measureStartTimes,
    required this.timedSymbols,
    required this.clefEventsByStaff,
  });

  final List<int> measureStartTimes;
  final List<_PreparedTimedSymbol> timedSymbols;
  final Map<int, List<_ClefSymbolEvent>> clefEventsByStaff;
}

enum _PreparedSymbolKind { barline, keySignature, rest, clef, other }

class _PreparedTimedSymbol {
  const _PreparedTimedSymbol({
    required this.timeMs,
    required this.label,
    required this.kind,
    this.restSymbol,
    this.clefSymbol,
  });

  final int timeMs;
  final String label;
  final _PreparedSymbolKind kind;
  final _RestSymbol? restSymbol;
  final _ClefSymbol? clefSymbol;
}
