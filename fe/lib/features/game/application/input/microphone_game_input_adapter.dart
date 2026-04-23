import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/audio/basic_pitch_tflite_detector.dart';
import '../../../../core/audio/expected_note_microphone_detector.dart';
import '../../../../core/audio/microphone_note_detector.dart';
import '../../presentation/cubit/game_prototype_state.dart';
import 'game_input_adapter.dart';

class MicrophoneGameInputAdapter implements GameInputAdapter {
  MicrophoneGameInputAdapter({
    FlutterAudioCapture? microphoneCapture,
    List<MicrophoneNoteDetector> Function()? detectorCandidatesFactory,
    required MicrophoneCalibration Function() calibrationProvider,
    required Set<int> Function() candidateMidisProvider,
  }) : _microphoneCapture = microphoneCapture ?? FlutterAudioCapture(),
       _detectorCandidatesFactory =
           detectorCandidatesFactory ?? _defaultDetectorCandidatesFactory,
       _calibrationProvider = calibrationProvider,
       _candidateMidisProvider = candidateMidisProvider;

  FlutterAudioCapture _microphoneCapture;
  final List<MicrophoneNoteDetector> Function() _detectorCandidatesFactory;
  final MicrophoneCalibration Function() _calibrationProvider;
  final Set<int> Function() _candidateMidisProvider;
  final Map<int, int> _hitStreakByMidi = <int, int>{};
  final Map<int, int> _missStreakByMidi = <int, int>{};
  final Set<int> _stableDetectedMidis = <int>{};
  MicrophoneNoteDetector? _activeDetector;

  bool _isCapturing = false;
  bool _isStarting = false;
  bool _isStopping = false;
  GameInputSnapshotCallback? _onSnapshot;
  GameInputStatusCallback? _onStatusChanged;

  @override
  Future<void> start({
    required GameInputMode inputMode,
    required GameInputSnapshotCallback onSnapshot,
    required GameInputStatusCallback onStatusChanged,
  }) async {
    if (_isCapturing || _isStarting) {
      return;
    }

    _isStarting = true;
    _onSnapshot = onSnapshot;
    _onStatusChanged = onStatusChanged;
    _microphoneCapture = FlutterAudioCapture();
    _resetDetectionState();

    try {
      final permissionStatus = await Permission.microphone.request();
      if (!permissionStatus.isGranted) {
        _emitStatus(
          GameInputStatus(
            isReady: false,
            label: permissionStatus.isPermanentlyDenied
                ? 'Microphone permission permanently denied. Enable it in Settings.'
                : 'Microphone permission denied.',
          ),
        );
        return;
      }

      _activeDetector = await _createReadyDetector();
      if (_activeDetector == null) {
        _emitStatus(
          const GameInputStatus(
            isReady: false,
            label: 'Failed to initialize any microphone note detector.',
          ),
        );
        return;
      }

      final initialized = await _microphoneCapture.init();
      if (initialized != true) {
        _emitStatus(
          const GameInputStatus(
            isReady: false,
            label: 'Failed to initialize microphone capture plugin.',
          ),
        );
        return;
      }

      await _microphoneCapture.start(
        _handleBuffer,
        _handleError,
        sampleRate: _activeDetector!.sampleRate,
        bufferSize: _activeDetector!.bufferSize,
        waitForFirstDataOnAndroid: false,
      );

      _isCapturing = true;
      _emitStatus(
        GameInputStatus(
          isReady: true,
          label: 'Microphone ready (${_activeDetector!.debugName}).',
        ),
      );
    } catch (error) {
      debugPrint('Microphone input init failed: $error');
      _emitStatus(
        GameInputStatus(
          isReady: false,
          label: 'Failed to start microphone: $error',
        ),
      );
    } finally {
      _isStarting = false;
    }
  }

  @override
  Future<void> stop() async {
    if (_isStopping) {
      return;
    }
    _isStopping = true;
    if (_isCapturing) {
      try {
        await _microphoneCapture.stop();
      } catch (_) {
        // Ignore teardown errors.
      }
    }
    try {
      _isCapturing = false;
      _resetDetectionState();
      await _activeDetector?.dispose();
      _activeDetector = null;
      _emitSnapshot(const <int>{});
      _emitStatus(const GameInputStatus(isReady: false));
    } finally {
      _isStopping = false;
    }
  }

