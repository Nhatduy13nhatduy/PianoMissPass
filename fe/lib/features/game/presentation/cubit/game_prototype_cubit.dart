import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_engine/flutter_midi_engine.dart';

import '../../domain/game_score.dart';
import '../../domain/note_timing.dart';
import 'game_prototype_state.dart';

class GamePrototypeCubit extends Cubit<GamePrototypeState> {
  GamePrototypeCubit({this.assetMxlPath, this.songTitle})
    : super(const GamePrototypeState()) {
    _ticker = Ticker(_onTick);
  }

  static const String sampleMxlUrl =
      'https://res.cloudinary.com/dnx5e59hz/raw/upload/v1776261396/chopin-prelude-no-4-in-e-minor-op-28_yaxgbx.mxl';
  static const String _soundfontAssetPath =
      'assets/soundfonts/GeneralUser-GS.sf2';

  static const bool _midiInputEnabled = true;
  static const int initialLeadInMs = 4500;
  static const int hitWindowMs = 120;
  static const int missWindowMs = 160;
  static const int _songAudioChannel = 0;
  static const int _midiInputAudioChannel = 1;
  static const int _songPlaybackVelocity = 92;
  static const int _midiInputVelocityFallback = 96;
  static const int _songPlaybackMinimumHoldMs = 90;
  static const int _songAudioLatencyCompensationMs = 160;
  static const int _synthProgramPiano = 0;
  static const int _synthVolume = 110;
  static const int _synthPanCenter = 64;

  final MidiCommand _midiCommand = MidiCommand();
  final FlutterMidiEngine _midiEngine = FlutterMidiEngine();
  final String? assetMxlPath;
  final String? songTitle;
  StreamSubscription<MidiPacket>? _midiSub;
  StreamSubscription<String>? _midiSetupSub;
  MidiDevice? _connectedInputDevice;
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _elapsedMsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Set<int>> _passedNoteIndexesNotifier =
      ValueNotifier<Set<int>>(const <int>{});
  final ValueNotifier<Set<int>> _missedNoteIndexesNotifier =
      ValueNotifier<Set<int>>(const <int>{});
  final List<_ScheduledMidiEvent> _scheduledSongEvents =
      <_ScheduledMidiEvent>[];
  final Map<int, int> _activeSongPlaybackTokenByMidi = <int, int>{};
  final Set<int> _activeInputNotes = <int>{};
  int _baseElapsedMs = 0;
  int _nextMissScanIndex = 0;
  int _nextSongPlaybackEventIndex = 0;
  int _maxDurationMs = 10000;
  bool _isSynthReady = false;
  bool _isSynthLoading = false;

  Future<void> initialize() async {
    final playbackSpeed = state.playbackSpeed;
    final timelineMsPerDurationDivision = state.timelineMsPerDurationDivision;
    final isSongAudioEnabled = state.isSongAudioEnabled;
    _ticker.stop();
    _stopSongPlaybackScheduler();
    await _silenceSongPlaybackNotes();
    _stopwatch
      ..stop()
      ..reset();
    _baseElapsedMs = -initialLeadInMs;
    _elapsedMsNotifier.value = _baseElapsedMs;
    _passedNoteIndexesNotifier.value = const <int>{};
    _missedNoteIndexesNotifier.value = const <int>{};
    _nextMissScanIndex = 0;

    _emitState(
      GamePrototypeState(
        isLoading: true,
        playbackSpeed: playbackSpeed,
        timelineMsPerDurationDivision: timelineMsPerDurationDivision,
        isSongAudioEnabled: isSongAudioEnabled,
        isSoundfontReady: _isSynthReady,
      ),
    );

    await _initializeSynth();
    await _setupMidiInput();
    await _loadScore();
  }

  Future<void> retry() => initialize();

  void _emitState(GamePrototypeState nextState) {
    if (nextState == state) {
      return;
    }
    if (_passedNoteIndexesNotifier.value != nextState.passedNoteIndexes) {
      _passedNoteIndexesNotifier.value = nextState.passedNoteIndexes;
    }
    if (_missedNoteIndexesNotifier.value != nextState.missedNoteIndexes) {
      _missedNoteIndexesNotifier.value = nextState.missedNoteIndexes;
    }
    emit(nextState);
  }

