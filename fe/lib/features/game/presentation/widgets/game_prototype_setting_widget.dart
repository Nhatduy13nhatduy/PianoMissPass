import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../domain/note_timing.dart';
import '../../domain/staff_background.dart';
import '../cubit/game_prototype_cubit.dart';
import '../cubit/game_prototype_state.dart';
import '../provider/game_prototype_provider.dart';

class GamePrototypeSettingWidget extends StatelessWidget {
  const GamePrototypeSettingWidget({
    super.key,
    required this.state,
    required this.songTitle,
    required this.hasCompletedSong,
    required this.completionScore,
    required this.onRepeat,
    required this.onBack,
    required this.onPlay,
  });

  final GamePrototypeState state;
  final String? songTitle;
  final bool hasCompletedSong;
  final int completionScore;
  final VoidCallback onRepeat;
  final VoidCallback onBack;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GamePrototypeSettingsProvider>();
    final cubit = context.read<GamePrototypeCubit>();

    return _GameSettingsOverlay(
      songTitle: songTitle,
      hasCompletedSong: hasCompletedSong,
      completionScore: completionScore,
      selectedTab: settings.selectedSettingsTab,
      onSelectTab: settings.selectSettingsTab,
      gameplayControls: _GameLayoutControls(
        useCard: false,
        showKeyboard: settings.showKeyboard,
        staffHeightScale: settings.staffHeightScale,
        inputMode: state.inputMode,
        audioStaffMode: state.audioStaffMode,
        visibleStaffMode: state.visibleStaffMode,
        isSoundfontReady: state.isSoundfontReady,
        isMicrophoneActive: state.isMicrophoneActive,
        inputDeviceName: state.inputDeviceName,
        playbackSpeed: state.playbackSpeed,
        timelineMsPerDurationDivision: state.timelineMsPerDurationDivision,
        onToggleKeyboard: settings.setShowKeyboard,
        onSelectInputMode: cubit.setInputMode,
        onSelectAudioStaffMode: cubit.setAudioStaffMode,
        onSelectVisibleStaffMode: cubit.setVisibleStaffMode,
        onDecreaseScale: settings.decreaseStaffHeightScale,
        onIncreaseScale: settings.increaseStaffHeightScale,
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
        noteColor: settings.noteColor,
        staffStrokeColor: settings.staffStrokeColor,
        notationGlyphColor: settings.notationGlyphColor,
        keyboardBlackColor: settings.keyboardBlackColor,
        keyboardWhiteColor: settings.keyboardWhiteColor,
        keyboardActiveColor: settings.keyboardActiveColor,
        neutralGlyphColor: settings.neutralGlyphColor,
        passAccentColor: settings.passAccentColor,
        missAccentColor: settings.missAccentColor,
        staffBackground: settings.staffBackground,
        staffBackgroundColor: settings.staffBackgroundColor,
        noteColorOptions: GamePrototypeSettingsProvider.noteColorOptions,
        staffStrokeOptions: GamePrototypeSettingsProvider.staffStrokeOptions,
        notationGlyphOptions:
            GamePrototypeSettingsProvider.notationGlyphOptions,
        keyboardBlackOptions:
            GamePrototypeSettingsProvider.keyboardBlackOptions,
        keyboardWhiteOptions:
            GamePrototypeSettingsProvider.keyboardWhiteOptions,
        keyboardActiveOptions:
            GamePrototypeSettingsProvider.keyboardActiveOptions,
        neutralGlyphOptions:
            GamePrototypeSettingsProvider.neutralGlyphOptions,
        passAccentOptions: GamePrototypeSettingsProvider.passAccentOptions,
        missAccentOptions: GamePrototypeSettingsProvider.missAccentOptions,
        backgroundOptions: settings.backgroundPresets,
        staffBackgroundColorOptions:
            GamePrototypeSettingsProvider.staffBackgroundColorOptions,
        onNoteColorChanged: settings.setNoteColor,
        onStaffStrokeColorChanged: settings.setStaffStrokeColor,
        onNotationGlyphColorChanged: settings.setNotationGlyphColor,
        onKeyboardBlackColorChanged: settings.setKeyboardBlackColor,
        onKeyboardWhiteColorChanged: settings.setKeyboardWhiteColor,
        onKeyboardActiveColorChanged: settings.setKeyboardActiveColor,
        onNeutralGlyphColorChanged: settings.setNeutralGlyphColor,
        onPassAccentColorChanged: settings.setPassAccentColor,
        onMissAccentColorChanged: settings.setMissAccentColor,
        onStaffBackgroundColorChanged: settings.setStaffBackgroundColor,
        onStaffBackgroundChanged: settings.setStaffBackground,
      ),
      onRepeat: onRepeat,
      onBack: onBack,
      onPlay: onPlay,
    );
  }
}