  void _handleBuffer(dynamic obj) {
    final samples = _coerceAudioSamples(obj);
    if (samples.isEmpty) {
      return;
    }

    final calibration = _calibrationProvider();
    final candidateMidis = _candidateMidisProvider();
    if (candidateMidis.isEmpty) {
      final stableDetected = _updateStableDetection(
        const <int>{},
        activationFrames: calibration.activationFrames,
        releaseFrames: calibration.releaseFrames,
      );
      _emitSnapshot(stableDetected);
      return;
    }

    final detection = _activeDetector?.addSamples(
      samples,
      candidateMidis: candidateMidis,
      calibration: calibration,
    );
    if (detection == null) {
      return;
    }

    final stableDetected = _updateStableDetection(
      detection.detectedMidis,
      activationFrames: calibration.activationFrames,
      releaseFrames: calibration.releaseFrames,
    );
    _emitSnapshot(
      stableDetected,
      confidenceByMidi: detection.confidenceByMidi,
      expectedMidis: candidateMidis,
      signalLevel: detection.rms,
      noiseFloor: detection.noiseFloor,
    );
  }

  void _handleError(Object error) {
    if (_isStopping) {
      return;
    }
    _isCapturing = false;
    debugPrint('Microphone capture error: $error');
    _emitStatus(
      GameInputStatus(isReady: false, label: 'Microphone error: $error'),
    );
  }

  List<double> _coerceAudioSamples(dynamic obj) {
    if (obj is Float64List) {
      return obj.toList(growable: false);
    }
    if (obj is Float32List) {
      return obj.map((value) => value.toDouble()).toList(growable: false);
    }
    if (obj is List<double>) {
      return obj;
    }
    if (obj is List) {
      return obj
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList(growable: false);
    }
    return const <double>[];
  }

  Set<int> _updateStableDetection(
    Set<int> rawDetectedMidis, {
    required int activationFrames,
    required int releaseFrames,
  }) {
    final trackedMidis = <int>{
      ..._hitStreakByMidi.keys,
      ..._missStreakByMidi.keys,
      ..._stableDetectedMidis,
      ...rawDetectedMidis,
    };

    for (final midi in trackedMidis) {
      if (rawDetectedMidis.contains(midi)) {
        final nextHit = (_hitStreakByMidi[midi] ?? 0) + 1;
        _hitStreakByMidi[midi] = nextHit;
        _missStreakByMidi[midi] = 0;
        if (nextHit >= activationFrames) {
          _stableDetectedMidis.add(midi);
        }
      } else {
        _hitStreakByMidi[midi] = 0;
        final nextMiss = (_missStreakByMidi[midi] ?? 0) + 1;
        _missStreakByMidi[midi] = nextMiss;
        if (nextMiss >= releaseFrames) {
          _stableDetectedMidis.remove(midi);
        }
      }
    }

    return Set<int>.from(_stableDetectedMidis);
  }

  void _resetDetectionState() {
    _activeDetector?.reset();
    _hitStreakByMidi.clear();
    _missStreakByMidi.clear();
    _stableDetectedMidis.clear();
  }

  Future<MicrophoneNoteDetector?> _createReadyDetector() async {
    for (final detector in _detectorCandidatesFactory()) {
      final isReady = await detector.initialize();
      if (isReady) {
        return detector;
      }
      await detector.dispose();
    }
    return null;
  }

  static List<MicrophoneNoteDetector> _defaultDetectorCandidatesFactory() {
    return <MicrophoneNoteDetector>[
      ExpectedNoteMicrophoneDetector(),
      BasicPitchTfliteDetector(),
    ];
  }

  void _emitSnapshot(
    Set<int> detectedMidis, {
    Map<int, double> confidenceByMidi = const <int, double>{},
    Set<int> expectedMidis = const <int>{},
    double signalLevel = 0,
    double noiseFloor = 0,
  }) {
    _onSnapshot?.call(
      GameInputSnapshot(
        detectedMidis: detectedMidis,
        noteLabels: gameInputMidiLabels(detectedMidis),
        confidenceByMidi: confidenceByMidi,
        expectedMidis: expectedMidis,
        signalLevel: signalLevel,
        noiseFloor: noiseFloor,
        detectorLabel: _activeDetector?.debugName,
      ),
    );
  }

  void _emitStatus(GameInputStatus status) {
    _onStatusChanged?.call(status);
  }
}
