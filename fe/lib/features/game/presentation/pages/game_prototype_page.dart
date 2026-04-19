import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  _SettingsTab _selectedSettingsTab = _SettingsTab.gameplay;
  GameStaffBackground _staffBackground = _backgroundPresets.first.$2;
  Color _noteColor = _defaultColors.note.idle;
  Color _staffStrokeColor = _defaultColors.staff.border;
  Color _notationGlyphColor = _defaultColors.notation.clef;
  Color _keyboardBlackColor = _defaultColors.keyboard.black;
  Color _keyboardWhiteColor = _defaultColors.keyboard.white;
  Color _keyboardActiveColor = _defaultColors.keyboard.active;
  Color _neutralGlyphColor = _defaultColors.rest.glyph;
  Color _passAccentColor = _defaultColors.note.pass;
  Color _missAccentColor = _defaultColors.note.miss;
  Color _judgeLineColor = _defaultColors.staff.judgeLine;

  static const GameColorScheme _defaultColors = GameColorScheme.classic;
  static const List<(String, GameStaffBackground)> _backgroundPresets = [
    (
      'White',
      GameStaffBackground.color(Color(0xE6F4F4F4)),
    ),
    (
      'Forest',
      GameStaffBackground.image(
        assetPath:
            'assets/backgrounds/luxury-plain-green-gradient-abstract-studio-background-empty-room-with-space-your-text-picture.jpg',
        fallbackColor: Color(0xFFE5EFE5),
      ),
    ),
    (
      'Paper',
      GameStaffBackground.image(
        assetPath: 'assets/backgrounds/pexels-fwstudio-33348-172295.jpg',
        fallbackColor: Color(0xFFF1E6D6),
      ),
    ),
    (
      'Stone',
      GameStaffBackground.image(
        assetPath: 'assets/backgrounds/pexels-pixabay-235985.jpg',
        fallbackColor: Color(0xFFE8E8E4),
      ),
    ),
    (
      'Soft',
      GameStaffBackground.image(
        assetPath:
            'assets/backgrounds/f8cd0a0d-0f8a-447f-b73c-37e87c224e31.jpg',
        fallbackColor: Color(0xFFE7DFD7),
      ),
    ),
  ];

  static const List<Color> _noteColorOptions = [
    Color(0xFF111111),
    Color(0xFF1C2A3A),
    Color(0xFF2D1E2F),
    Color(0xFF243322),
    Color(0xFF3A2418),
  ];

  static const List<Color> _staffStrokeOptions = [
    Color(0xFF111111),
    Color(0xFF22313F),
    Color(0xFF4A403A),
    Color(0xFF2E3D2F),
    Color(0xFF47312A),
  ];

  static const List<Color> _notationGlyphOptions = [
    Color(0xFF111111),
    Color(0xFF1F2D3A),
    Color(0xFF2F253D),
    Color(0xFF30422C),
    Color(0xFF4C3423),
  ];

  static const List<Color> _keyboardBlackOptions = [
    Color(0xFF1A1A1C),
    Color(0xFF15222D),
    Color(0xFF2A2434),
    Color(0xFF233123),
    Color(0xFF35251E),
  ];

  static const List<Color> _keyboardWhiteOptions = [
    Color(0xFFE7EBF0),
    Color(0xFFF5F1E8),
    Color(0xFFE9F0EA),
    Color(0xFFEDE7F3),
    Color(0xFFF2E7E1),
  ];

  static const List<Color> _keyboardActiveOptions = [
    Color(0xFF8A6DB8),
    Color(0xFF2B7FFF),
    Color(0xFF2E9C6A),
    Color(0xFFE07A2D),
    Color(0xFFC05780),
  ];

  static const List<Color> _neutralGlyphOptions = [
    Color(0xFF222222),
    Color(0xFF34495E),
    Color(0xFF5B4B3A),
    Color(0xFF38553C),
    Color(0xFF5C3B3B),
  ];

  static const List<Color> _passAccentOptions = [
    Color(0xFF1E5D31),
    Color(0xFF2E9C6A),
    Color(0xFF2C7A7B),
    Color(0xFF4D8B31),
    Color(0xFF0F766E),
  ];

  static const List<Color> _missAccentOptions = [
    Color(0xFF98273B),
    Color(0xFFC44536),
    Color(0xFFD97706),
    Color(0xFFB42318),
    Color(0xFF9F1239),
  ];

  static const List<Color> _judgeLineOptions = [
    Color(0xFF0D3750),
    Color(0xFF2B7FFF),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFB45309),
  ];

  GameColorScheme get _effectiveColors {
    return GameColorScheme(
      staff: GameStaffColorScheme(
        background: _staffBackground,
        border: _staffStrokeColor,
        line: _staffStrokeColor,
        measureLine: _staffStrokeColor,
        judgeLine: _judgeLineColor,
      ),
      note: GameNoteColorScheme(
        idle: _noteColor,
        active: _noteColor,
        pass: _passAccentColor,
        miss: _missAccentColor,
      ),
      accidentalAndSlur: GameAccidentalSlurColorScheme(
        accidental: _neutralGlyphColor,
        slurIdle: _neutralGlyphColor,
        slurPass: _passAccentColor,
        slurMiss: _missAccentColor,
      ),
      fingering: GameFingeringColorScheme(text: _neutralGlyphColor),
      rest: GameRestColorScheme(glyph: _neutralGlyphColor),
      notation: GameNotationColorScheme(
        keySignature: _notationGlyphColor,
        clef: _notationGlyphColor,
        timeSignature: _notationGlyphColor,
      ),
      keyboard: GameKeyboardColorScheme(
        white: _keyboardWhiteColor,
        active: _keyboardActiveColor,
        whiteBorder: _keyboardBlackColor,
        black: _keyboardBlackColor,
      ),
      progress: GameProgressColorScheme(line: _judgeLineColor),
    );
  }

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
            final effectiveScore = score.copyWith(colors: _effectiveColors);
            final hasCompletedSong =
                !state.isPlaying &&
                cubit.maxDurationMs > 0 &&
                cubit.currentMs >= cubit.maxDurationMs;

            return Stack(
              children: [
                Positioned.fill(
                  child: _GameScreenBackground(
                    background: _staffBackground,
                  ),
                ),
                CustomPaint(
                  painter: _StaffScrollerPainter(
                    score: effectiveScore,
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
                        color: effectiveScore.colors.progress.line,
                      );
                    },
                  ),
                ),
                if (!state.isPlaying)
                  Positioned.fill(
                    child: _GameSettingsOverlay(
                      songTitle: cubit.songTitle,
                      hasCompletedSong: hasCompletedSong,
                      selectedTab: _selectedSettingsTab,
                      onSelectTab: (tab) {
                        setState(() {
                          _selectedSettingsTab = tab;
                        });
                      },
                      gameplayControls: _GameLayoutControls(
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
                      colorControls: _GameColorControls(
                        noteColor: _noteColor,
                        staffStrokeColor: _staffStrokeColor,
                        notationGlyphColor: _notationGlyphColor,
                        keyboardBlackColor: _keyboardBlackColor,
                        keyboardWhiteColor: _keyboardWhiteColor,
                        keyboardActiveColor: _keyboardActiveColor,
                        neutralGlyphColor: _neutralGlyphColor,
                        passAccentColor: _passAccentColor,
                        missAccentColor: _missAccentColor,
                        judgeLineColor: _judgeLineColor,
                        staffBackground: _staffBackground,
                        noteColorOptions: _noteColorOptions,
                        staffStrokeOptions: _staffStrokeOptions,
                        notationGlyphOptions: _notationGlyphOptions,
                        keyboardBlackOptions: _keyboardBlackOptions,
                        keyboardWhiteOptions: _keyboardWhiteOptions,
                        keyboardActiveOptions: _keyboardActiveOptions,
                        neutralGlyphOptions: _neutralGlyphOptions,
                        passAccentOptions: _passAccentOptions,
                        missAccentOptions: _missAccentOptions,
                        judgeLineOptions: _judgeLineOptions,
                        backgroundOptions: _backgroundPresets,
                        onNoteColorChanged: (value) {
                          setState(() {
                            _noteColor = value;
                          });
                        },
                        onStaffStrokeColorChanged: (value) {
                          setState(() {
                            _staffStrokeColor = value;
                          });
                        },
                        onNotationGlyphColorChanged: (value) {
                          setState(() {
                            _notationGlyphColor = value;
                          });
                        },
                        onKeyboardBlackColorChanged: (value) {
                          setState(() {
                            _keyboardBlackColor = value;
                          });
                        },
                        onKeyboardWhiteColorChanged: (value) {
                          setState(() {
                            _keyboardWhiteColor = value;
                          });
                        },
                        onKeyboardActiveColorChanged: (value) {
                          setState(() {
                            _keyboardActiveColor = value;
                          });
                        },
                        onNeutralGlyphColorChanged: (value) {
                          setState(() {
                            _neutralGlyphColor = value;
                          });
                        },
                        onPassAccentColorChanged: (value) {
                          setState(() {
                            _passAccentColor = value;
                          });
                        },
                        onMissAccentColorChanged: (value) {
                          setState(() {
                            _missAccentColor = value;
                          });
                        },
                        onJudgeLineColorChanged: (value) {
                          setState(() {
                            _judgeLineColor = value;
                          });
                        },
                        onStaffBackgroundChanged: (value) {
                          setState(() {
                            _staffBackground = value;
                          });
                        },
                      ),
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
    );
  }
}

