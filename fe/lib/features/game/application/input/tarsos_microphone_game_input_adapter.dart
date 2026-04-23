import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/audio/microphone_note_detector.dart';
import '../../presentation/cubit/game_prototype_state.dart';
import 'game_input_adapter.dart';

class TarsosMicrophoneGameInputAdapter implements GameInputAdapter {
  TarsosMicrophoneGameInputAdapter({
    required MicrophoneCalibration Function() calibrationProvider,
    required Set<int> Function() candidateMidisProvider,
  }) : _calibrationProvider = calibrationProvider,
       _candidateMidisProvider = candidateMidisProvider;

  static const MethodChannel _methodChannel = MethodChannel(
    'pianomisspass/native_microphone_pitch',
  );
  static const EventChannel _eventChannel = EventChannel(
    'pianomisspass/native_microphone_pitch/events',
  );
  static const Duration _expectedUpdateInterval = Duration(milliseconds: 24);
  static const Duration _noteHoldDuration = Duration(milliseconds: 80);

  final MicrophoneCalibration Function() _calibrationProvider;
  final Set<int> Function() _candidateMidisProvider;
  final Map<int, int> _hitStreakByMidi = <int, int>{};
  final Map<int, int> _missStreakByMidi = <int, int>{};
  final Set<int> _stableDetectedMidis = <int>{};
  final Map<int, int> _heldDetectedUntilMs = <int, int>{};
  final Map<int, int> _heldActiveUntilMs = <int, int>{};

  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _expectedUpdateTimer;
  Set<int> _lastExpectedMidis = const <int>{};
  Set<int> _lastSnapshotDetectedMidis = const <int>{};
  Set<int> _lastSnapshotActiveMidis = const <int>{};
  GameInputSnapshotCallback? _onSnapshot;
  GameInputStatusCallback? _onStatusChanged;
  bool _isCapturing = false;
  bool _isStopping = false;

  @override
  Future<void> start({
    required GameInputMode inputMode,
    required GameInputSnapshotCallback onSnapshot,
    required GameInputStatusCallback onStatusChanged,
  }) async {
    if (_isCapturing) {
      return;
    }

    _onSnapshot = onSnapshot;
    _onStatusChanged = onStatusChanged;
    _resetDetectionState();

    if (!Platform.isAndroid) {
      _emitStatus(
        const GameInputStatus(
          isReady: false,
          label: 'TarsosDSP microphone is only available on Android.',
        ),
      );
      return;
    }

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

      final isNativeAvailable =
          await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (!isNativeAvailable) {
        _emitStatus(
          const GameInputStatus(
            isReady: false,
            label: 'Native microphone plugin is not available.',
          ),
        );
        return;
      }

      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNativeEvent,
        onError: _handleNativeError,
      );
      await _pushExpectedMidis(force: true);
      await _methodChannel.invokeMethod<void>('start');
      _expectedUpdateTimer = Timer.periodic(_expectedUpdateInterval, (_) {
        unawaited(_pushExpectedMidis());
        _emitHeldSnapshotIfChanged();
      });

