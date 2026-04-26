import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
import '../../domain/staff_background.dart';
import '../notation/notation_metrics.dart';
import '../cubit/game_prototype_cubit.dart';
import '../cubit/game_prototype_state.dart';
import '../painters/game_keyboard_painter.dart';
import '../painters/game_note_painter.dart';
import '../painters/game_staff_painter.dart';
import '../painters/game_text_painter.dart';
import '../provider/game_prototype_provider.dart';
import '../widgets/game_prototype_setting_widget.dart';

class GamePrototypePage extends StatelessWidget {
  const GamePrototypePage({super.key, this.assetMxlPath, this.songTitle});

  final String? assetMxlPath;
  final String? songTitle;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GamePrototypeSettingsProvider()),
        BlocProvider(
          create: (_) => GamePrototypeCubit(
            assetMxlPath: assetMxlPath,
            songTitle: songTitle,
          )..initialize(),
        ),
      ],
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
  static const MethodChannel _screenControlChannel = MethodChannel(
    'pianomisspass/screen_control',
  );

  bool _isKeepingScreenOn = false;

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
    _setKeepScreenOn(false);
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
    return Consumer<GamePrototypeSettingsProvider>(
      builder: (context, settings, _) {
        return BlocListener<GamePrototypeCubit, GamePrototypeState>(
          listenWhen: (previous, current) =>
              previous.isPlaying != current.isPlaying,
          listener: (_, state) {
            _setKeepScreenOn(state.isPlaying);
          },
          child: PopScope(
            canPop: true,
            onPopInvokedWithResult: (_, _) {
              cubit.pause();
            },
            child: Scaffold(
              body: BlocBuilder<GamePrototypeCubit, GamePrototypeState>(
                buildWhen: (previous, current) =>
                    previous.isLoading != current.isLoading ||
                    previous.errorMessage != current.errorMessage ||
                    previous.score != current.score ||
                    previous.isPlaying != current.isPlaying ||
                    previous.inputMode != current.inputMode ||
                    previous.audioStaffMode != current.audioStaffMode ||
                    previous.visibleStaffMode != current.visibleStaffMode ||
                    previous.gameplayMode != current.gameplayMode ||
                    previous.isSoundfontReady != current.isSoundfontReady ||
                    previous.isMicrophoneActive != current.isMicrophoneActive ||
                    previous.inputDeviceName != current.inputDeviceName ||
                    previous.activeInputMidis != current.activeInputMidis ||
                    previous.microphoneDebug != current.microphoneDebug ||
                    previous.playbackSpeed != current.playbackSpeed ||
                    previous.timelineMsPerDurationDivision !=
                        current.timelineMsPerDurationDivision,
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
                  final effectiveScore = settings.resolveEffectiveScore(score);
                  final hasCompletedSong =
                      !state.isPlaying &&
                      cubit.maxDurationMs > 0 &&
                      cubit.currentMs >= cubit.maxDurationMs;
                  final completionScore = _calculateCompletionScore(
                    passedNotes: state.passedNoteIndexes.length,
                    totalNotes: score.notes.length,
                  );

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: _GameScreenBackground(
                          background: settings.staffBackground,
                        ),
                      ),
                      CustomPaint(
                        painter: _StaffScrollerPainter(
                          score: effectiveScore,
                          inputMode: state.inputMode,
                          activeInputMidis: state.activeInputMidis,
                          elapsedMsListenable: cubit.elapsedMsListenable,
                          animationClockListenable:
                              cubit.animationClockListenable,
                          passedNoteIndexesListenable:
                              cubit.passedNoteIndexesListenable,
                          missedNoteIndexesListenable:
                              cubit.missedNoteIndexesListenable,
                          judgeAnimationByNoteIndexListenable:
                              cubit.judgeAnimationByNoteIndexListenable,
                          showKeyboard: settings.showKeyboard,
                          staffHeightScale: settings.staffHeightScale,
                          visibleStaffMode: state.visibleStaffMode,
                          gameplayMode: state.gameplayMode,
                          timelineMsPerDurationDivision:
                              state.timelineMsPerDurationDivision,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      if (state.isPlaying)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _PlaybackButton(
                            isPlaying: true,
                            onPressed: cubit.pause,
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
                              color: effectiveScore.colors.note.pass,
                            );
                          },
                        ),
                      ),
                      if (state.isPlaying)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ValueListenableBuilder<int>(
                              valueListenable: cubit.elapsedMsListenable,
                              builder: (context, elapsedMs, _) {
                                if (state.gameplayMode == GamePlayMode.step ||
                                    elapsedMs >= 0) {
                                  return const SizedBox.shrink();
                                }
                                final countdown = ((-elapsedMs) / 1000)
                                    .ceil()
                                    .clamp(1, 3);
                                return Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(84),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        '$countdown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 56,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (!state.isPlaying)
                        Positioned.fill(
                          child: GamePrototypeSettingWidget(
                            songTitle: cubit.songTitle,
                            state: state,
                            hasCompletedSong: hasCompletedSong,
                            completionScore: completionScore,
                            onRepeat: cubit.repeat,
                            onBack: () {
                              cubit.pause();
                              Navigator.of(context).maybePop();
                            },
                            onPlay: cubit.play,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _setKeepScreenOn(bool enabled) async {
    if (_isKeepingScreenOn == enabled) {
      return;
    }
    _isKeepingScreenOn = enabled;
    try {
      await _screenControlChannel.invokeMethod<void>(
        'setKeepScreenOn',
        <String, Object>{'enabled': enabled},
      );
    } catch (_) {
      // Ignore platform errors and fall back to the system default behavior.
    }
  }

  int _calculateCompletionScore({
    required int passedNotes,
    required int totalNotes,
  }) {
    if (totalNotes <= 0) {
      return 0;
    }
    return ((passedNotes / totalNotes) * 100).round();
  }
}

class _GameScreenBackground extends StatelessWidget {
  const _GameScreenBackground({required this.background});

  final GameStaffBackground background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            background.color ?? background.fallbackColor ?? Colors.transparent,
        gradient: background.gradient,
        image: background.imageAssetPath != null
            ? DecorationImage(
                image: AssetImage(background.imageAssetPath!),
                fit: background.imageFit,
                alignment: background.imageAlignment,
              )
            : null,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TopProgressLine extends StatelessWidget {
  const _TopProgressLine({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trackRadius = BorderRadius.circular(999);
    return IgnorePointer(
      child: SizedBox(
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: trackRadius,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(36),
                blurRadius: 10,
                spreadRadius: 0.2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: trackRadius,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [color.withAlpha(220), color],
                    ),
                    borderRadius: trackRadius,
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(140),
                        blurRadius: 10,
                        spreadRadius: 0.6,
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
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
  static const String _grandStaffBraceGlyph = '\uE000';
  static const int _clefTransitionMs = 700;
  static final Expando<_PrecomputedScoreVisuals> _scoreVisualsCache =
      Expando<_PrecomputedScoreVisuals>('game-prototype-score-visuals');

  _StaffScrollerPainter({
    required this.score,
    required this.inputMode,
    required this.activeInputMidis,
    required this.elapsedMsListenable,
    required this.animationClockListenable,
    required this.passedNoteIndexesListenable,
    required this.missedNoteIndexesListenable,
    required this.judgeAnimationByNoteIndexListenable,
    required this.showKeyboard,
    required this.staffHeightScale,
    required this.visibleStaffMode,
    required this.gameplayMode,
    required this.timelineMsPerDurationDivision,
  }) : super(
         repaint: Listenable.merge([
           elapsedMsListenable,
           animationClockListenable,
           passedNoteIndexesListenable,
           missedNoteIndexesListenable,
           judgeAnimationByNoteIndexListenable,
         ]),
       );

  final ScoreData score;
  final GameInputMode inputMode;
  final Set<int> activeInputMidis;
  final ValueListenable<int> elapsedMsListenable;
  final ValueListenable<int> animationClockListenable;
  final ValueListenable<Set<int>> passedNoteIndexesListenable;
  final ValueListenable<Set<int>> missedNoteIndexesListenable;
  final ValueListenable<Map<int, GameNoteJudgeAnimation>>
  judgeAnimationByNoteIndexListenable;
  final bool showKeyboard;
  final double staffHeightScale;
  final GameVisibleStaffMode visibleStaffMode;
  final GamePlayMode gameplayMode;
  final int timelineMsPerDurationDivision;

  final GameStaffPainter _staffPainter = GameStaffPainter();
  final GameTextPainter _textPainter = GameTextPainter();
  final GameNotePainter _notePainter = GameNotePainter();
  final GameKeyboardPainter _keyboardPainter = GameKeyboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = elapsedMsListenable.value;
    final currentAnimationClockMs = animationClockListenable.value;
    final passedNoteIndexes = passedNoteIndexesListenable.value;
    final missedNoteIndexes = missedNoteIndexesListenable.value;
    final judgeAnimationByNoteIndex = judgeAnimationByNoteIndexListenable.value;
    final visuals = _getPrecomputedScoreVisuals(score);
    final timelineMapper = NoteTiming.visualTimelineForScore(score);
    final baseMetrics = NotationMetrics.fromCanvasSize(size);
    final notePxPerMs = NoteTiming.notePxPerMsForTimeline(
      timelineMsPerDurationDivision: timelineMsPerDurationDivision,
    );
    final currentVisualMs = timelineMapper
        .visualTimeForRealMs(currentMs)
        .round();
    final keyboardHeight = showKeyboard ? baseMetrics.keyboardTotalHeight : 0.0;
    final staffRegionHeight = (size.height - keyboardHeight).clamp(
      0.0,
      size.height,
    );
    final metrics = NotationMetrics.fromCanvasSize(
      size,
      staffRegionHeight: staffRegionHeight,
      staffHeightScale: staffHeightScale,
    );
    final measureMs = timelineMapper.visualMeasureDurationAtRealMs(currentMs);
    final leftInvisibleMeasurePx = measureMs * notePxPerMs;
    final staffHeight = metrics.staffHeight;
    final keyboardTop = size.height - keyboardHeight;
    final singleStaffTop = (staffRegionHeight - staffHeight) / 2.0;
    final hasLowerStaff = _scoreHasLowerStaff(score);
    final forceSingleCenteredStaff = !hasLowerStaff;
    final double twoStaffGap = metrics.staffSpace * 5.0;
    final double twoStaffBlockHeight = staffHeight * 2 + twoStaffGap;
    final double centeredTwoStaffTop =
        (staffRegionHeight - twoStaffBlockHeight) / 2.0;
    final showUpperStaff = forceSingleCenteredStaff
        ? true
        : visibleStaffMode != GameVisibleStaffMode.lowerOnly;
    final showLowerStaff = forceSingleCenteredStaff
        ? false
        : visibleStaffMode != GameVisibleStaffMode.upperOnly;
    final trebleTop =
        (!forceSingleCenteredStaff &&
            visibleStaffMode == GameVisibleStaffMode.both)
        ? centeredTwoStaffTop
        : singleStaffTop;
    final bassTop =
        (!forceSingleCenteredStaff &&
            visibleStaffMode == GameVisibleStaffMode.both)
        ? trebleTop + staffHeight + twoStaffGap
        : singleStaffTop;
    final effectiveBassTop = showLowerStaff && !_debugHideLowerStaff
        ? bassTop
        : size.height + 1000;
    final playheadTopY = showUpperStaff ? trebleTop : bassTop;
    final stavesBottomY = showLowerStaff
        ? bassTop + staffHeight
        : trebleTop + staffHeight;
    final lineSpacing = metrics.staffSpace;
    final staffLeftInset = metrics.staffLeftInset;
    final staffWidth = size.width - staffLeftInset;

    if (showUpperStaff) {
      _staffPainter.paint(
        canvas,
        Rect.fromLTWH(staffLeftInset, trebleTop, staffWidth, staffHeight),
        lineSpacing,
        colors: score.colors,
      );
    }
    if (showLowerStaff && !_debugHideLowerStaff) {
      _staffPainter.paint(
        canvas,
        Rect.fromLTWH(staffLeftInset, bassTop, staffWidth, staffHeight),
        lineSpacing,
        colors: score.colors,
      );
    }
    if (showUpperStaff && showLowerStaff && !_debugHideLowerStaff) {
      _paintGrandStaffBrace(
        canvas,
        score: score,
        metrics: metrics,
        trebleTop: trebleTop,
        bassTop: bassTop,
      );
    }

    final trebleMainClefX = metrics.trebleMainClefX;
    final bassMainClefX = metrics.bassMainClefX;
    final trebleClefY = trebleTop + metrics.clefBaselineOffsetY;
    final bassClefY = bassTop + metrics.clefBaselineOffsetY;

    final playheadX = metrics.fixedPlayheadX;
    final keySignatureTransition = _resolveKeySignatureTransition(
      score,
      visuals,
      currentVisualMs,
      timelineMapper,
    );
    if (keySignatureTransition.fromOpacity > 0.0 &&
        _shouldUseKeySignature(keySignatureTransition.fromFifths)) {
      _paintKeySignature(
        canvas,
        fifths: keySignatureTransition.fromFifths,
        colors: score.colors,
        metrics: metrics,
        trebleTop: trebleTop,
        bassTop: bassTop,
        drawTreble: showUpperStaff,
        drawBass: showLowerStaff && !_debugHideLowerStaff,
        opacity: keySignatureTransition.fromOpacity,
      );
    }
    if (keySignatureTransition.toOpacity > 0.0 &&
        _shouldUseKeySignature(keySignatureTransition.toFifths)) {
      _paintKeySignature(
        canvas,
        fifths: keySignatureTransition.toFifths,
        colors: score.colors,
        metrics: metrics,
        trebleTop: trebleTop,
        bassTop: bassTop,
        drawTreble: showUpperStaff,
        drawBass: showLowerStaff && !_debugHideLowerStaff,
        opacity: keySignatureTransition.toOpacity,
      );
    }
    if (gameplayMode != GamePlayMode.step &&
        keySignatureTransition.timeSignatureOpacity > 0.0) {
      _paintTimeSignature(
        canvas,
        top: score.beatsPerMeasure,
        bottom: score.beatUnit,
        rightX: playheadX - metrics.timeSignatureToPlayheadGap,
        colors: score.colors,
        metrics: metrics,
        trebleTop: trebleTop,
        bassTop: bassTop,
        drawTreble: showUpperStaff,
        drawBass: showLowerStaff && !_debugHideLowerStaff,
        opacity: keySignatureTransition.timeSignatureOpacity,
      );
    }

    final checkLineColor = score.colors.note.pass;
    final symbolPaint = Paint()
      ..color = checkLineColor
      ..strokeWidth = metrics.playheadStrokeWidth * 1.5
      ..strokeCap = StrokeCap.round;
    final measureLinePaint = Paint()
      ..color = score.colors.staff.measureLine
      ..strokeWidth = metrics.measureLineStrokeWidth;
    final measureLineOffsetX =
        metrics.measureLineOffsetX +
        (gameplayMode == GamePlayMode.step ? metrics.staffSpace * 1.6 : 0.0);

    final trebleActiveClef = _mainClefSignForStaffAtAnchor(
      visuals.clefEventsByStaff[1] ?? const <_ClefSymbolEvent>[],
      currentMs: currentVisualMs,
      fallback: 'G',
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: trebleMainClefX,
      notePxPerMs: notePxPerMs,
    );
    final trebleMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[1] ?? const <_ClefSymbolEvent>[],
      currentMs: currentVisualMs,
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: trebleMainClefX,
      notePxPerMs: notePxPerMs,
    );
    final bassActiveClef = _mainClefSignForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentVisualMs,
      fallback: 'F',
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: bassMainClefX,
      notePxPerMs: notePxPerMs,
    );
    final bassMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentVisualMs,
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: bassMainClefX,
      notePxPerMs: notePxPerMs,
    );
    if (showUpperStaff) {
      _textPainter.paintClef(
        canvas,
        Offset(trebleMainClefX, trebleClefY),
        _glyphForClefSign(trebleActiveClef),
        metrics.clefFontSize,
        color: _withOpacity(score.colors.notation.clef, trebleMainClefOpacity),
      );
    }
    if (showLowerStaff && !_debugHideLowerStaff) {
      _textPainter.paintClef(
        canvas,
        Offset(bassMainClefX, bassClefY),
        _glyphForClefSign(bassActiveClef),
        metrics.clefFontSize,
        color: _withOpacity(score.colors.notation.clef, bassMainClefOpacity),
      );
    }

    final visibleStartTime = (currentVisualMs - GameNotePainter.cleanupWindowMs)
        .floor();
    final visibleEndTime = (currentVisualMs + GameNotePainter.previewWindowMs)
        .ceil();
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
      final x = playheadX + (symbol.timeMs - currentVisualMs) * notePxPerMs;

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
        if ((isTrebleStaff && !showUpperStaff) ||
            (!isTrebleStaff && (!showLowerStaff || _debugHideLowerStaff))) {
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
                currentMs: currentVisualMs,
                barlineOffsetX: measureLineOffsetX,
                notePxPerMs: notePxPerMs,
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
        if ((isTrebleStaff && !showUpperStaff) ||
            (!isTrebleStaff && (!showLowerStaff || _debugHideLowerStaff))) {
          continue;
        }
        final glyph = _glyphForClefSign(clef.sign);
        final clefX = x + measureLineOffsetX + metrics.movingClefOffsetX;
        final y = isTrebleStaff ? trebleClefY : bassClefY;
        final mainClefX = isTrebleStaff ? trebleMainClefX : bassMainClefX;
        if (clefX <= mainClefX) {
          continue;
        }
        final passedPlayheadMs = currentVisualMs - symbol.timeMs;
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

    final earlyHitWindowWidth =
        GamePrototypeCubit.earlyHitWindowMs * notePxPerMs;
    if (earlyHitWindowWidth > 0) {
      final hitZonePaint = Paint()
        ..color = score.colors.staff.judgeLine.withAlpha(0);
      canvas.drawRect(
        Rect.fromLTRB(
          playheadX,
          playheadTopY,
          math.min(size.width, playheadX + earlyHitWindowWidth),
          stavesBottomY,
        ),
        hitZonePaint,
      );
    }

    _notePainter.paintNotes(
      canvas,
      size,
      score: score,
      currentMs: currentMs,
      animationClockMs: currentAnimationClockMs,
      passedNoteIndexes: passedNoteIndexes,
      missedNoteIndexes: missedNoteIndexes,
      judgeAnimationByNoteIndex: judgeAnimationByNoteIndex,
      playheadX: playheadX,
      trebleTop: trebleTop,
      bassTop: effectiveBassTop,
      visibleStaffMode: visibleStaffMode,
      gameplayMode: gameplayMode,
      metrics: metrics,
      notePxPerMs: notePxPerMs,
    );

    if (gameplayMode == GamePlayMode.scrolling) {
      final checkLineHeight = metrics.staffSpace * 17.0;
      final checkLineCenterY = (playheadTopY + stavesBottomY) / 2.0;
      final checkLineTopY = math.max(
        0.0,
        checkLineCenterY - checkLineHeight / 2.0,
      );
      final checkLineBottomY = math.min(
        size.height,
        checkLineCenterY + checkLineHeight / 2.0,
      );
      final checkLineTrailWidth = metrics.staffSpace * 3.2;
      final checkLineTrailVerticalInset = symbolPaint.strokeWidth * 0.5;
      final checkLineTrailRect = Rect.fromLTRB(
        playheadX - checkLineTrailWidth,
        math.max(0.0, checkLineTopY - checkLineTrailVerticalInset),
        playheadX,
        math.min(size.height, checkLineBottomY + checkLineTrailVerticalInset),
      );
      final checkLineTrailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            checkLineColor.withAlpha(186),
            checkLineColor.withAlpha(118),
            checkLineColor.withAlpha(52),
            checkLineColor.withAlpha(0),
          ],
          stops: [0.0, 0.16, 0.52, 1.0],
        ).createShader(checkLineTrailRect);
      canvas.drawRect(checkLineTrailRect, checkLineTrailPaint);
      canvas.drawLine(
        Offset(playheadX, checkLineTopY),
        Offset(playheadX, checkLineBottomY),
        symbolPaint,
      );
    }

    if (showKeyboard) {
      _keyboardPainter.paintKeyboard(
        canvas,
        size,
        score: score,
        currentMs: currentMs,
        inputMode: inputMode,
        activeInputMidis: activeInputMidis,
        passedNoteIndexes: passedNoteIndexes,
        missedNoteIndexes: missedNoteIndexes,
        visibleStaffMode: visibleStaffMode,
        keyboardTop: keyboardTop,
        metrics: metrics,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.inputMode != inputMode ||
        oldDelegate.activeInputMidis != activeInputMidis ||
        oldDelegate.elapsedMsListenable != elapsedMsListenable ||
        oldDelegate.animationClockListenable != animationClockListenable ||
        oldDelegate.passedNoteIndexesListenable !=
            passedNoteIndexesListenable ||
        oldDelegate.missedNoteIndexesListenable !=
            missedNoteIndexesListenable ||
        oldDelegate.judgeAnimationByNoteIndexListenable !=
            judgeAnimationByNoteIndexListenable ||
        oldDelegate.showKeyboard != showKeyboard ||
        oldDelegate.staffHeightScale != staffHeightScale ||
        oldDelegate.visibleStaffMode != visibleStaffMode ||
        oldDelegate.gameplayMode != gameplayMode ||
        oldDelegate.timelineMsPerDurationDivision !=
            timelineMsPerDurationDivision;
  }

  int _activeKeyFifths(
    ScoreData score,
    int timeMs,
    ScoreVisualTimelineMapper timelineMapper,
  ) {
    if (score.keySignatures.isEmpty) {
      return 0;
    }

    final firstChangeVisualMs = timelineMapper.visualTimeForRealMs(
      score.keySignatures.first.timeMs,
    );
    if (timeMs < firstChangeVisualMs) {
      return score.keySignatures.first.fifths;
    }

    var result = 0;
    for (final change in score.keySignatures) {
      final changeVisualMs = timelineMapper.visualTimeForRealMs(change.timeMs);
      if (changeVisualMs <= timeMs) {
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

  bool _shouldHideTimeSignatureForKeyFifths(int fifths) {
    return fifths.abs() >= 5;
  }

  bool _scoreHasLowerStaff(ScoreData score) {
    for (final note in score.notes) {
      if (note.staffNumber == 2) {
        return true;
      }
    }
    for (final slur in score.slurs) {
      if (slur.staffNumber == 2) {
        return true;
      }
    }
    for (final symbol in score.symbols) {
      final label = symbol.label;
      if (label.startsWith('Clef:2:') || label.startsWith('Rest:2:')) {
        return true;
      }
    }
    return false;
  }

  _KeySignatureTransition _resolveKeySignatureTransition(
    ScoreData score,
    _PrecomputedScoreVisuals visuals,
    int currentMs,
    ScoreVisualTimelineMapper timelineMapper,
  ) {
    final activeFifths = _activeKeyFifths(score, currentMs, timelineMapper);
    if (score.keySignatures.isEmpty) {
      return _KeySignatureTransition(
        fromFifths: activeFifths,
        toFifths: activeFifths,
        fromOpacity: 0.0,
        toOpacity: _shouldUseKeySignature(activeFifths) ? 1.0 : 0.0,
        timeSignatureOpacity: _shouldHideTimeSignatureForKeyFifths(activeFifths)
            ? 0.0
            : 1.0,
      );
    }

    KeySignatureChange? nextChange;
    KeySignatureChange? previousChange;
    for (final change in score.keySignatures) {
      final changeVisualMs = timelineMapper.visualTimeForRealMs(change.timeMs);
      if (changeVisualMs <= currentMs) {
        previousChange = change;
        continue;
      }
      nextChange = change;
      break;
    }

    if (nextChange == null) {
      return _KeySignatureTransition(
        fromFifths: activeFifths,
        toFifths: activeFifths,
        fromOpacity: 0.0,
        toOpacity: _shouldUseKeySignature(activeFifths) ? 1.0 : 0.0,
        timeSignatureOpacity: _shouldHideTimeSignatureForKeyFifths(activeFifths)
            ? 0.0
            : 1.0,
      );
    }

    final transitionStartMs = _transitionStartMsForKeyChange(
      changeTimeMs: timelineMapper
          .visualTimeForRealMs(nextChange.timeMs)
          .round(),
      measureStartTimes: visuals.measureStartTimes,
      score: score,
      timelineMapper: timelineMapper,
    );
    if (transitionStartMs <= 0) {
      return _KeySignatureTransition(
        fromFifths: activeFifths,
        toFifths: activeFifths,
        fromOpacity: 0.0,
        toOpacity: _shouldUseKeySignature(activeFifths) ? 1.0 : 0.0,
        timeSignatureOpacity: _shouldHideTimeSignatureForKeyFifths(activeFifths)
            ? 0.0
            : 1.0,
      );
    }
    if (currentMs < transitionStartMs) {
      return _KeySignatureTransition(
        fromFifths: activeFifths,
        toFifths: activeFifths,
        fromOpacity: 0.0,
        toOpacity: _shouldUseKeySignature(activeFifths) ? 1.0 : 0.0,
        timeSignatureOpacity: _shouldHideTimeSignatureForKeyFifths(activeFifths)
            ? 0.0
            : 1.0,
      );
    }

    final fromFifths = previousChange?.fifths ?? 0;
    final toFifths = nextChange.fifths;
    final nextChangeVisualMs = timelineMapper.visualTimeForRealMs(
      nextChange.timeMs,
    );
    final transitionDurationMs = (nextChangeVisualMs - transitionStartMs).abs();
    final progress = transitionDurationMs <= 0
        ? 1.0
        : ((currentMs - transitionStartMs) / transitionDurationMs)
              .clamp(0.0, 1.0)
              .toDouble();

    final fromVisible = _shouldUseKeySignature(fromFifths);
    final toVisible = _shouldUseKeySignature(toFifths);
    final fromTimeSigVisible = !_shouldHideTimeSignatureForKeyFifths(
      fromFifths,
    );
    final toTimeSigVisible = !_shouldHideTimeSignatureForKeyFifths(toFifths);
    return _KeySignatureTransition(
      fromFifths: fromFifths,
      toFifths: toFifths,
      fromOpacity: fromVisible ? 1.0 - progress : 0.0,
      toOpacity: toVisible ? progress : 0.0,
      timeSignatureOpacity: _lerpDouble(
        fromTimeSigVisible ? 1.0 : 0.0,
        toTimeSigVisible ? 1.0 : 0.0,
        progress,
      ),
    );
  }

  int _transitionStartMsForKeyChange({
    required int changeTimeMs,
    required List<int> measureStartTimes,
    required ScoreData score,
    required ScoreVisualTimelineMapper timelineMapper,
  }) {
    for (var i = measureStartTimes.length - 1; i >= 0; i--) {
      final measureStart = measureStartTimes[i];
      if (measureStart < changeTimeMs) {
        return measureStart;
      }
    }
    final measureMs = score.measureSpans.isEmpty
        ? NoteTiming.defaultTimelineMsPerDurationDivision.toDouble()
        : timelineMapper.visualMeasureDurationMs(score.measureSpans.first);
    return changeTimeMs - measureMs.round();
  }

  double _lerpDouble(double from, double to, double t) {
    return from + (to - from) * t;
  }

  _PrecomputedScoreVisuals _getPrecomputedScoreVisuals(ScoreData score) {
    final cached = _scoreVisualsCache[score];
    if (cached != null) {
      return cached;
    }

    final measureStartTimes = <int>[];
    final timedSymbols = <_PreparedTimedSymbol>[];
    final clefEventsByStaff = <int, List<_ClefSymbolEvent>>{};
    final timelineMapper = NoteTiming.visualTimelineForScore(score);
    int? lastBarlineMeasureIndex;

    for (final symbol in score.symbols) {
      final label = symbol.label;
      final visualTimeMs = timelineMapper
          .visualTimeForRealMs(symbol.timeMs)
          .round();
      if (label == '|') {
        if (symbol.measureIndex != null &&
            symbol.measureIndex == lastBarlineMeasureIndex) {
          continue;
        }
        lastBarlineMeasureIndex = symbol.measureIndex;
        measureStartTimes.add(visualTimeMs);
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: visualTimeMs,
            label: label,
            kind: _PreparedSymbolKind.barline,
          ),
        );
        continue;
      }

      if (label.startsWith('Key ')) {
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: visualTimeMs,
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
            timeMs: visualTimeMs,
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
            .add(_ClefSymbolEvent(timeMs: visualTimeMs, sign: clef.sign));
        timedSymbols.add(
          _PreparedTimedSymbol(
            timeMs: visualTimeMs,
            label: label,
            kind: _PreparedSymbolKind.clef,
            clefSymbol: clef,
          ),
        );
        continue;
      }

      timedSymbols.add(
        _PreparedTimedSymbol(
          timeMs: visualTimeMs,
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
    required double notePxPerMs,
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
        notePxPerMs: notePxPerMs,
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
    required double notePxPerMs,
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
        notePxPerMs: notePxPerMs,
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
    required double notePxPerMs,
  }) {
    final clefOffsetX = metrics.measureLineOffsetX + metrics.movingClefOffsetX;
    final distanceToMain = (playheadX + clefOffsetX) - mainClefX;
    final travelMs = distanceToMain / notePxPerMs;
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
    final scale = metrics.visualScale;
    return switch (restType) {
      'whole' => (lineSpacing * 1.38).clamp(12.0 * scale, 22.0 * scale),
      'half' => (lineSpacing * 1.38).clamp(12.0 * scale, 22.0 * scale),
      'quarter' => (lineSpacing * 1.9).clamp(16.0 * scale, 30.0 * scale),
      '8th' => (lineSpacing * 2.1).clamp(17.0 * scale, 33.0 * scale),
      '16th' => (lineSpacing * 2.3).clamp(18.0 * scale, 36.0 * scale),
      '32th' ||
      '32nd' => (lineSpacing * 3.05).clamp(24.0 * scale, 46.0 * scale),
      _ => (lineSpacing * 2.3).clamp(18.0 * scale, 36.0 * scale),
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
      'half' => lineSpacing * 0.28,
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
    required double notePxPerMs,
  }) {
    final centerTimeMs = _measureCenterTimeMs(restTimeMs, measureStartTimes);
    return playheadX +
        (centerTimeMs - currentMs) * notePxPerMs +
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

  void _paintGrandStaffBrace(
    Canvas canvas, {
    required ScoreData score,
    required NotationMetrics metrics,
    required double trebleTop,
    required double bassTop,
  }) {
    final braceSpanHeight =
        (bassTop + metrics.staffHeight - trebleTop) + metrics.staffSpace * 0.18;
    final baseFontSize = math.max(
      metrics.clefFontSize * 1.22,
      metrics.staffHeight * 2.0,
    );
    final baseSize = _textPainter.measureText(
      _grandStaffBraceGlyph,
      fontSize: baseFontSize,
      fontWeight: FontWeight.w400,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
      maxWidth: baseFontSize * 1.2,
    );
    final safeBaseHeight = math.max(baseSize.height, 1.0);
    final braceFontSize = baseFontSize * (braceSpanHeight / safeBaseHeight);
    final braceSize = _textPainter.measureText(
      _grandStaffBraceGlyph,
      fontSize: braceFontSize,
      fontWeight: FontWeight.w400,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
      maxWidth: braceFontSize * 1.2,
    );
    final braceRightX = metrics.staffLeftInset - metrics.staffSpace * 0.22;
    final braceX = math.max(0.0, braceRightX - braceSize.width);
    final braceCenterY = (trebleTop + bassTop + metrics.staffHeight) / 2.0;
    final braceY =
        braceCenterY - braceSize.height / 2.0 + metrics.staffSpace * 6.57;
    _textPainter.paintText(
      canvas,
      Offset(braceX, braceY),
      _grandStaffBraceGlyph,
      color: score.colors.notation.clef,
      fontSize: braceFontSize,
      fontWeight: FontWeight.w400,
      maxWidth: braceFontSize * 1.2,
      fontFamily: _bravuraFontFamily,
      height: 1.0,
    );
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
    double opacity = 1.0,
    bool drawTreble = true,
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

      if (drawTreble) {
        _textPainter.paintText(
          canvas,
          Offset(x, trebleY - glyphFontSize * 0.55 + glyphBaselineNudge),
          glyph,
          color: _withOpacity(colors.notation.keySignature, opacity),
          fontSize: glyphFontSize,
          fontWeight: FontWeight.w400,
          maxWidth: glyphFontSize * 1.4,
          fontFamily: _bravuraFontFamily,
          height: 1.0,
        );
      }
      if (drawBass) {
        _textPainter.paintText(
          canvas,
          Offset(x, bassY - glyphFontSize * 0.55 + glyphBaselineNudge),
          glyph,
          color: _withOpacity(colors.notation.keySignature, opacity),
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
    required double rightX,
    required GameColorScheme colors,
    required NotationMetrics metrics,
    required double trebleTop,
    required double bassTop,
    double opacity = 1.0,
    bool drawTreble = true,
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
              math.max(
                metrics.timeSignatureMaxFontSize /
                    metrics.timeSignatureVisualScale,
                metrics.timeSignatureMinFontSize /
                    metrics.timeSignatureVisualScale,
              ),
            )
            .toDouble() *
        metrics.timeSignatureVisualScale;
    final effectiveFontSize = fontSize
        .clamp(
          metrics.timeSignatureMinFontSize,
          math.max(
            metrics.timeSignatureMaxFontSize,
            metrics.timeSignatureMinFontSize,
          ),
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

    final blockRightX = rightX;
    final centerX = blockRightX - blockWidth / 2;
    final topX = centerX - topWidth / 2;
    final bottomX = centerX - bottomWidth / 2;
    final trebleTopCenterY = _yForStaffStep(
      36,
      isTreble: true,
      staffTop: trebleTop,
      spacing: metrics.staffSpace,
    );
    final trebleBottomCenterY = _yForStaffStep(
      32,
      isTreble: true,
      staffTop: trebleTop,
      spacing: metrics.staffSpace,
    );
    final trebleTopY = trebleTopCenterY - topHeight / 2;
    final trebleBottomY = trebleBottomCenterY - bottomHeight / 2;

    if (drawTreble) {
      _textPainter.paintText(
        canvas,
        Offset(topX, trebleTopY),
        topText,
        color: _withOpacity(colors.notation.timeSignature, opacity),
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
        color: _withOpacity(colors.notation.timeSignature, opacity),
        fontSize: effectiveFontSize,
        fontWeight: FontWeight.w400,
        maxWidth: blockWidth + metrics.timeSignatureMaxWidthPadding,
        fontFamily: _bravuraFontFamily,
        height: 1.0,
      );
    }

    if (!drawBass) {
      return blockRightX;
    }

    final bassTopCenterY = _yForStaffStep(
      24,
      isTreble: false,
      staffTop: bassTop,
      spacing: metrics.staffSpace,
    );
    final bassBottomCenterY = _yForStaffStep(
      20,
      isTreble: false,
      staffTop: bassTop,
      spacing: metrics.staffSpace,
    );
    final bassTopY = bassTopCenterY - topHeight / 2;
    final bassBottomY = bassBottomCenterY - bottomHeight / 2;
    _textPainter.paintText(
      canvas,
      Offset(topX, bassTopY),
      topText,
      color: _withOpacity(colors.notation.timeSignature, opacity),
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
      color: _withOpacity(colors.notation.timeSignature, opacity),
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

class _KeySignatureTransition {
  const _KeySignatureTransition({
    required this.fromFifths,
    required this.toFifths,
    required this.fromOpacity,
    required this.toOpacity,
    required this.timeSignatureOpacity,
  });

  final int fromFifths;
  final int toFifths;
  final double fromOpacity;
  final double toOpacity;
  final double timeSignatureOpacity;
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
