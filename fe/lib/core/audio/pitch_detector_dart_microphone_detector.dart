import 'dart:math' as math;

import 'package:pitch_detector_dart/pitch_detector.dart';

import 'microphone_note_detector.dart';

class PitchDetectorDartMicrophoneDetector implements MicrophoneNoteDetector {
  PitchDetectorDartMicrophoneDetector({
    this.audioSampleRate = 44100,
    this.frameSize = 2048,
    this.hopSize = 1024,
    this.maxSemitoneDistanceFromCandidate = 0,
  });

  final int audioSampleRate;
  final int frameSize;
  final int hopSize;
  final int maxSemitoneDistanceFromCandidate;

  late final PitchDetector _pitchDetector;
  final List<double> _sampleBuffer = <double>[];

  @override
  String get debugName => 'Pitch Detector Dart';

  @override
  int get sampleRate => audioSampleRate;

  @override
  int get bufferSize => hopSize;

  @override
  Future<bool> initialize() async {
    _pitchDetector = PitchDetector(
      audioSampleRate: audioSampleRate.toDouble(),
      bufferSize: frameSize,
    );
    _sampleBuffer.clear();
    return true;
  }

  @override
  Future<PitchDetectionFrame?> addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  }) async {
    if (samples.isEmpty) {
      return null;
    }

    _sampleBuffer.addAll(samples);
    if (_sampleBuffer.length < frameSize) {
      return null;
    }

    final frame = _sampleBuffer.sublist(_sampleBuffer.length - frameSize);
    final keepFrom = math.max(0, _sampleBuffer.length - (frameSize - hopSize));
    if (keepFrom > 0) {
      _sampleBuffer.removeRange(0, keepFrom);
    }

    final rms = _computeRms(frame);
    if (rms < calibration.rmsGate || candidateMidis.isEmpty) {
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }

    final result = await _pitchDetector.getPitchFromFloatBuffer(frame);
    if (!result.pitched || result.pitch <= 0) {
      return PitchDetectionFrame(detectedMidis: const <int>{}, rms: rms);
    }

    final rawMidi = _frequencyToMidi(result.pitch);
    final nearestMidi = rawMidi.round();
    final matchedMidi = _nearestCandidateMidi(
      nearestMidi,
      candidateMidis: candidateMidis,
    );
    if (matchedMidi == null) {
      return PitchDetectionFrame(
        detectedMidis: const <int>{},
        rms: rms,
      );
    }

    return PitchDetectionFrame(
      detectedMidis: <int>{matchedMidi},
      rms: rms,
    );
  }

  @override
  void reset() {
    _sampleBuffer.clear();
  }

  @override
  Future<void> dispose() async {
    _sampleBuffer.clear();
  }

  int? _nearestCandidateMidi(
    int midi, {
    required Set<int> candidateMidis,
  }) {
    int? bestMidi;
    var bestDistance = 1 << 30;
    for (final candidateMidi in candidateMidis) {
      final distance = (candidateMidi - midi).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMidi = candidateMidi;
      }
    }
    if (bestDistance > maxSemitoneDistanceFromCandidate) {
      return null;
    }
    return bestMidi;
  }

  double _frequencyToMidi(double frequency) {
    return 69 + 12 * (math.log(frequency / 440.0) / math.ln2);
  }

  double _computeRms(List<double> frame) {
    var energy = 0.0;
    for (final sample in frame) {
      energy += sample * sample;
    }
    return math.sqrt(energy / frame.length);
  }
}