class _GameLayoutControls extends StatelessWidget {
  const _GameLayoutControls({
    this.useCard = true,
    required this.showKeyboard,
    required this.staffHeightScale,
    required this.inputMode,
    required this.audioStaffMode,
    required this.visibleStaffMode,
    required this.isSoundfontReady,
    required this.isMicrophoneActive,
    required this.inputDeviceName,
    required this.playbackSpeed,
    required this.timelineMsPerDurationDivision,
    required this.onToggleKeyboard,
    required this.onSelectInputMode,
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
  final GameInputMode inputMode;
  final GameAudioStaffMode audioStaffMode;
  final GameVisibleStaffMode visibleStaffMode;
  final bool isSoundfontReady;
  final bool isMicrophoneActive;
  final String? inputDeviceName;
  final double playbackSpeed;
  final int timelineMsPerDurationDivision;
  final ValueChanged<bool> onToggleKeyboard;
  final ValueChanged<GameInputMode> onSelectInputMode;
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
    const helperStyle = TextStyle(
      color: Color(0xB3FFFFFF),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final timelineMultiplier =
        NoteTiming.timelineMultiplierFromMsPerDurationDivision(
          timelineMsPerDurationDivision,
        );
    final inputStatusText = switch (inputMode) {
      GameInputMode.microphone =>
        isMicrophoneActive
            ? 'Microphone ready for note detection.'
            : (inputDeviceName?.trim().isNotEmpty == true
                  ? inputDeviceName!.trim()
                  : 'Microphone has not started yet.'),
      GameInputMode.bluetoothMidi =>
        inputDeviceName?.trim().isNotEmpty == true
            ? 'Bluetooth MIDI: ${inputDeviceName!.trim()}'
            : 'No Bluetooth MIDI device connected.',
      GameInputMode.wiredMidi =>
        inputDeviceName?.trim().isNotEmpty == true
            ? 'Wired MIDI: ${inputDeviceName!.trim()}'
            : 'No wired MIDI device connected.',
    };

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
          _ModeRow<GameInputMode>(
            label: 'Input',
            selected: inputMode,
            onSelected: onSelectInputMode,
            options: const [
              (GameInputMode.wiredMidi, 'Wired MIDI'),
              (GameInputMode.bluetoothMidi, 'Bluetooth MIDI'),
              (GameInputMode.microphone, 'Micro'),
            ],
          ),
          const SizedBox(height: 6),
          Text(inputStatusText, style: helperStyle, textAlign: TextAlign.right),
          if (inputMode == GameInputMode.microphone &&
              audioStaffMode != GameAudioStaffMode.off) ...[
            const SizedBox(height: 4),
            const Text(
              'Audio staff is muted while using Micro mode to avoid self-trigger.',
              style: TextStyle(
                color: Color(0xFFE7C56B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ],
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
              _MiniIconButton(icon: Icons.remove_rounded, onTap: onDecreaseScale),
              const SizedBox(width: 8),
              Text('${staffHeightScale.toStringAsFixed(1)}x', style: labelStyle),
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
              _MiniIconButton(icon: Icons.remove_rounded, onTap: onDecreaseSpeed),
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
    required this.completionScore,
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
  final int completionScore;
  final GamePrototypeSettingsTab selectedTab;
  final ValueChanged<GamePrototypeSettingsTab> onSelectTab;
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final settingsPanelHeight = math.max(
              260.0,
              constraints.maxHeight - (hasCompletedSong ? 290.0 : 250.0),
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                  if (hasCompletedSong) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Score: $completionScore',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: settingsPanelHeight,
                    child: DecoratedBox(
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
                            GamePrototypeSettingsTabBar(
                              selectedTab: selectedTab,
                              onSelectTab: onSelectTab,
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: SingleChildScrollView(
                                key: ValueKey(selectedTab),
                                child: selectedTab ==
                                        GamePrototypeSettingsTab.gameplay
                                    ? gameplayControls
                                    : colorControls,
                              ),
                            ),
                          ],
                        ),
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
            );
          },
        ),
      ),
    );
  }
}

class GamePrototypeSettingsTabBar extends StatelessWidget {
  const GamePrototypeSettingsTabBar({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
  });

