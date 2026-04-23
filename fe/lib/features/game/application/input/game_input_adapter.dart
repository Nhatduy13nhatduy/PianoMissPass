import '../../presentation/cubit/game_prototype_state.dart';

class GameInputSnapshot {
  const GameInputSnapshot({
    required this.detectedMidis,
    Set<int>? activeMidis,
  }) : activeMidis = activeMidis ?? detectedMidis;

  final Set<int> detectedMidis;
  final Set<int> activeMidis;
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
