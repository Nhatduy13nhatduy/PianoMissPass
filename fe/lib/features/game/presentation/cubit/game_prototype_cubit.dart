import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

import '../../domain/game_score.dart';
import 'game_prototype_state.dart';

class GamePrototypeCubit extends Cubit<GamePrototypeState> {
  GamePrototypeCubit() : super(const GamePrototypeState()) {
    _ticker = Ticker(_onTick);
  }

  static const String sampleMxlUrl =
      'https://res.cloudinary.com/dnx5e59hz/raw/upload/v1775314886/pianomisspass/canon-in-d-johann-pachelbel_ece4o3.mxl';

  static const int hitWindowMs = 180;
  static const int missWindowMs = 220;

  final MidiCommand _midiCommand = MidiCommand();
  StreamSubscription<MidiPacket>? _midiSub;
  StreamSubscription<String>? _midiSetupSub;
  MidiDevice? _connectedDevice;
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _baseElapsedMs = 0;

  Future<void> initialize() async {
    _ticker.stop();
    _stopwatch
      ..stop()
      ..reset();
    _baseElapsedMs = 0;

    emit(const GamePrototypeState(isLoading: true));

    await _setupMidi();
    await _loadSampleScore();
  }

  Future<void> retry() => initialize();

  Future<void> _setupMidi() async {
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

    for (var i = 0; i < score.notes.length; i++) {
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

      final score = parseMxl(Uint8List.fromList(bytes));

      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
          score: score,
          elapsedMs: 0,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
        ),
      );

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

  void _pause() {
    if (!state.isPlaying) {
      return;
    }

    _baseElapsedMs += _stopwatch.elapsedMilliseconds;
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    emit(state.copyWith(isPlaying: false, elapsedMs: _baseElapsedMs));
  }

  void _onTick(Duration _) {
    if (!state.isPlaying || state.score == null) {
      return;
    }

    final current = currentMs;
    final updatedMisses = _updateMisses(current);

    if (current >= maxDurationMs) {
      _pause();
      return;
    }

    emit(
      state.copyWith(
        elapsedMs: current,
        passedNoteIndexes: updatedMisses.passed,
        missedNoteIndexes: updatedMisses.missed,
      ),
    );
  }

  ({Set<int> passed, Set<int> missed}) _updateMisses(int currentMs) {
    final score = state.score;
    if (score == null) {
      return (
        passed: Set<int>.from(state.passedNoteIndexes),
        missed: Set<int>.from(state.missedNoteIndexes),
      );
    }

    final missed = Set<int>.from(state.missedNoteIndexes);
    for (var i = 0; i < score.notes.length; i++) {
      if (state.passedNoteIndexes.contains(i) || missed.contains(i)) {
        continue;
      }

      final note = score.notes[i];
      if (currentMs - note.hitTimeMs > missWindowMs) {
        missed.add(i);
      }
    }

    return (passed: Set<int>.from(state.passedNoteIndexes), missed: missed);
  }

  int get currentMs {
    if (!state.isPlaying) {
      return _baseElapsedMs;
    }

    return _baseElapsedMs + _stopwatch.elapsedMilliseconds;
  }

  int get maxDurationMs {
    final score = state.score;
    if (score == null || score.notes.isEmpty) {
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
    if (_connectedDevice != null) {
      _midiCommand.disconnectDevice(_connectedDevice!);
    }
    _stopwatch
      ..stop()
      ..reset();
    return super.close();
  }
}
