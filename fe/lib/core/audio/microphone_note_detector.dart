class PitchDetectionFrame {
  const PitchDetectionFrame({
    required this.detectedMidis,
    required this.rms,
    this.noiseFloor = 0,
    this.confidenceByMidi = const <int, double>{},
    this.onsetConfidenceByMidi = const <int, double>{},
  });

  final Set<int> detectedMidis;
  final double rms;
  final double noiseFloor;
  final Map<int, double> confidenceByMidi;
  final Map<int, double> onsetConfidenceByMidi;
}

class MicrophoneCalibration {
  const MicrophoneCalibration({
    required this.noteThreshold,
    required this.onsetThreshold,
    required this.rmsGate,
    required this.activationFrames,
    required this.releaseFrames,
  });

  final double noteThreshold;
  final double onsetThreshold;
  final double rmsGate;
  final int activationFrames;
  final int releaseFrames;
}

abstract class MicrophoneNoteDetector {
  String get debugName;
  int get sampleRate;
  int get bufferSize;

  Future<bool> initialize();

  PitchDetectionFrame? addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  });

  void reset();

  Future<void> dispose();
}