  Future<void> _initializeSynth() async {
    if (_isSynthReady || _isSynthLoading) {
      if (!isClosed) {
        _emitState(state.copyWith(isSoundfontReady: _isSynthReady));
      }
      return;
    }

    _isSynthLoading = true;
    try {
      await _midiEngine.unmute();
    } catch (_) {
      // Unmute is platform-specific; continue even if unavailable.
    }

    try {
      final loaded = await _midiEngine.loadSoundfontFromAsset(
        _soundfontAssetPath,
      );
      if (!loaded) {
        throw Exception('Khong load duoc soundfont tu asset.');
      }

      await _configureSynthChannel(_songAudioChannel);
      await _configureSynthChannel(_midiInputAudioChannel);
      _isSynthReady = true;
    } catch (error) {
      _isSynthReady = false;
      debugPrint('Soundfont init failed: $error');
    } finally {
      _isSynthLoading = false;
      if (!isClosed) {
        _emitState(state.copyWith(isSoundfontReady: _isSynthReady));
      }
    }
  }

  Future<void> _configureSynthChannel(int channel) async {
    await _midiEngine.changeProgram(
      program: _synthProgramPiano,
      channel: channel,
    );
    await _midiEngine.setVolume(volume: _synthVolume, channel: channel);
    await _midiEngine.setPan(pan: _synthPanCenter, channel: channel);
  }

  Future<void> _setupMidiInput() async {
    if (!_midiInputEnabled) {
      await _midiSub?.cancel();
      _midiSub = null;
      await _midiSetupSub?.cancel();
      _midiSetupSub = null;
      _connectedInputDevice = null;
      return;
    }

    try {
      await _connectPreferredMidiInputDevice();
      _midiSetupSub ??= _midiCommand.onMidiSetupChanged?.listen((_) {
        _connectPreferredMidiInputDevice();
      });
      _midiSub ??= _midiCommand.onMidiDataReceived?.listen((packet) {
        _handleMidiPacket(packet.data);
      });
    } catch (_) {
      // Keep gameplay running even if MIDI input is unavailable.
    }
  }

  Future<void> _connectPreferredMidiInputDevice() async {
    try {
      final devices = await _midiCommand.devices ?? const <MidiDevice>[];
      final target = _selectPreferredMidiInputDevice(devices);
      if (target == null) {
        if (_connectedInputDevice != null) {
          _midiCommand.disconnectDevice(_connectedInputDevice!);
        }
        _connectedInputDevice = null;
        return;
      }

      if (_connectedInputDevice?.id == target.id) {
        return;
      }

      if (_connectedInputDevice != null) {
        _midiCommand.disconnectDevice(_connectedInputDevice!);
      }
      await _midiCommand.connectToDevice(target);
      _connectedInputDevice = target;
    } catch (_) {
      _connectedInputDevice = null;
    }
  }

  MidiDevice? _selectPreferredMidiInputDevice(List<MidiDevice> devices) {
    final preferred = devices
        .where((device) => device.inputPorts.isNotEmpty)
        .toList();
    if (preferred.isEmpty) {
      return null;
    }

    for (final device in preferred) {
      if (device.connected) {
        return device;
      }
    }
    return preferred.first;
  }

  void _handleMidiPacket(List<int> data) {
    if (!_midiInputEnabled || data.length < 3) {
      return;
    }

    final status = data[0] & 0xF0;
    final note = data[1];
    final velocity = data[2];

    if (status == 0x90 && velocity > 0) {
      _playInputMidiNote(note, velocity);
      if (state.score != null && state.isPlaying) {
        _judgeNoteInput(note);
      }
      return;
    }

    if (status == 0x80 || (status == 0x90 && velocity == 0)) {
      _stopInputMidiNote(note);
    }
  }

  void _playInputMidiNote(int midiNote, int velocity) {
    _activeInputNotes.add(midiNote);
    if (!_isSynthReady) {
      return;
    }

    unawaited(
      _midiEngine.playNote(
        note: midiNote,
        velocity: velocity > 0 ? velocity : _midiInputVelocityFallback,
        channel: _midiInputAudioChannel,
      ),
    );
  }