  final GamePrototypeSettingsTab selectedTab;
  final ValueChanged<GamePrototypeSettingsTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GamePrototypeSettingsTabButton(
            label: 'Gameplay',
            selected: selectedTab == GamePrototypeSettingsTab.gameplay,
            onTap: () => onSelectTab(GamePrototypeSettingsTab.gameplay),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GamePrototypeSettingsTabButton(
            label: 'Color',
            selected: selectedTab == GamePrototypeSettingsTab.color,
            onTap: () => onSelectTab(GamePrototypeSettingsTab.color),
          ),
        ),
      ],
    );
  }
}

class GamePrototypeSettingsTabButton extends StatelessWidget {
  const GamePrototypeSettingsTabButton({
    super.key,
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
    required this.staffBackground,
    required this.staffBackgroundColor,
    required this.noteColorOptions,
    required this.staffStrokeOptions,
    required this.notationGlyphOptions,
    required this.keyboardBlackOptions,
    required this.keyboardWhiteOptions,
    required this.keyboardActiveOptions,
    required this.neutralGlyphOptions,
    required this.passAccentOptions,
    required this.missAccentOptions,
    required this.backgroundOptions,
    required this.staffBackgroundColorOptions,
    required this.onNoteColorChanged,
    required this.onStaffStrokeColorChanged,
    required this.onNotationGlyphColorChanged,
    required this.onKeyboardBlackColorChanged,
    required this.onKeyboardWhiteColorChanged,
    required this.onKeyboardActiveColorChanged,
    required this.onNeutralGlyphColorChanged,
    required this.onPassAccentColorChanged,
    required this.onMissAccentColorChanged,
    required this.onStaffBackgroundColorChanged,
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
  final GameStaffBackground staffBackground;
  final Color? staffBackgroundColor;
  final List<Color> noteColorOptions;
  final List<Color> staffStrokeOptions;
  final List<Color> notationGlyphOptions;
  final List<Color> keyboardBlackOptions;
  final List<Color> keyboardWhiteOptions;
  final List<Color> keyboardActiveOptions;
  final List<Color> neutralGlyphOptions;
  final List<Color> passAccentOptions;
  final List<Color> missAccentOptions;
  final List<GameStaffBackground> backgroundOptions;
  final List<(String, Color?)> staffBackgroundColorOptions;
  final ValueChanged<Color> onNoteColorChanged;
  final ValueChanged<Color> onStaffStrokeColorChanged;
  final ValueChanged<Color> onNotationGlyphColorChanged;
  final ValueChanged<Color> onKeyboardBlackColorChanged;
  final ValueChanged<Color> onKeyboardWhiteColorChanged;
  final ValueChanged<Color> onKeyboardActiveColorChanged;
  final ValueChanged<Color> onNeutralGlyphColorChanged;
  final ValueChanged<Color> onPassAccentColorChanged;
  final ValueChanged<Color> onMissAccentColorChanged;
  final ValueChanged<Color?> onStaffBackgroundColorChanged;
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
        _NullableColorOptionRow(
          label: 'Staff background color',
          selected: staffBackgroundColor,
          options: staffBackgroundColorOptions,
          onSelected: onStaffBackgroundColorChanged,
        ),
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

class _NullableColorOptionRow extends StatelessWidget {
  const _NullableColorOptionRow({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final Color? selected;
  final List<(String, Color?)> options;
  final ValueChanged<Color?> onSelected;

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
                _NullableColorSwatchButton(
                  color: option.$2,
                  label: option.$1,
                  selected: _sameOptionalColor(option.$2, selected),
                  onTap: () => onSelected(option.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _sameOptionalColor(Color? a, Color? b) {
    return a?.value == b?.value && ((a == null) == (b == null));
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

class _NullableColorSwatchButton extends StatelessWidget {
  const _NullableColorSwatchButton({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.white : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: label,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color ?? const Color(0x0FFFFFFF),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: selected ? 3 : 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: color == null
              ? CustomPaint(painter: _TransparentSwatchPainter())
              : null,
        ),
      ),
    );
  }
}

class _TransparentSwatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xD0FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawLine(
      Offset(size.width * 0.24, size.height * 0.76),
      Offset(size.width * 0.76, size.height * 0.24),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final GameStaffBackground selected;
  final List<GameStaffBackground> options;
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
              final isSelected = _sameBackground(selected, option);
              return _BackgroundOptionCard(
                background: option,
                selected: isSelected,
                onTap: () => onSelected(option),
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
    required this.background,
    required this.selected,
    required this.onTap,
  });

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
      child: Ink(width: 116, decoration: decoration),
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
