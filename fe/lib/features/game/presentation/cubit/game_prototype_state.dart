import 'package:equatable/equatable.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

enum GameAudioStaffMode { off, upperOnly, lowerOnly, both }

enum GameVisibleStaffMode { upperOnly, lowerOnly, both }

enum GameInputMode { wiredMidi, bluetoothMidi, microphone }

enum GamePlayMode { scrolling, step }

enum GameNoteJudgeOutcome { pass, miss }

class GameNoteJudgeAnimation extends Equatable {
  const GameNoteJudgeAnimation({
    required this.outcome,
    required this.startMs,
  });

  final GameNoteJudgeOutcome outcome;
  final int startMs;

  @override
  List<Object?> get props => [outcome, startMs];
}

class GameMicrophoneDebugData extends Equatable {
  const GameMicrophoneDebugData({
    required this.rms,
    required this.maxScore,
    required this.expectedMidis,
    required this.detectedMidis,
    required this.scoresByMidi,
  });

  final double rms;
  final double maxScore;
  final Set<int> expectedMidis;
  final Set<int> detectedMidis;
  final Map<int, double> scoresByMidi;

  @override
  List<Object?> get props => [
    rms,
    maxScore,
    expectedMidis,
    detectedMidis,
    scoresByMidi.entries.map((entry) => '${entry.key}:${entry.value}').toList(),
  ];
}

class GamePrototypeState extends Equatable {
  const GamePrototypeState({
    this.isLoading = true,
    this.errorMessage,
    this.score,
    this.isPlaying = false,
    this.inputMode = GameInputMode.wiredMidi,
    this.audioStaffMode = GameAudioStaffMode.both,
    this.visibleStaffMode = GameVisibleStaffMode.both,
    this.gameplayMode = GamePlayMode.scrolling,
    this.isSoundfontReady = false,
    this.isMicrophoneActive = false,
    this.inputDeviceName,
    this.activeInputMidis = const <int>{},
    this.microphoneDebug,
    this.playbackSpeed = NoteTiming.defaultPlaybackSpeed,
    this.timelineMsPerDurationDivision =
        NoteTiming.defaultTimelineMsPerDurationDivision,
    this.passedNoteIndexes = const <int>{},
    this.missedNoteIndexes = const <int>{},
  });

  final bool isLoading;
  final String? errorMessage;
  final ScoreData? score;
  final bool isPlaying;
  final GameInputMode inputMode;
  final GameAudioStaffMode audioStaffMode;
  final GameVisibleStaffMode visibleStaffMode;
  final GamePlayMode gameplayMode;
  final bool isSoundfontReady;
  final bool isMicrophoneActive;
  final String? inputDeviceName;
  final Set<int> activeInputMidis;
  final GameMicrophoneDebugData? microphoneDebug;
  final double playbackSpeed;
  final int timelineMsPerDurationDivision;
  final Set<int> passedNoteIndexes;
  final Set<int> missedNoteIndexes;

  GamePrototypeState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    ScoreData? score,
    bool? isPlaying,
    GameInputMode? inputMode,
    GameAudioStaffMode? audioStaffMode,
    GameVisibleStaffMode? visibleStaffMode,
    GamePlayMode? gameplayMode,
    bool? isSoundfontReady,
    bool? isMicrophoneActive,
    String? inputDeviceName,
    bool clearInputDeviceName = false,
    Set<int>? activeInputMidis,
    GameMicrophoneDebugData? microphoneDebug,
    bool clearMicrophoneDebug = false,
    double? playbackSpeed,
    int? timelineMsPerDurationDivision,
    Set<int>? passedNoteIndexes,
    Set<int>? missedNoteIndexes,
  }) {
    return GamePrototypeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      score: score ?? this.score,
      isPlaying: isPlaying ?? this.isPlaying,
      inputMode: inputMode ?? this.inputMode,
      audioStaffMode: audioStaffMode ?? this.audioStaffMode,
      visibleStaffMode: visibleStaffMode ?? this.visibleStaffMode,
      gameplayMode: gameplayMode ?? this.gameplayMode,
      isSoundfontReady: isSoundfontReady ?? this.isSoundfontReady,
      isMicrophoneActive: isMicrophoneActive ?? this.isMicrophoneActive,
      inputDeviceName: clearInputDeviceName
          ? null
          : inputDeviceName ?? this.inputDeviceName,
      activeInputMidis: activeInputMidis ?? this.activeInputMidis,
      microphoneDebug: clearMicrophoneDebug
          ? null
          : microphoneDebug ?? this.microphoneDebug,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      timelineMsPerDurationDivision:
          timelineMsPerDurationDivision ?? this.timelineMsPerDurationDivision,
      passedNoteIndexes: passedNoteIndexes ?? this.passedNoteIndexes,
      missedNoteIndexes: missedNoteIndexes ?? this.missedNoteIndexes,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    score,
    isPlaying,
    inputMode,
    audioStaffMode,
    visibleStaffMode,
    gameplayMode,
    isSoundfontReady,
    isMicrophoneActive,
    inputDeviceName,
    activeInputMidis,
    microphoneDebug,
    playbackSpeed,
    timelineMsPerDurationDivision,
    passedNoteIndexes,
    missedNoteIndexes,
  ];
}
