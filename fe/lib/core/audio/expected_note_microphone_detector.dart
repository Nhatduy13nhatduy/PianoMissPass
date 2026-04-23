import 'expected_note_pitch_detector.dart';
import 'microphone_note_detector.dart';

class ExpectedNoteMicrophoneDetector implements MicrophoneNoteDetector {
  ExpectedNoteMicrophoneDetector({ExpectedNotePitchDetector? detector})
    : _detector = detector ?? ExpectedNotePitchDetector();

  final ExpectedNotePitchDetector _detector;

  @override
  String get debugName => 'FFT fallback';

  @override
  int get sampleRate => _detector.sampleRate;

  @override
  int get bufferSize => _detector.hopSize;

  @override
  Future<bool> initialize() async => true;

  @override
  PitchDetectionFrame? addSamples(
    List<double> samples, {
    required Set<int> candidateMidis,
    required MicrophoneCalibration calibration,
  }) {
    return _detector.addSamples(
      samples,
      candidateMidis: candidateMidis,
      calibration: calibration,
    );
  }

  @override
  void reset() {
    _detector.reset();
  }

  @override
  Future<void> dispose() async {}
}
