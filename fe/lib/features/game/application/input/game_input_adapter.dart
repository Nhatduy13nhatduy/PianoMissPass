import '../../presentation/cubit/game_prototype_state.dart';

class GameInputSnapshot {
  const GameInputSnapshot({
    required this.detectedMidis,
    Set<int>? activeMidis,
    this.microphoneDebug,
  }) : activeMidis = activeMidis ?? detectedMidis;

  final Set<int> detectedMidis;
  final Set<int> activeMidis;
  final MicrophoneDebugSnapshot? microphoneDebug;
}

class MicrophoneDebugSnapshot {
  const MicrophoneDebugSnapshot({
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
}

class GameInputStatus {
  const GameInputStatus({required this.isReady, this.label});

  final bool isReady;
  final String? label;
}

typedef GameInputSnapshotCallback = void Function(GameInputSnapshot snapshot);
typedef GameInputStatusCallback = void Function(GameInputStatus status);

abstract class GameInputAdapter {
  Future<void> start({
    required GameInputMode inputMode,
    required GameInputSnapshotCallback onSnapshot,
    required GameInputStatusCallback onStatusChanged,
  });

  Future<void> stop();
}
