import 'dart:async';

class PitchDetectionFrame {
  const PitchDetectionFrame({required this.detectedMidis, required this.rms});

  final Set<int> detectedMidis;
  final double rms;
}

class MicrophoneCalibration {
  const MicrophoneCalibration({
    required this.rmsGate,
    required this.activationFrames,
    required this.releaseFrames,
  });

  final double rmsGate;
  final int activationFrames;
  final int releaseFrames;
}

abstract class MicrophoneNoteDetector {
  String get debugName;
  int get sampleRate;
  int get bufferSize;

  Future<bool> initialize();

  FutureOr<PitchDetectionFrame?> addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  });

  void reset();

  Future<void> dispose();
}