enum _SettingsTab { gameplay, color }

class _GameScreenBackground extends StatelessWidget {
  const _GameScreenBackground({required this.background});

  final GameStaffBackground background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.color ?? background.fallbackColor ?? Colors.transparent,
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
    final timelineMultiplier = NoteTiming
        .timelineMultiplierFromMsPerDurationDivision(
          timelineMsPerDurationDivision,
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
              Text(
                'x${timelineMultiplier.toStringAsFixed(1)}',
                style: labelStyle,
              ),
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
    required this.hasCompletedSong,
    required this.selectedTab,
    required this.onSelectTab,
    required this.gameplayControls,
    required this.colorControls,
    required this.onRepeat,
    required this.onBack,
    required this.onPlay,
    this.songTitle,
  });

  final bool hasCompletedSong;
  final _SettingsTab selectedTab;
  final ValueChanged<_SettingsTab> onSelectTab;
  final Widget gameplayControls;
  final Widget colorControls;
  final VoidCallback onRepeat;
  final VoidCallback onBack;
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
                    hasCompletedSong
                        ? 'Bai nhac da ket thuc. Ban co the repeat, quay lai, hoac dieu chinh cau hinh truoc khi choi tiep.'
                        : 'Chinh cau hinh truoc khi choi, hoac tiep tuc tu vi tri da pause.',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingsTabBar(
                            selectedTab: selectedTab,
                            onSelectTab: onSelectTab,
                          ),
                          const SizedBox(height: 18),
                          if (selectedTab == _SettingsTab.gameplay)
                            gameplayControls
                          else
                            colorControls,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0x40FFFFFF)),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onRepeat,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Repeat'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFF1F8A70),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: hasCompletedSong ? onRepeat : onPlay,
                    icon: Icon(
                      hasCompletedSong
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(hasCompletedSong ? 'Play Again' : 'Play'),
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

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({
    required this.selectedTab,
    required this.onSelectTab,
  });

  final _SettingsTab selectedTab;
  final ValueChanged<_SettingsTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SettingsTabButton(
            label: 'Gameplay',
            selected: selectedTab == _SettingsTab.gameplay,
            onTap: () => onSelectTab(_SettingsTab.gameplay),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SettingsTabButton(
            label: 'Color',
            selected: selectedTab == _SettingsTab.color,
            onTap: () => onSelectTab(_SettingsTab.color),
          ),
        ),
      ],
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF284B63) : const Color(0xFF1C2735),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameColorControls extends StatelessWidget {
  const _GameColorControls({
    required this.noteColor,
    required this.staffStrokeColor,
    required this.notationGlyphColor,
    required this.keyboardBlackColor,
    required this.keyboardWhiteColor,
    required this.keyboardActiveColor,
    required this.neutralGlyphColor,
    required this.passAccentColor,
    required this.missAccentColor,
    required this.judgeLineColor,
    required this.staffBackground,
    required this.noteColorOptions,
    required this.staffStrokeOptions,
    required this.notationGlyphOptions,
    required this.keyboardBlackOptions,
    required this.keyboardWhiteOptions,
    required this.keyboardActiveOptions,
    required this.neutralGlyphOptions,
    required this.passAccentOptions,
    required this.missAccentOptions,
    required this.judgeLineOptions,
    required this.backgroundOptions,
    required this.onNoteColorChanged,
    required this.onStaffStrokeColorChanged,
    required this.onNotationGlyphColorChanged,
    required this.onKeyboardBlackColorChanged,
    required this.onKeyboardWhiteColorChanged,
    required this.onKeyboardActiveColorChanged,
    required this.onNeutralGlyphColorChanged,
    required this.onPassAccentColorChanged,
    required this.onMissAccentColorChanged,
    required this.onJudgeLineColorChanged,
    required this.onStaffBackgroundChanged,
  });

  final Color noteColor;
  final Color staffStrokeColor;
  final Color notationGlyphColor;
  final Color keyboardBlackColor;
  final Color keyboardWhiteColor;
  final Color keyboardActiveColor;
  final Color neutralGlyphColor;
  final Color passAccentColor;
  final Color missAccentColor;
  final Color judgeLineColor;
  final GameStaffBackground staffBackground;
  final List<Color> noteColorOptions;
  final List<Color> staffStrokeOptions;
  final List<Color> notationGlyphOptions;
  final List<Color> keyboardBlackOptions;
  final List<Color> keyboardWhiteOptions;
  final List<Color> keyboardActiveOptions;
  final List<Color> neutralGlyphOptions;
  final List<Color> passAccentOptions;
  final List<Color> missAccentOptions;
  final List<Color> judgeLineOptions;
  final List<(String, GameStaffBackground)> backgroundOptions;
  final ValueChanged<Color> onNoteColorChanged;
  final ValueChanged<Color> onStaffStrokeColorChanged;
  final ValueChanged<Color> onNotationGlyphColorChanged;
  final ValueChanged<Color> onKeyboardBlackColorChanged;
  final ValueChanged<Color> onKeyboardWhiteColorChanged;
  final ValueChanged<Color> onKeyboardActiveColorChanged;
  final ValueChanged<Color> onNeutralGlyphColorChanged;
  final ValueChanged<Color> onPassAccentColorChanged;
  final ValueChanged<Color> onMissAccentColorChanged;
  final ValueChanged<Color> onJudgeLineColorChanged;
  final ValueChanged<GameStaffBackground> onStaffBackgroundChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackgroundPicker(
          selected: staffBackground,
          options: backgroundOptions,
          onSelected: onStaffBackgroundChanged,
        ),
        const SizedBox(height: 14),
        _ColorOptionRow(
          label: 'Note',
          selected: noteColor,
          options: noteColorOptions,
          onSelected: onNoteColorChanged,
        ),
        _ColorOptionRow(
          label: 'Staff stroke',
          selected: staffStrokeColor,
          options: staffStrokeOptions,
          onSelected: onStaffStrokeColorChanged,
        ),
        _ColorOptionRow(
          label: 'Notation glyph',
          selected: notationGlyphColor,
          options: notationGlyphOptions,
          onSelected: onNotationGlyphColorChanged,
        ),
        _ColorOptionRow(
          label: 'Keyboard black',
          selected: keyboardBlackColor,
          options: keyboardBlackOptions,
          onSelected: onKeyboardBlackColorChanged,
        ),
        _ColorOptionRow(
          label: 'Keyboard white',
          selected: keyboardWhiteColor,
          options: keyboardWhiteOptions,
          onSelected: onKeyboardWhiteColorChanged,
        ),
        _ColorOptionRow(
          label: 'Keyboard active',
          selected: keyboardActiveColor,
          options: keyboardActiveOptions,
          onSelected: onKeyboardActiveColorChanged,
        ),
        _ColorOptionRow(
          label: 'Neutral glyph',
          selected: neutralGlyphColor,
          options: neutralGlyphOptions,
          onSelected: onNeutralGlyphColorChanged,
        ),
        _ColorOptionRow(
          label: 'Pass accent',
          selected: passAccentColor,
          options: passAccentOptions,
          onSelected: onPassAccentColorChanged,
        ),
        _ColorOptionRow(
          label: 'Miss accent',
          selected: missAccentColor,
          options: missAccentOptions,
          onSelected: onMissAccentColorChanged,
        ),
        _ColorOptionRow(
          label: 'Judge line',
          selected: judgeLineColor,
          options: judgeLineOptions,
          onSelected: onJudgeLineColorChanged,
        ),
      ],
    );
  }
}

