import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

import '../../domain/game_score.dart';
import 'game_prototype_state.dart';

class GamePrototypeCubit extends Cubit<GamePrototypeState> {
  GamePrototypeCubit({this.assetMxlPath, this.songTitle})
    : super(const GamePrototypeState()) {
    _ticker = Ticker(_onTick);
  }

  static const String sampleMxlUrl =
      'https://res.cloudinary.com/dnx5e59hz/raw/upload/v1776261396/chopin-prelude-no-4-in-e-minor-op-28_yaxgbx.mxl';

  static const bool _midiInputEnabled = false;
  static const int initialLeadInMs = 4500;
  static const int hitWindowMs = 120;
  static const int missWindowMs = 160;

  final MidiCommand _midiCommand = MidiCommand();
  final String? assetMxlPath;
  final String? songTitle;
  StreamSubscription<MidiPacket>? _midiSub;
  StreamSubscription<String>? _midiSetupSub;
  MidiDevice? _connectedDevice;
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _elapsedMsNotifier = ValueNotifier<int>(0);
  int _baseElapsedMs = 0;
  int _nextMissScanIndex = 0;
  int _maxDurationMs = 10000;

  Future<void> initialize() async {
    _ticker.stop();
    _stopwatch
      ..stop()
      ..reset();
    _baseElapsedMs = -initialLeadInMs;
    _elapsedMsNotifier.value = _baseElapsedMs;
    _nextMissScanIndex = 0;

    emit(const GamePrototypeState(isLoading: true));

    await _setupMidi();
    await _loadScore();
  }

  Future<void> retry() => initialize();

  Future<void> _setupMidi() async {
    if (!_midiInputEnabled) {
      _connectedDevice = null;
      await _midiSub?.cancel();
      _midiSub = null;
      await _midiSetupSub?.cancel();
      _midiSetupSub = null;
      return;
    }

    try {
      await _connectFirstMidiDevice();
      _midiSetupSub ??= _midiCommand.onMidiSetupChanged?.listen((_) {
        _connectFirstMidiDevice();
      });

      _midiSub ??= _midiCommand.onMidiDataReceived?.listen((packet) {
        _handleMidiPacket(packet.data);
      });
    } catch (_) {
      // Keep gameplay running even if MIDI is unavailable on the device.
    }
  }

  Future<void> _connectFirstMidiDevice() async {
    if (!_midiInputEnabled) {
      _connectedDevice = null;
      return;
    }

    try {
      final devices = await _midiCommand.devices ?? const <MidiDevice>[];
      if (devices.isEmpty) {
        _connectedDevice = null;
        return;
      }

      if (_connectedDevice != null &&
          devices.any((device) => device.id == _connectedDevice!.id)) {
        return;
      }

      final target = devices.first;
      await _midiCommand.connectToDevice(target);
      _connectedDevice = target;
    } catch (_) {
      _connectedDevice = null;
    }
  }

  void _handleMidiPacket(List<int> data) {
    if (!_midiInputEnabled) {
      return;
    }

    if (data.length < 3 || state.score == null || !state.isPlaying) {
      return;
    }

    final status = data[0] & 0xF0;
    final note = data[1];
    final velocity = data[2];

    if (status != 0x90 || velocity == 0) {
      return;
    }

    _judgeNoteInput(note);
  }