  void _stopInputMidiNote(int midiNote) {
    final removed = _activeInputNotes.remove(midiNote);
    if (!removed || !_isSynthReady) {
      return;
    }

    unawaited(
      _midiEngine.stopNote(
        note: midiNote,
        velocity: 0,
        channel: _midiInputAudioChannel,
      ),
    );
  }

  Future<void> _silenceInputNotes() async {
    if (_activeInputNotes.isEmpty || !_isSynthReady) {
      _activeInputNotes.clear();
      return;
    }

    final notes = _activeInputNotes.toList();
    _activeInputNotes.clear();
    for (final note in notes) {
      await _midiEngine.stopNote(
        note: note,
        velocity: 0,
        channel: _midiInputAudioChannel,
      );
    }
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
    _emitState(state.copyWith(passedNoteIndexes: updatedPassed));
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

      _emitState(
        state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
          score: score,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
          isSoundfontReady: _isSynthReady,
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _rebuildSongPlaybackEvents(score);
      _play();
    } catch (error) {
      if (isClosed) {
        return;
      }

      _emitState(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Khong tai duoc bai hat tu asset: $assetPath\n$error',
          isPlaying: false,
          isSoundfontReady: _isSynthReady,
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

      _emitState(
        state.copyWith(
          isLoading: false,
          clearErrorMessage: true,
          score: score,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
          isSoundfontReady: _isSynthReady,
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _rebuildSongPlaybackEvents(score);
      _play();
    } catch (error) {
      if (isClosed) {
        return;
      }

      _emitState(
        state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          isPlaying: false,
          isSoundfontReady: _isSynthReady,
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
    _emitState(state.copyWith(isPlaying: true));
    _restartSongPlaybackFromCurrentPosition();
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
    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());
    _emitState(state.copyWith(isPlaying: false));
  }

  void pause() => _pause();

  void togglePlayback() {
    if (state.isPlaying) {
      _pause();
      return;
    }
    _play();
  }

  void setSongAudioEnabled(bool value) {
    if (value == state.isSongAudioEnabled) {
      return;
    }

    _emitState(state.copyWith(isSongAudioEnabled: value));
    if (!value) {
      _stopSongPlaybackScheduler();
      unawaited(_silenceSongPlaybackNotes());
      return;
    }

    if (state.isPlaying) {
      _restartSongPlaybackFromCurrentPosition();
    }
  }

  void setPlaybackSpeed(double value) {
    final clamped = value
        .clamp(NoteTiming.minPlaybackSpeed, NoteTiming.maxPlaybackSpeed)
        .toDouble();
    final anchoredCurrentMs = currentMs;

    _baseElapsedMs = anchoredCurrentMs;
    _elapsedMsNotifier.value = anchoredCurrentMs;
    if (state.isPlaying) {
      _stopwatch
        ..reset()
        ..start();
    }

    _emitState(state.copyWith(playbackSpeed: clamped));
    if (state.isPlaying && state.isSongAudioEnabled) {
      _restartSongPlaybackFromCurrentPosition();
    }
  }

  void setTimelineMsPerDurationDivision(int value) {
    final minTimeline = NoteTiming.minTimelineMsPerDurationDivision;
    final maxTimeline = NoteTiming.maxTimelineMsPerDurationDivision;
    final step = NoteTiming.timelineMsPerDurationDivisionStep;
    final normalized = ((value / step).round() * step)
        .clamp(minTimeline, maxTimeline)
        .toInt();
    _emitState(state.copyWith(timelineMsPerDurationDivision: normalized));
  }

  void _onTick(Duration _) {
    if (!state.isPlaying || state.score == null) {
      return;
    }

    final current = currentMs;
    if (state.isSongAudioEnabled) {
      _pumpSongPlayback(current);
    }
    final updatedMisses = _updateMissesIncremental(current);

    if (current >= maxDurationMs) {
      _pause();
      return;
    }

    if (_elapsedMsNotifier.value == current) {
      if (updatedMisses == null) {
        return;
      }
      _emitState(state.copyWith(missedNoteIndexes: updatedMisses));
      return;
    }

    _elapsedMsNotifier.value = current;
    if (updatedMisses != null) {
      _emitState(state.copyWith(missedNoteIndexes: updatedMisses));
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

    return _baseElapsedMs +
        (_stopwatch.elapsedMilliseconds * state.playbackSpeed).round();
  }

  ValueListenable<int> get elapsedMsListenable => _elapsedMsNotifier;
  ValueListenable<Set<int>> get passedNoteIndexesListenable =>
      _passedNoteIndexesNotifier;
  ValueListenable<Set<int>> get missedNoteIndexesListenable =>
      _missedNoteIndexesNotifier;

  int get maxDurationMs {
    return _maxDurationMs;
  }

  int _computeMaxDurationMs(ScoreData score) {
    final timedNotes = score.playbackNotes.isEmpty
        ? score.notes
        : score.playbackNotes;
    if (timedNotes.isEmpty) {
      return 10000;
    }

    final last = timedNotes
        .map((note) => note.hitTimeMs + (note.holdMs < 180 ? 180 : note.holdMs))
        .reduce((a, b) => a > b ? a : b);
    return last + 2400;
  }

  void _rebuildSongPlaybackEvents(ScoreData score) {
    _scheduledSongEvents
      ..clear()
      ..addAll(_buildSongPlaybackEvents(score));
    _nextSongPlaybackEventIndex = 0;
  }

  List<_ScheduledMidiEvent> _buildSongPlaybackEvents(ScoreData score) {
    final events = <_ScheduledMidiEvent>[];
    final playbackNotes = score.playbackNotes.isEmpty
        ? score.notes
        : score.playbackNotes;
    for (var i = 0; i < playbackNotes.length; i++) {
      final note = playbackNotes[i];
      final noteOnTimeMs = _songPlaybackStartMs(note);
      final noteOffTimeMs = _songPlaybackEndMs(note);
      events.add(
        _ScheduledMidiEvent(
          timeMs: noteOnTimeMs,
          midi: note.midi,
          token: i,
          type: _ScheduledMidiEventType.noteOn,
        ),
      );
      events.add(
        _ScheduledMidiEvent(
          timeMs: noteOffTimeMs,
          midi: note.midi,
          token: i,
          type: _ScheduledMidiEventType.noteOff,
        ),
      );
    }

    events.sort((a, b) {
      final timeComparison = a.timeMs.compareTo(b.timeMs);
      if (timeComparison != 0) {
        return timeComparison;
      }
      if (a.type != b.type) {
        return a.type == _ScheduledMidiEventType.noteOff ? -1 : 1;
      }
      return a.token.compareTo(b.token);
    });
    return events;
  }

  int _songPlaybackStartMs(MusicNote note) {
    return note.hitTimeMs - _songAudioLatencyCompensationMs;
  }

  int _songPlaybackEndMs(MusicNote note) {
    final holdMs = note.holdMs < _songPlaybackMinimumHoldMs
        ? _songPlaybackMinimumHoldMs
        : note.holdMs;
    return _songPlaybackStartMs(note) + holdMs;
  }

  void _restartSongPlaybackFromCurrentPosition() {
    if (!state.isPlaying ||
        !state.isSongAudioEnabled ||
        state.score == null ||
        !_isSynthReady) {
      return;
    }

    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());

    final current = currentMs;
    _restoreActiveSongPlaybackNotes(current);
    _nextSongPlaybackEventIndex = _upperBoundSongPlaybackEventTime(current);
    _pumpSongPlayback(current);
  }

  void _restoreActiveSongPlaybackNotes(int currentMs) {
    final score = state.score;
    if (score == null || !_isSynthReady) {
      return;
    }

    final playbackNotes = score.playbackNotes.isEmpty
        ? score.notes
        : score.playbackNotes;
    final latestTokenByMidi = <int, int>{};
    for (var i = 0; i < playbackNotes.length; i++) {
      final note = playbackNotes[i];
      if (_songPlaybackStartMs(note) <= currentMs &&
          currentMs < _songPlaybackEndMs(note)) {
        latestTokenByMidi[note.midi] = i;
      }
    }

    for (final entry in latestTokenByMidi.entries) {
      _activeSongPlaybackTokenByMidi[entry.key] = entry.value;
      unawaited(
        _midiEngine.playNote(
          note: entry.key,
          velocity: _songPlaybackVelocity,
          channel: _songAudioChannel,
        ),
      );
    }
  }

  void _pumpSongPlayback([int? currentOverrideMs]) {
    if (!state.isPlaying ||
        !state.isSongAudioEnabled ||
        state.score == null ||
        !_isSynthReady) {
      return;
    }

    final nowMs = currentOverrideMs ?? currentMs;
    while (_nextSongPlaybackEventIndex < _scheduledSongEvents.length) {
      final event = _scheduledSongEvents[_nextSongPlaybackEventIndex];
      if (event.timeMs > nowMs) {
        break;
      }
      _dispatchSongPlaybackEvent(event);
      _nextSongPlaybackEventIndex++;
    }

    if (_nextSongPlaybackEventIndex >= _scheduledSongEvents.length &&
        _activeSongPlaybackTokenByMidi.isEmpty) {
      _stopSongPlaybackScheduler();
    }
  }

  void _dispatchSongPlaybackEvent(_ScheduledMidiEvent event) {
    if (!_isSynthReady) {
      return;
    }

    if (event.type == _ScheduledMidiEventType.noteOn) {
      final activeToken = _activeSongPlaybackTokenByMidi[event.midi];
      if (activeToken != null && activeToken != event.token) {
        unawaited(
          _midiEngine.stopNote(
            note: event.midi,
            velocity: 0,
            channel: _songAudioChannel,
          ),
        );
      }
      _activeSongPlaybackTokenByMidi[event.midi] = event.token;
      unawaited(
        _midiEngine.playNote(
          note: event.midi,
          velocity: _songPlaybackVelocity,
          channel: _songAudioChannel,
        ),
      );
      return;
    }

    final activeToken = _activeSongPlaybackTokenByMidi[event.midi];
    if (activeToken != event.token) {
      return;
    }
    _activeSongPlaybackTokenByMidi.remove(event.midi);
    unawaited(
      _midiEngine.stopNote(
        note: event.midi,
        velocity: 0,
        channel: _songAudioChannel,
      ),
    );
  }

  int _upperBoundSongPlaybackEventTime(int targetMs) {
    var low = 0;
    var high = _scheduledSongEvents.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_scheduledSongEvents[mid].timeMs <= targetMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  void _stopSongPlaybackScheduler() {
    // Audio events are advanced from the frame ticker, so there is no
    // separate timer to tear down here.
  }

  Future<void> _silenceSongPlaybackNotes() async {
    if (_activeSongPlaybackTokenByMidi.isEmpty || !_isSynthReady) {
      _activeSongPlaybackTokenByMidi.clear();
      return;
    }

    final activeMidis = _activeSongPlaybackTokenByMidi.keys.toList();
    _activeSongPlaybackTokenByMidi.clear();
    for (final midi in activeMidis) {
      await _midiEngine.stopNote(
        note: midi,
        velocity: 0,
        channel: _songAudioChannel,
      );
    }
  }

  @override
  Future<void> close() async {
    _stopSongPlaybackScheduler();
    await _silenceSongPlaybackNotes();
    await _silenceInputNotes();
    if (_isSynthReady) {
      try {
        await _midiEngine.stopAllNotes();
        await _midiEngine.unloadSoundfont();
      } catch (_) {
        // Ignore teardown errors during disposal.
      }
    }
    _ticker.dispose();
    await _midiSub?.cancel();
    await _midiSetupSub?.cancel();
    if (_connectedInputDevice != null) {
      _midiCommand.disconnectDevice(_connectedInputDevice!);
    }
    _stopwatch
      ..stop()
      ..reset();
    _elapsedMsNotifier.dispose();
    _passedNoteIndexesNotifier.dispose();
    _missedNoteIndexesNotifier.dispose();
    return super.close();
  }
}

enum _ScheduledMidiEventType { noteOn, noteOff }

class _ScheduledMidiEvent {
  const _ScheduledMidiEvent({
    required this.timeMs,
    required this.midi,
    required this.token,
    required this.type,
  });

  final int timeMs;
  final int midi;
  final int token;
  final _ScheduledMidiEventType type;
}
