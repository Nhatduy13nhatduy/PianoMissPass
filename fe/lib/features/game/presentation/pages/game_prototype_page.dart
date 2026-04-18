import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
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
  bool _showKeyboard = true;
  double _staffHeightScale = 1.0;

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
    return PopScope(
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
              previous.audioStaffMode != current.audioStaffMode ||
              previous.visibleStaffMode != current.visibleStaffMode ||
              previous.isSoundfontReady != current.isSoundfontReady ||
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

            return Stack(
              children: [
                CustomPaint(
                  painter: _StaffScrollerPainter(
                    score: score,
                    elapsedMsListenable: cubit.elapsedMsListenable,
                    passedNoteIndexesListenable:
                        cubit.passedNoteIndexesListenable,
                    missedNoteIndexesListenable:
                        cubit.missedNoteIndexesListenable,
                    showKeyboard: _showKeyboard,
                    staffHeightScale: _staffHeightScale,
                    visibleStaffMode: state.visibleStaffMode,
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
                        color: score.colors.progress.line,
                      );
                    },
                  ),
                ),
                if (!state.isPlaying)
                  Positioned.fill(
                    child: _GameSettingsOverlay(
                      songTitle: cubit.songTitle,
                      controls: _GameLayoutControls(
                        useCard: false,
                        showKeyboard: _showKeyboard,
                        staffHeightScale: _staffHeightScale,
                        audioStaffMode: state.audioStaffMode,
                        visibleStaffMode: state.visibleStaffMode,
                        isSoundfontReady: state.isSoundfontReady,
                        playbackSpeed: state.playbackSpeed,
                        timelineMsPerDurationDivision:
                            state.timelineMsPerDurationDivision,
                        onToggleKeyboard: (value) {
                          setState(() {
                            _showKeyboard = value;
                          });
                        },
                        onSelectAudioStaffMode: cubit.setAudioStaffMode,
                        onSelectVisibleStaffMode: cubit.setVisibleStaffMode,
                        onDecreaseScale: () {
                          setState(() {
                            _staffHeightScale = (_staffHeightScale - 0.1).clamp(
                              0.5,
                              2.0,
                            );
                          });
                        },
                        onIncreaseScale: () {
                          setState(() {
                            _staffHeightScale = (_staffHeightScale + 0.1).clamp(
                              0.5,
                              2.0,
                            );
                          });
                        },
                        onDecreaseSpeed: () {
                          cubit.setPlaybackSpeed(state.playbackSpeed - 0.1);
                        },
                        onIncreaseSpeed: () {
                          cubit.setPlaybackSpeed(state.playbackSpeed + 0.1);
                        },
                        onDecreaseTimeline: () {
                          cubit.setTimelineMsPerDurationDivision(
                            state.timelineMsPerDurationDivision -
                                NoteTiming.timelineMsPerDurationDivisionStep,
                          );
                        },
                        onIncreaseTimeline: () {
                          cubit.setTimelineMsPerDurationDivision(
                            state.timelineMsPerDurationDivision +
                                NoteTiming.timelineMsPerDurationDivisionStep,
                          );
                        },
                      ),
                      onPlay: cubit.play,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameLayoutControls extends StatelessWidget {
  const _GameLayoutControls({
    this.useCard = true,
    required this.showKeyboard,
    required this.staffHeightScale,
    required this.audioStaffMode,
    required this.visibleStaffMode,
    required this.isSoundfontReady,
    required this.playbackSpeed,
    required this.timelineMsPerDurationDivision,
    required this.onToggleKeyboard,
    required this.onSelectAudioStaffMode,
    required this.onSelectVisibleStaffMode,
    required this.onDecreaseScale,
    required this.onIncreaseScale,
    required this.onDecreaseSpeed,
    required this.onIncreaseSpeed,
    required this.onDecreaseTimeline,
    required this.onIncreaseTimeline,
  });

  final bool useCard;
  final bool showKeyboard;
  final double staffHeightScale;
  final GameAudioStaffMode audioStaffMode;
  final GameVisibleStaffMode visibleStaffMode;
  final bool isSoundfontReady;
  final double playbackSpeed;
  final int timelineMsPerDurationDivision;
  final ValueChanged<bool> onToggleKeyboard;
  final ValueChanged<GameAudioStaffMode> onSelectAudioStaffMode;
  final ValueChanged<GameVisibleStaffMode> onSelectVisibleStaffMode;
  final VoidCallback onDecreaseScale;
  final VoidCallback onIncreaseScale;
  final VoidCallback onDecreaseSpeed;
  final VoidCallback onIncreaseSpeed;
  final VoidCallback onDecreaseTimeline;
  final VoidCallback onIncreaseTimeline;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Keyboard', style: labelStyle),
              const SizedBox(width: 8),
              Switch(
                value: showKeyboard,
                onChanged: onToggleKeyboard,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ModeRow<GameAudioStaffMode>(
            label: 'Audio staff',
            selected: audioStaffMode,
            onSelected: onSelectAudioStaffMode,
            options: const [
              (GameAudioStaffMode.off, 'Off'),
              (GameAudioStaffMode.upperOnly, 'Staff 1'),
              (GameAudioStaffMode.lowerOnly, 'Staff 2'),
              (GameAudioStaffMode.both, 'Both'),
            ],
          ),
          const SizedBox(height: 6),
          _ModeRow<GameVisibleStaffMode>(
            label: 'Show staff',
            selected: visibleStaffMode,
            onSelected: onSelectVisibleStaffMode,
            options: const [
              (GameVisibleStaffMode.upperOnly, 'Staff 1'),
              (GameVisibleStaffMode.lowerOnly, 'Staff 2'),
              (GameVisibleStaffMode.both, 'Both'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Staff', style: labelStyle),
              const SizedBox(width: 10),
              _MiniIconButton(
                icon: Icons.remove_rounded,
                onTap: onDecreaseScale,
              ),
              const SizedBox(width: 8),
              Text(
                '${staffHeightScale.toStringAsFixed(1)}x',
                style: labelStyle,
              ),
              const SizedBox(width: 8),
              _MiniIconButton(icon: Icons.add_rounded, onTap: onIncreaseScale),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Speed', style: labelStyle),
              const SizedBox(width: 10),
              _MiniIconButton(
                icon: Icons.remove_rounded,
                onTap: onDecreaseSpeed,
              ),
              const SizedBox(width: 8),
              Text('${playbackSpeed.toStringAsFixed(1)}x', style: labelStyle),
              const SizedBox(width: 8),
              _MiniIconButton(icon: Icons.add_rounded, onTap: onIncreaseSpeed),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Timeline', style: labelStyle),
              const SizedBox(width: 10),
              _MiniIconButton(
                icon: Icons.remove_rounded,
                onTap: onDecreaseTimeline,
              ),
              const SizedBox(width: 8),
              Text('$timelineMsPerDurationDivision', style: labelStyle),
              const SizedBox(width: 8),
              _MiniIconButton(
                icon: Icons.add_rounded,
                onTap: onIncreaseTimeline,
              ),
            ],
          ),
        ],
      ),
    );

    if (!useCard) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC0E1620),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

class _GameSettingsOverlay extends StatelessWidget {
  const _GameSettingsOverlay({
    required this.controls,
    required this.onPlay,
    this.songTitle,
  });

  final Widget controls;
  final VoidCallback onPlay;
  final String? songTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF0B1118),
      child: SafeArea(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    songTitle?.trim().isNotEmpty == true
                        ? songTitle!.trim()
                        : 'Game Settings',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Chinh cau hinh truoc khi choi, hoac tiep tuc tu vi tri da pause.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xD9FFFFFF),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101923),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: controls,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFF2B7FFF),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF1C2735),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _ModeRow<T> extends StatelessWidget {
  const _ModeRow({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.options,
    this.enabled = true,
  });

  final String label;
  final T selected;
  final ValueChanged<T> onSelected;
  final List<(T value, String label)> options;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.$2),
                selected: selected == option.$1,
                onSelected: enabled ? (_) => onSelected(option.$1) : null,
                selectedColor: const Color(0xFF284B63),
                backgroundColor: const Color(0xFF1C2735),
                disabledColor: const Color(0xFF1C2735),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
              ),
          ],
        ),
      ],
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
    required this.passedNoteIndexesListenable,
    required this.missedNoteIndexesListenable,
    required this.showKeyboard,
    required this.staffHeightScale,
    required this.visibleStaffMode,
    required this.timelineMsPerDurationDivision,
  }) : super(
         repaint: Listenable.merge([
           elapsedMsListenable,
           passedNoteIndexesListenable,
           missedNoteIndexesListenable,
         ]),
       );

  final ScoreData score;
  final ValueListenable<int> elapsedMsListenable;
  final ValueListenable<Set<int>> passedNoteIndexesListenable;
  final ValueListenable<Set<int>> missedNoteIndexesListenable;
  final bool showKeyboard;
  final double staffHeightScale;
  final GameVisibleStaffMode visibleStaffMode;
  final int timelineMsPerDurationDivision;

  final GameStaffPainter _staffPainter = GameStaffPainter();
  final GameTextPainter _textPainter = GameTextPainter();
  final GameNotePainter _notePainter = GameNotePainter();
  final GameKeyboardPainter _keyboardPainter = GameKeyboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = elapsedMsListenable.value;
    final passedNoteIndexes = passedNoteIndexesListenable.value;
    final missedNoteIndexes = missedNoteIndexesListenable.value;
    final visuals = _getPrecomputedScoreVisuals(score);
    final baseMetrics = NotationMetrics.fromCanvasSize(size);
    final notePxPerMs = NoteTiming.notePxPerMsForScore(
      score,
      timelineMsPerDurationDivision: timelineMsPerDurationDivision,
    );
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
    final beatMs = 60000.0 / score.bpm;
    final measureMs = score.beatsPerMeasure * beatMs;
    final leftInvisibleMeasurePx = measureMs * notePxPerMs;
    final staffHeight = metrics.staffHeight;
    final staffGap = metrics.staffGap;
    final keyboardTop = size.height - keyboardHeight;
    final singleStaffTop = (staffRegionHeight - staffHeight) / 2.0;
    final showUpperStaff = visibleStaffMode != GameVisibleStaffMode.lowerOnly;
    final showLowerStaff = visibleStaffMode != GameVisibleStaffMode.upperOnly;
    final trebleTop = visibleStaffMode == GameVisibleStaffMode.both
        ? metrics.topPadding
        : singleStaffTop;
    final bassTop = visibleStaffMode == GameVisibleStaffMode.both
        ? trebleTop + staffHeight + staffGap
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

    final trebleMainClefX = metrics.trebleMainClefX;
    final bassMainClefX = metrics.bassMainClefX;
    final trebleClefY = trebleTop + metrics.clefBaselineOffsetY;
    final bassClefY = bassTop + metrics.clefBaselineOffsetY;

    final playheadX = metrics.fixedPlayheadX;
    final activeKeyFifths = _activeKeyFifths(score, currentMs);
    _paintKeySignature(
      canvas,
      fifths: activeKeyFifths,
      colors: score.colors,
      metrics: metrics,
      trebleTop: trebleTop,
      bassTop: bassTop,
      drawTreble: showUpperStaff,
      drawBass: showLowerStaff && !_debugHideLowerStaff,
    );
    if (!_shouldHideTimeSignatureForKeyFifths(activeKeyFifths)) {
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
      );
    }

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
      notePxPerMs: notePxPerMs,
    );
    final trebleMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[1] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: trebleMainClefX,
      notePxPerMs: notePxPerMs,
    );
    final bassActiveClef = _mainClefSignForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
      fallback: 'F',
      playheadX: playheadX,
      metrics: metrics,
      mainClefX: bassMainClefX,
      notePxPerMs: notePxPerMs,
    );
    final bassMainClefOpacity = _mainClefOpacityForStaffAtAnchor(
      visuals.clefEventsByStaff[2] ?? const <_ClefSymbolEvent>[],
      currentMs: currentMs,
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
      final x = playheadX + (symbol.timeMs - currentMs) * notePxPerMs;

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
                currentMs: currentMs,
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
      visibleStaffMode: visibleStaffMode,
      metrics: metrics,
      notePxPerMs: notePxPerMs,
    );

    canvas.drawLine(
      Offset(playheadX, playheadTopY),
      Offset(playheadX, stavesBottomY),
      symbolPaint,
    );

    if (showKeyboard) {
      _keyboardPainter.paintKeyboard(
        canvas,
        size,
        score: score,
        currentMs: currentMs,
        keyboardTop: keyboardTop,
        metrics: metrics,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffScrollerPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.elapsedMsListenable != elapsedMsListenable ||
        oldDelegate.passedNoteIndexesListenable !=
            passedNoteIndexesListenable ||
        oldDelegate.missedNoteIndexesListenable !=
            missedNoteIndexesListenable ||
        oldDelegate.showKeyboard != showKeyboard ||
        oldDelegate.staffHeightScale != staffHeightScale ||
        oldDelegate.visibleStaffMode != visibleStaffMode ||
        oldDelegate.timelineMsPerDurationDivision !=
            timelineMsPerDurationDivision;
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

  bool _shouldHideTimeSignatureForKeyFifths(int fifths) {
    return fifths.abs() >= 5;
  }

  _PrecomputedScoreVisuals _getPrecomputedScoreVisuals(ScoreData score) {
    final cached = _scoreVisualsCache[score];
    if (cached != null) {
      return cached;
    }

    final measureStartTimes = <int>[];
    final timedSymbols = <_PreparedTimedSymbol>[];
    final clefEventsByStaff = <int, List<_ClefSymbolEvent>>{};
    int? lastBarlineMeasureIndex;

    for (final symbol in score.symbols) {
      final label = symbol.label;
      if (label == '|') {
        if (symbol.measureIndex != null &&
            symbol.measureIndex == lastBarlineMeasureIndex) {
          continue;
        }
        lastBarlineMeasureIndex = symbol.measureIndex;
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
      'whole' => (lineSpacing * 1.7).clamp(14.0 * scale, 26.0 * scale),
      'half' => (lineSpacing * 1.7).clamp(14.0 * scale, 26.0 * scale),
      'quarter' => (lineSpacing * 2.3).clamp(18.0 * scale, 36.0 * scale),
      '8th' => (lineSpacing * 2.55).clamp(20.0 * scale, 40.0 * scale),
      '16th' => (lineSpacing * 2.8).clamp(22.0 * scale, 43.0 * scale),
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
          color: colors.notation.keySignature,
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
    required double rightX,
    required GameColorScheme colors,
    required NotationMetrics metrics,
    required double trebleTop,
    required double bassTop,
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