class _ColorOptionRow extends StatelessWidget {
  const _ColorOptionRow({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final Color selected;
  final List<Color> options;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in options)
                _ColorSwatchButton(
                  color: option,
                  selected: option.value == selected.value,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final GameStaffBackground selected;
  final List<(String, GameStaffBackground)> options;
  final ValueChanged<GameStaffBackground> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Background',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _sameBackground(selected, option.$2);
              return _BackgroundOptionCard(
                label: option.$1,
                background: option.$2,
                selected: isSelected,
                onTap: () => onSelected(option.$2),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _sameBackground(GameStaffBackground a, GameStaffBackground b) {
    return a.color?.value == b.color?.value &&
        a.imageAssetPath == b.imageAssetPath &&
        a.fallbackColor?.value == b.fallbackColor?.value;
  }
}

class _BackgroundOptionCard extends StatelessWidget {
  const _BackgroundOptionCard({
    required this.label,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final GameStaffBackground background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: background.color ?? background.fallbackColor ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? Colors.white : Colors.white24,
        width: selected ? 2.4 : 1.0,
      ),
      image: background.imageAssetPath != null
          ? DecorationImage(
              image: AssetImage(background.imageAssetPath!),
              fit: background.imageFit,
              alignment: background.imageAlignment,
            )
          : null,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 116,
        decoration: decoration,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
      'whole' => (lineSpacing * 1.38).clamp(12.0 * scale, 22.0 * scale),
      'half' => (lineSpacing * 1.38).clamp(12.0 * scale, 22.0 * scale),
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