      _isCapturing = true;
      _emitStatus(
        const GameInputStatus(
          isReady: true,
          label: 'Microphone ready (TarsosDSP native).',
        ),
      );
    } catch (error) {
      debugPrint('Native microphone input init failed: $error');
      await stop();
      _emitStatus(
        GameInputStatus(
          isReady: false,
          label: 'Failed to start native microphone: $error',
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    if (_isStopping) {
      return;
    }
    _isStopping = true;
    try {
      _expectedUpdateTimer?.cancel();
      _expectedUpdateTimer = null;
      if (_isCapturing) {
        await _methodChannel.invokeMethod<void>('stop');
      }
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _isCapturing = false;
      _lastExpectedMidis = const <int>{};
      _resetDetectionState();
      _emitSnapshotIfChanged(
        detectedMidis: const <int>{},
        activeMidis: const <int>{},
      );
      _emitStatus(const GameInputStatus(isReady: false));
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _pushExpectedMidis({bool force = false}) async {
    final expectedMidis = Set<int>.unmodifiable(_candidateMidisProvider());
    if (!force && setEquals(expectedMidis, _lastExpectedMidis)) {
      return;
    }
    _lastExpectedMidis = expectedMidis;
    await _methodChannel.invokeMethod<void>(
      'updateExpectedMidis',
      <String, Object>{'midis': expectedMidis.toList(growable: false)},
    );
  }

  void _handleNativeEvent(dynamic event) {
    final nativeFrame = _coerceNativeFrame(event);
    final calibration = _calibrationProvider();
    final stableDetected = _updateStableDetection(
      nativeFrame.detectedMidis,
      activationFrames: calibration.activationFrames,
      releaseFrames: calibration.releaseFrames,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _refreshHeldMidis(_heldDetectedUntilMs, stableDetected, nowMs);
    _refreshHeldMidis(_heldActiveUntilMs, nativeFrame.activeMidis, nowMs);
    _emitSnapshotIfChanged(
      detectedMidis: _currentHeldMidis(_heldDetectedUntilMs, nowMs),
      activeMidis: _currentHeldMidis(_heldActiveUntilMs, nowMs),
    );
  }

  void _handleNativeError(Object error) {
    if (_isStopping) {
      return;
    }
    _isCapturing = false;
    _expectedUpdateTimer?.cancel();
    _expectedUpdateTimer = null;
    debugPrint('Native microphone capture error: $error');
    _emitSnapshotIfChanged(
      detectedMidis: const <int>{},
      activeMidis: const <int>{},
    );
    _emitStatus(
      GameInputStatus(isReady: false, label: 'Microphone error: $error'),
    );
  }

  _NativePitchFrame _coerceNativeFrame(dynamic event) {
    if (event is Map) {
      final detectedMidis = _coerceMidiSet(event['detectedMidis']);
      final activeMidis = _coerceMidiSet(event['activeMidis']);
      return _NativePitchFrame(
        detectedMidis: detectedMidis,
        activeMidis: activeMidis,
      );
    }

    final midis = _coerceMidiSet(event);
    return _NativePitchFrame(detectedMidis: midis, activeMidis: midis);
  }

  Set<int> _coerceMidiSet(dynamic event) {
    if (event is List) {
      return event.whereType<num>().map((value) => value.toInt()).toSet();
    }
    return const <int>{};
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
    _hitStreakByMidi.clear();
    _missStreakByMidi.clear();
    _stableDetectedMidis.clear();
    _heldDetectedUntilMs.clear();
    _heldActiveUntilMs.clear();
    _lastSnapshotDetectedMidis = const <int>{};
    _lastSnapshotActiveMidis = const <int>{};
  }

  void _refreshHeldMidis(
    Map<int, int> heldUntilMsByMidi,
    Set<int> midis,
    int nowMs,
  ) {
    _pruneHeldMidis(heldUntilMsByMidi, nowMs);
    final holdUntilMs = nowMs + _noteHoldDuration.inMilliseconds;
    for (final midi in midis) {
      heldUntilMsByMidi[midi] = holdUntilMs;
    }
  }

  Set<int> _currentHeldMidis(Map<int, int> heldUntilMsByMidi, int nowMs) {
    _pruneHeldMidis(heldUntilMsByMidi, nowMs);
    return heldUntilMsByMidi.keys.toSet();
  }

  void _pruneHeldMidis(Map<int, int> heldUntilMsByMidi, int nowMs) {
    heldUntilMsByMidi.removeWhere((_, untilMs) => untilMs < nowMs);
  }

  void _emitHeldSnapshotIfChanged() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _emitSnapshotIfChanged(
      detectedMidis: _currentHeldMidis(_heldDetectedUntilMs, nowMs),
      activeMidis: _currentHeldMidis(_heldActiveUntilMs, nowMs),
    );
  }

  void _emitSnapshotIfChanged({
    required Set<int> detectedMidis,
    Set<int>? activeMidis,
  }) {
    final resolvedActiveMidis = activeMidis ?? detectedMidis;
    if (setEquals(detectedMidis, _lastSnapshotDetectedMidis) &&
        setEquals(resolvedActiveMidis, _lastSnapshotActiveMidis)) {
      return;
    }
    _lastSnapshotDetectedMidis = Set<int>.unmodifiable(detectedMidis);
    _lastSnapshotActiveMidis = Set<int>.unmodifiable(resolvedActiveMidis);
    _onSnapshot?.call(
      GameInputSnapshot(
        detectedMidis: detectedMidis,
        activeMidis: resolvedActiveMidis,
      ),
    );
  }

  void _emitStatus(GameInputStatus status) {
    _onStatusChanged?.call(status);
  }
}

class _NativePitchFrame {
  const _NativePitchFrame({
    required this.detectedMidis,
    required this.activeMidis,
  });

  final Set<int> detectedMidis;
  final Set<int> activeMidis;
}
