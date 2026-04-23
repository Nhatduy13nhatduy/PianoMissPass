import 'package:equatable/equatable.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

enum GameAudioStaffMode { off, upperOnly, lowerOnly, both }

enum GameVisibleStaffMode { upperOnly, lowerOnly, both }

enum GameInputMode { wiredMidi, bluetoothMidi, microphone }

class GameMicrophoneCalibration extends Equatable {
  const GameMicrophoneCalibration({
    this.noteThreshold = 0.16,
    this.onsetThreshold = 0.06,
    this.rmsGate = 0.004,
    this.activationFrames = 2,
    this.releaseFrames = 2,
    this.latencyMs = 70,
  });

  final double noteThreshold;
  final double onsetThreshold;
  final double rmsGate;
  final int activationFrames;
  final int releaseFrames;
  final int latencyMs;

  GameMicrophoneCalibration copyWith({
    double? noteThreshold,
    double? onsetThreshold,
    double? rmsGate,
    int? activationFrames,
    int? releaseFrames,
    int? latencyMs,
  }) {
    return GameMicrophoneCalibration(
      noteThreshold: noteThreshold ?? this.noteThreshold,
      onsetThreshold: onsetThreshold ?? this.onsetThreshold,
      rmsGate: rmsGate ?? this.rmsGate,
      activationFrames: activationFrames ?? this.activationFrames,
      releaseFrames: releaseFrames ?? this.releaseFrames,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  @override
  List<Object?> get props => [
    noteThreshold,
    onsetThreshold,
    rmsGate,
    activationFrames,
    releaseFrames,
    latencyMs,
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
    this.isSoundfontReady = false,
    this.isMicrophoneActive = false,
    this.inputDeviceName,
    this.inputDetectorLabel,
    this.recentDetectedNoteLabels = const <String>[],
    this.recentExpectedNoteLabels = const <String>[],
    this.recentDetectedConfidenceLabels = const <String>[],
    this.inputSignalLevel = 0,
    this.inputNoiseFloor = 0,
    this.microphoneCalibration = const GameMicrophoneCalibration(),
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
  final String? inputDetectorLabel;
  final List<String> recentDetectedNoteLabels;
  final List<String> recentExpectedNoteLabels;
  final List<String> recentDetectedConfidenceLabels;
  final double inputSignalLevel;
  final double inputNoiseFloor;
  final GameMicrophoneCalibration microphoneCalibration;
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
    String? inputDetectorLabel,
    bool clearInputDetectorLabel = false,
    List<String>? recentDetectedNoteLabels,
    List<String>? recentExpectedNoteLabels,
    List<String>? recentDetectedConfidenceLabels,
    double? inputSignalLevel,
    double? inputNoiseFloor,
    GameMicrophoneCalibration? microphoneCalibration,
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
      inputDetectorLabel: clearInputDetectorLabel
          ? null
          : inputDetectorLabel ?? this.inputDetectorLabel,
      recentDetectedNoteLabels:
          recentDetectedNoteLabels ?? this.recentDetectedNoteLabels,
      recentExpectedNoteLabels:
          recentExpectedNoteLabels ?? this.recentExpectedNoteLabels,
      recentDetectedConfidenceLabels:
          recentDetectedConfidenceLabels ?? this.recentDetectedConfidenceLabels,
      inputSignalLevel: inputSignalLevel ?? this.inputSignalLevel,
      inputNoiseFloor: inputNoiseFloor ?? this.inputNoiseFloor,
      microphoneCalibration:
          microphoneCalibration ?? this.microphoneCalibration,
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
    inputDetectorLabel,
    recentDetectedNoteLabels,
    recentExpectedNoteLabels,
    recentDetectedConfidenceLabels,
    inputSignalLevel,
    inputNoiseFloor,
    microphoneCalibration,
    playbackSpeed,
    timelineMsPerDurationDivision,
    passedNoteIndexes,
    missedNoteIndexes,
  ];
}
