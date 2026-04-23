import 'package:equatable/equatable.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

enum GameAudioStaffMode { off, upperOnly, lowerOnly, both }

enum GameVisibleStaffMode { upperOnly, lowerOnly, both }

enum GameInputMode { wiredMidi, bluetoothMidi, microphone }

class GamePrototypeState extends Equatable {
  const GamePrototypeState({
    this.isLoading = true,
    this.errorMessage,
    this.score,
    this.isPlaying = false,
    this.inputMode = GameInputMode.wiredMidi,
    this.audioStaffMode = GameAudioStaffMode.both,
    this.visibleStaffMode = GameVisibleStaffMode.both,
    this.isSoundfontReady = false,
    this.isMicrophoneActive = false,
    this.inputDeviceName,
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
  final bool isSoundfontReady;
  final bool isMicrophoneActive;
  final String? inputDeviceName;
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
    bool? isSoundfontReady,
    bool? isMicrophoneActive,
    String? inputDeviceName,
    bool clearInputDeviceName = false,
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
      isSoundfontReady: isSoundfontReady ?? this.isSoundfontReady,
      isMicrophoneActive: isMicrophoneActive ?? this.isMicrophoneActive,
      inputDeviceName: clearInputDeviceName
          ? null
          : inputDeviceName ?? this.inputDeviceName,
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
    isSoundfontReady,
    isMicrophoneActive,
    inputDeviceName,
    playbackSpeed,
    timelineMsPerDurationDivision,
    passedNoteIndexes,
    missedNoteIndexes,
  ];
}
