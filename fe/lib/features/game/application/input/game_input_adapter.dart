import '../../presentation/cubit/game_prototype_state.dart';

class GameInputSnapshot {
  const GameInputSnapshot({
    required this.detectedMidis,
    required this.noteLabels,
    this.confidenceByMidi = const <int, double>{},
    this.expectedMidis = const <int>{},
    this.signalLevel = 0,
    this.noiseFloor = 0,
    this.detectorLabel,
  });

  final Set<int> detectedMidis;
  final List<String> noteLabels;
  final Map<int, double> confidenceByMidi;
  final Set<int> expectedMidis;
  final double signalLevel;
  final double noiseFloor;
  final String? detectorLabel;
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

List<String> gameInputMidiLabels(Set<int> midis) {
  final sorted = midis.toList()..sort();
  return sorted.map(gameInputMidiToLabel).toList(growable: false);
}

String gameInputMidiToLabel(int midi) {
  const pitchNames = <String>[
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  final pitchClass = midi % 12;
  final octave = (midi ~/ 12) - 1;
  return '${pitchNames[pitchClass]}$octave';
}