  void _judgeNoteInput(int midiNote) {
    final score = state.score;
    if (score == null) {
      return;
    }

    var bestIndex = -1;
    var bestDelta = 1 << 30;
    final windowStart = currentMs - hitWindowMs;
    final windowEnd = currentMs + hitWindowMs;
    final startIndex = _lowerBoundHitTime(score.notes, windowStart);
    final endIndex = _upperBoundHitTime(score.notes, windowEnd);

    for (var i = startIndex; i < endIndex; i++) {
      if (state.passedNoteIndexes.contains(i) ||
          state.missedNoteIndexes.contains(i)) {
        continue;
      }

      final expected = score.notes[i];
      if (expected.midi != midiNote) {
        continue;
      }

      final delta = (expected.hitTimeMs - currentMs).abs();
      if (delta <= hitWindowMs && delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }

    if (bestIndex < 0) {
      return;
    }

    final updatedPassed = Set<int>.from(state.passedNoteIndexes)
      ..add(bestIndex);
    emit(state.copyWith(passedNoteIndexes: updatedPassed));
  }

  Future<void> _loadScore() async {
    if (assetMxlPath != null) {
      await _loadAssetScore(assetMxlPath!);
      return;
    }
    await _loadSampleScore();
  }

  Future<void> _loadAssetScore(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final mxlDocument = parseMxlDocument(bytes.buffer.asUint8List());
      final score = buildScoreDataFromMxlDocument(mxlDocument);
      _nextMissScanIndex = 0;

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
          score: score,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _play();
    } catch (error) {
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Khong tai duoc bai hat tu asset: $assetPath\n$error',
          isPlaying: false,
        ),
      );
    }
  }

  Future<void> _loadSampleScore() async {
    try {
      final response = await Dio().get<List<int>>(
        sampleMxlUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Khong tai duoc MXL mau.');
      }

      final mxlDocument = parseMxlDocument(Uint8List.fromList(bytes));
      final score = buildScoreDataFromMxlDocument(mxlDocument);
      _nextMissScanIndex = 0;

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
          score: score,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _play();
    } catch (error) {
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          isPlaying: false,
        ),
      );
    }
  }

  void _play() {
    if (state.isPlaying || state.score == null) {
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    _ticker.start();
    emit(state.copyWith(isPlaying: true));
  }

  void play() => _play();

  void _pause() {
    if (!state.isPlaying) {
      return;
    }

    _baseElapsedMs += _stopwatch.elapsedMilliseconds;
    _elapsedMsNotifier.value = _baseElapsedMs;
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    emit(state.copyWith(isPlaying: false));
  }

  void pause() => _pause();

  void togglePlayback() {
    if (state.isPlaying) {
      _pause();
      return;
    }
    _play();
  }

  void _onTick(Duration _) {
    if (!state.isPlaying || state.score == null) {
      return;
    }

    final current = currentMs;
    final updatedMisses = _updateMissesIncremental(current);

    if (current >= maxDurationMs) {
      _pause();
      return;
    }

    if (_elapsedMsNotifier.value == current) {
      if (updatedMisses == null) {
        return;
      }
      emit(state.copyWith(missedNoteIndexes: updatedMisses));
      return;
    }

    _elapsedMsNotifier.value = current;
    if (updatedMisses != null) {
      emit(state.copyWith(missedNoteIndexes: updatedMisses));
    }
  }

  Set<int>? _updateMissesIncremental(int currentMs) {
    final score = state.score;
    if (score == null || score.notes.isEmpty) {
      return null;
    }

    final deadline = currentMs - missWindowMs;
    if (_nextMissScanIndex >= score.notes.length ||
        score.notes[_nextMissScanIndex].hitTimeMs > deadline) {
      return null;
    }

    final missed = Set<int>.from(state.missedNoteIndexes);
    var changed = false;

    while (_nextMissScanIndex < score.notes.length) {
      final note = score.notes[_nextMissScanIndex];
      if (note.hitTimeMs > deadline) {
        break;
      }

      if (!state.passedNoteIndexes.contains(_nextMissScanIndex) &&
          !missed.contains(_nextMissScanIndex)) {
        missed.add(_nextMissScanIndex);
        changed = true;
      }

      _nextMissScanIndex++;
    }

    return changed ? missed : null;
  }

  int _lowerBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _upperBoundHitTime(List<MusicNote> notes, int targetMs) {
    var low = 0;
    var high = notes.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (notes[mid].hitTimeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int get currentMs {
    if (!state.isPlaying) {
      return _baseElapsedMs;
    }

    return _baseElapsedMs + _stopwatch.elapsedMilliseconds;
  }

  ValueListenable<int> get elapsedMsListenable => _elapsedMsNotifier;

  int get maxDurationMs {
    return _maxDurationMs;
  }

  int _computeMaxDurationMs(ScoreData score) {
    if (score.notes.isEmpty) {
      return 10000;
    }

    final last = score.notes
        .map((note) => note.hitTimeMs + (note.holdMs < 180 ? 180 : note.holdMs))
        .reduce((a, b) => a > b ? a : b);
    return last + 2400;
  }

  @override
  Future<void> close() async {
    _ticker.dispose();
    await _midiSub?.cancel();
    await _midiSetupSub?.cancel();
    if (_midiInputEnabled && _connectedDevice != null) {
      _midiCommand.disconnectDevice(_connectedDevice!);
    }
    _stopwatch
      ..stop()
      ..reset();
    _elapsedMsNotifier.dispose();
    return super.close();
  }
}
