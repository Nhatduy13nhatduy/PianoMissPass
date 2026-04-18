import 'package:equatable/equatable.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';

enum GameAudioStaffMode { upperOnly, lowerOnly, both }

enum GameVisibleStaffMode { upperOnly, lowerOnly, both }

class GamePrototypeState extends Equatable {
  const GamePrototypeState({
    this.isLoading = true,
    this.errorMessage,
    this.score,
    this.isPlaying = false,
    this.isSongAudioEnabled = true,
    this.audioStaffMode = GameAudioStaffMode.both,
    this.visibleStaffMode = GameVisibleStaffMode.both,
    this.isSoundfontReady = false,
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
  final bool isSongAudioEnabled;
  final GameAudioStaffMode audioStaffMode;
  final GameVisibleStaffMode visibleStaffMode;
  final bool isSoundfontReady;
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
    bool? isSongAudioEnabled,
    GameAudioStaffMode? audioStaffMode,
    GameVisibleStaffMode? visibleStaffMode,
    bool? isSoundfontReady,
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
      isSongAudioEnabled: isSongAudioEnabled ?? this.isSongAudioEnabled,
      audioStaffMode: audioStaffMode ?? this.audioStaffMode,
      visibleStaffMode: visibleStaffMode ?? this.visibleStaffMode,
      isSoundfontReady: isSoundfontReady ?? this.isSoundfontReady,
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
    isSongAudioEnabled,
    audioStaffMode,
    visibleStaffMode,
    isSoundfontReady,
    playbackSpeed,
    timelineMsPerDurationDivision,
    passedNoteIndexes,
    missedNoteIndexes,
  ];
}
