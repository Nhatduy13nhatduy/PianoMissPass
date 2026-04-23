import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pianomisspass_fe/core/audio/microphone_note_detector.dart';

import '../../application/input/game_input_adapter.dart';
import '../../application/input/midi_game_input_adapter.dart';
import '../../application/input/tarsos_microphone_game_input_adapter.dart';
import '../../application/judging/game_note_judge_engine.dart';
import '../../../../core/audio/app_midi_engine.dart';
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

  static const int initialLeadInMs = 5200;
  static const int lateHitWindowMs = 160;
  static const int earlyHitWindowMs = 240;
  static const int missWindowMs = 240;
  static const int _songAudioChannel = 0;
  static const int _midiInputAudioChannel = 1;
  static const int _songPlaybackVelocity = 92;
  static const int _midiInputVelocityFallback = 96;
  static const int _songPlaybackMinimumHoldMs = 90;
  static const int _songAudioLatencyCompensationMs = 0;
  static const int _songPlaybackDispatchLookaheadMs = 12;
  static const int _synthProgramPiano = 0;
  static const int _synthVolume = 110;
  static const int _synthPanCenter = 64;
  static const int _microphoneLatencyMs = 20;
  static const MicrophoneCalibration _microphoneCalibration =
      MicrophoneCalibration(
        rmsGate: 0.004,
        activationFrames: 1,
        releaseFrames: 1,
      );
  static const Duration _inputModeSwitchSettleDelay = Duration(
    milliseconds: 180,
  );
  final AppMidiEngine _midiEngine = AppMidiEngine();
  final GameNoteJudgeEngine _judgeEngine = GameNoteJudgeEngine(
    lateHitWindowMs: lateHitWindowMs,
    earlyHitWindowMs: earlyHitWindowMs,
  );
  final String? assetMxlPath;
  final String? songTitle;

  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<int> _elapsedMsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Set<int>> _passedNoteIndexesNotifier =
      ValueNotifier<Set<int>>(const <int>{});
  final ValueNotifier<Set<int>> _missedNoteIndexesNotifier =
      ValueNotifier<Set<int>>(const <int>{});
  final ValueNotifier<Map<int, int>> _passAnimationStartMsByNoteIndexNotifier =
      ValueNotifier<Map<int, int>>(const <int, int>{});
  final List<_ScheduledMidiEvent> _scheduledSongEvents =
      <_ScheduledMidiEvent>[];

  final Map<int, int> _activeSongPlaybackTokenByMidi = <int, int>{};
  final Set<int> _activeInputNotes = <int>{};
  Set<int> _latestDetectedInputMidis = const <int>{};
  GameInputAdapter? _inputAdapter;

  int _baseElapsedMs = 0;
  int _nextMissScanIndex = 0;
  int _nextSongPlaybackEventIndex = 0;
  int _inputConfigurationGeneration = 0;
  int _maxDurationMs = 10000;
  bool _isSynthReady = false;
  bool _isSynthLoading = false;
  bool _isInputReady = false;
  String? _inputStatusLabel;

  Future<void> initialize() async {
    final playbackSpeed = state.playbackSpeed;
    final timelineMsPerDurationDivision = state.timelineMsPerDurationDivision;
    final audioStaffMode = state.audioStaffMode;
    final visibleStaffMode = state.visibleStaffMode;
    final inputMode = state.inputMode;

    _ticker.stop();
    _stopSongPlaybackScheduler();
    await _silenceSongPlaybackNotes();
    await _silenceInputNotes();
    _inputConfigurationGeneration++;
    await _teardownInputAdapter();
    _stopwatch
      ..stop()
      ..reset();
    _baseElapsedMs = -initialLeadInMs;
    _elapsedMsNotifier.value = _baseElapsedMs;
    _passedNoteIndexesNotifier.value = const <int>{};
    _missedNoteIndexesNotifier.value = const <int>{};
    _passAnimationStartMsByNoteIndexNotifier.value = const <int, int>{};
    _nextMissScanIndex = 0;
    _isInputReady = false;
    _inputStatusLabel = null;
    _latestDetectedInputMidis = const <int>{};

    _emitState(
      GamePrototypeState(
        isLoading: true,
        inputMode: inputMode,
        playbackSpeed: playbackSpeed,
        timelineMsPerDurationDivision: timelineMsPerDurationDivision,
        audioStaffMode: audioStaffMode,
        visibleStaffMode: visibleStaffMode,
        isSoundfontReady: _isSynthReady,
        activeInputMidis: const <int>{},
      ),
    );

    await _initializeSynth();
    await _configureSelectedInputMode(state.inputMode);
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

  GamePrototypeState _applyInputStatus(GamePrototypeState baseState) {
    return baseState.copyWith(
      isMicrophoneActive:
          baseState.inputMode == GameInputMode.microphone && _isInputReady,
      inputDeviceName: _inputStatusLabel,
      clearInputDeviceName: _inputStatusLabel == null,
    );
  }

  Future<void> _initializeSynth() async {
    if (_isSynthReady || _isSynthLoading) {
      if (!isClosed) {
        _emitState(
          _applyInputStatus(state.copyWith(isSoundfontReady: _isSynthReady)),
        );
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
      await _midiEngine.warmUp();
      _isSynthReady = true;
    } catch (error) {
      _isSynthReady = false;
      debugPrint('Soundfont init failed: $error');
    } finally {
      _isSynthLoading = false;
      if (!isClosed) {
        _emitState(
          _applyInputStatus(state.copyWith(isSoundfontReady: _isSynthReady)),
        );
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

  Future<void> _configureSelectedInputMode(GameInputMode mode) async {
    final generation = ++_inputConfigurationGeneration;
    await _teardownInputAdapter();
    if (mode == GameInputMode.microphone) {
      await Future<void>.delayed(_inputModeSwitchSettleDelay);
    }

    if (isClosed ||
        generation != _inputConfigurationGeneration ||
        state.inputMode != mode) {
      return;
    }

    final adapter = switch (mode) {
      GameInputMode.wiredMidi ||
      GameInputMode.bluetoothMidi => MidiGameInputAdapter(),
      GameInputMode.microphone => TarsosMicrophoneGameInputAdapter(
        calibrationProvider: () => _microphoneCalibration,
        candidateMidisProvider: () {
          final score = state.score;
          if (score == null) {
            return const <int>{};
          }
          return _judgeEngine.candidateExpectedMidisAroundTime(
            currentMs: currentMs + _microphoneLatencyMs,
            score: score,
            passedNoteIndexes: state.passedNoteIndexes,
            missedNoteIndexes: state.missedNoteIndexes,
          );
        },
      ),
    };
    _inputAdapter = adapter;

    await adapter.start(
      inputMode: mode,
      onSnapshot: (snapshot) {
        if (generation == _inputConfigurationGeneration &&
            state.inputMode == mode) {
          _handleInputSnapshot(snapshot);
        }
      },
      onStatusChanged: (status) {
        if (generation == _inputConfigurationGeneration &&
            state.inputMode == mode) {
          _handleInputStatusChanged(status);
        }
      },
    );

    if (isClosed ||
        generation != _inputConfigurationGeneration ||
        state.inputMode != mode) {
      if (identical(_inputAdapter, adapter)) {
        _inputAdapter = null;
      }
      await adapter.stop();
      return;
    }

    if (!isClosed) {
      _emitState(_applyInputStatus(state));
    }

    if (!state.isPlaying) {
      return;
    }

    if (_isSongAudioEnabled) {
      _restartSongPlaybackFromCurrentPosition();
      return;
    }

    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());
  }

  Future<void> _teardownInputAdapter() async {
    final adapter = _inputAdapter;
    _inputAdapter = null;
    await adapter?.stop();
    _isInputReady = false;
    _inputStatusLabel = null;
    _latestDetectedInputMidis = const <int>{};
    if (!isClosed) {
      _emitState(
        _applyInputStatus(state.copyWith(activeInputMidis: const <int>{})),
      );
    }
  }

  void _handleInputStatusChanged(GameInputStatus status) {
    _isInputReady = status.isReady;
    _inputStatusLabel = status.label;
    if (!isClosed) {
      _emitState(_applyInputStatus(state));
    }
  }

  void _handleInputSnapshot(GameInputSnapshot snapshot) {
    _latestDetectedInputMidis = Set<int>.unmodifiable(snapshot.detectedMidis);
    if (state.activeInputMidis != snapshot.activeMidis) {
      _emitState(
        _applyInputStatus(
          state.copyWith(
            activeInputMidis: Set<int>.unmodifiable(snapshot.activeMidis),
          ),
        ),
      );
    }
    unawaited(_syncInputPreviewNotes(snapshot.detectedMidis));

    final score = state.score;
    if (!state.isPlaying || score == null || snapshot.detectedMidis.isEmpty) {
      return;
    }

    _judgeDetectedInputMidis(
      detectedMidis: snapshot.detectedMidis,
      currentMs: currentMs,
      score: score,
    );
  }

  void _judgeLatestHeldInputNotes(int currentMs) {
    final score = state.score;
    if (!state.isPlaying ||
        score == null ||
        _latestDetectedInputMidis.isEmpty ||
        state.inputMode == GameInputMode.microphone) {
      return;
    }

    final targetChord = _judgeEngine.nearestUnresolvedChordWithinWindow(
      currentMs: currentMs,
      passedNoteIndexes: state.passedNoteIndexes,
      missedNoteIndexes: state.missedNoteIndexes,
    );
    if (targetChord == null) {
      return;
    }

    final heldContinuationMidis = <int>{};
    for (final noteIndex in targetChord.noteIndexes) {
      if (state.passedNoteIndexes.contains(noteIndex) ||
          state.missedNoteIndexes.contains(noteIndex)) {
        continue;
      }
      final midi = score.notes[noteIndex].midi;
      if (_latestDetectedInputMidis.contains(midi) &&
          _hasPassedSameMidiBefore(score: score, noteIndex: noteIndex)) {
        heldContinuationMidis.add(midi);
      }
    }
    if (heldContinuationMidis.isEmpty) {
      return;
    }

    _judgeDetectedInputMidis(
      detectedMidis: heldContinuationMidis,
      currentMs: currentMs,
      score: score,
    );
  }

  bool _hasPassedSameMidiBefore({
    required ScoreData score,
    required int noteIndex,
  }) {
    final note = score.notes[noteIndex];
    for (var i = noteIndex - 1; i >= 0; i--) {
      final previous = score.notes[i];
      if (previous.hitTimeMs >= note.hitTimeMs) {
        continue;
      }
      if (previous.midi == note.midi) {
        final previousHeldThroughCurrent =
            previous.hitTimeMs + previous.holdMs + lateHitWindowMs >=
            note.hitTimeMs;
        return previousHeldThroughCurrent &&
            state.passedNoteIndexes.contains(i);
      }
    }
    return false;
  }

  void _judgeDetectedInputMidis({
    required Set<int> detectedMidis,
    required int currentMs,
    required ScoreData score,
  }) {
    final judgeCurrentMs = state.inputMode == GameInputMode.microphone
        ? currentMs + _microphoneLatencyMs
        : currentMs;
    final updatedPassed = _judgeEngine.judgeDetectedNotes(
      currentMs: judgeCurrentMs,
      score: score,
      passedNoteIndexes: state.passedNoteIndexes,
      missedNoteIndexes: state.missedNoteIndexes,
      detectedMidis: detectedMidis,
    );
    if (updatedPassed == null) {
      return;
    }

    final newlyPassedNoteIndexes = updatedPassed.difference(
      state.passedNoteIndexes,
    );
    if (newlyPassedNoteIndexes.isNotEmpty) {
      final passAnimationStartMsByNoteIndex = Map<int, int>.from(
        _passAnimationStartMsByNoteIndexNotifier.value,
      );
      for (final noteIndex in newlyPassedNoteIndexes) {
        passAnimationStartMsByNoteIndex[noteIndex] = currentMs;
      }
      _passAnimationStartMsByNoteIndexNotifier.value =
          Map<int, int>.unmodifiable(passAnimationStartMsByNoteIndex);
    }

    _emitState(
      _applyInputStatus(state.copyWith(passedNoteIndexes: updatedPassed)),
    );
  }

  Future<void> _syncInputPreviewNotes(Set<int> detectedMidis) async {
    if (state.inputMode == GameInputMode.microphone || !_isSynthReady) {
      await _silenceInputNotes();
      return;
    }

    final notesToStop = _activeInputNotes.difference(detectedMidis).toList();
    final notesToPlay = detectedMidis.difference(_activeInputNotes).toList();

    for (final note in notesToStop) {
      _activeInputNotes.remove(note);
      await _midiEngine.stopNote(
        note: note,
        velocity: 0,
        channel: _midiInputAudioChannel,
      );
    }

    for (final note in notesToPlay) {
      _activeInputNotes.add(note);
      await _midiEngine.playNote(
        note: note,
        velocity: _midiInputVelocityFallback,
        channel: _midiInputAudioChannel,
      );
    }
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
      _judgeEngine.loadScore(score);

      if (isClosed) {
        return;
      }

      _emitState(
        _applyInputStatus(
          state.copyWith(
            isLoading: false,
            clearErrorMessage: true,
            score: score,
            passedNoteIndexes: const <int>{},
            missedNoteIndexes: const <int>{},
            isSoundfontReady: _isSynthReady,
          ),
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _rebuildSongPlaybackEvents(score);
    } catch (error) {
      if (isClosed) {
        return;
      }

      _emitState(
        _applyInputStatus(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Khong tai duoc bai hat tu asset: $assetPath\n$error',
            isPlaying: false,
            isSoundfontReady: _isSynthReady,
          ),
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
      _judgeEngine.loadScore(score);

      if (isClosed) {
        return;
      }

      _emitState(
        _applyInputStatus(
          state.copyWith(
            isLoading: false,
            clearErrorMessage: true,
            score: score,
            passedNoteIndexes: const <int>{},
            missedNoteIndexes: const <int>{},
            isSoundfontReady: _isSynthReady,
          ),
        ),
      );

      _maxDurationMs = _computeMaxDurationMs(score);
      _rebuildSongPlaybackEvents(score);
    } catch (error) {
      if (isClosed) {
        return;
      }

      _emitState(
        _applyInputStatus(
          state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
            isPlaying: false,
            isSoundfontReady: _isSynthReady,
          ),
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
    _emitState(_applyInputStatus(state.copyWith(isPlaying: true)));
    _restartSongPlaybackFromCurrentPosition();
  }

  void play() => _play();

  void repeat() {
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());
    _baseElapsedMs = -initialLeadInMs;
    _elapsedMsNotifier.value = _baseElapsedMs;
    _nextMissScanIndex = 0;
    _nextSongPlaybackEventIndex = 0;
    _passAnimationStartMsByNoteIndexNotifier.value = const <int, int>{};
    _emitState(
      _applyInputStatus(
        state.copyWith(
          isPlaying: false,
          passedNoteIndexes: const <int>{},
          missedNoteIndexes: const <int>{},
        ),
      ),
    );
    _play();
  }

  void _pause() {
    if (!state.isPlaying) {
      return;
    }

    final anchoredCurrentMs = currentMs;
    _baseElapsedMs = anchoredCurrentMs;
    _elapsedMsNotifier.value = anchoredCurrentMs;
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());
    _emitState(_applyInputStatus(state.copyWith(isPlaying: false)));
  }

  void pause() => _pause();

  void togglePlayback() {
    if (state.isPlaying) {
      _pause();
      return;
    }
    _play();
  }

  void setInputMode(GameInputMode mode) {
    if (mode == state.inputMode) {
      return;
    }

    _emitState(_applyInputStatus(state.copyWith(inputMode: mode)));
    unawaited(_configureSelectedInputMode(mode));
  }

  void setAudioStaffMode(GameAudioStaffMode mode) {
    if (mode == state.audioStaffMode) {
      return;
    }

    _emitState(_applyInputStatus(state.copyWith(audioStaffMode: mode)));
    if (!_isSongAudioEnabled) {
      _stopSongPlaybackScheduler();
      unawaited(_silenceSongPlaybackNotes());
      return;
    }

    if (state.isPlaying) {
      _restartSongPlaybackFromCurrentPosition();
    }
  }

  void setVisibleStaffMode(GameVisibleStaffMode mode) {
    if (mode == state.visibleStaffMode) {
      return;
    }

    _emitState(_applyInputStatus(state.copyWith(visibleStaffMode: mode)));
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

    _emitState(_applyInputStatus(state.copyWith(playbackSpeed: clamped)));
    if (state.isPlaying && _isSongAudioEnabled) {
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
    _emitState(
      _applyInputStatus(
        state.copyWith(timelineMsPerDurationDivision: normalized),
      ),
    );
  }

  void _onTick(Duration _) {
    if (!state.isPlaying || state.score == null) {
      return;
    }

    final current = currentMs;
    if (_isSongAudioEnabled) {
      _pumpSongPlayback(current);
    }
    _judgeLatestHeldInputNotes(current);
    final updatedMisses = _updateMissesIncremental(current);

    if (current >= maxDurationMs) {
      _completePlayback();
      return;
    }

    if (_elapsedMsNotifier.value == current) {
      if (updatedMisses == null) {
        return;
      }
      _emitState(
        _applyInputStatus(state.copyWith(missedNoteIndexes: updatedMisses)),
      );
      return;
    }

    _elapsedMsNotifier.value = current;
    if (updatedMisses != null) {
      _emitState(
        _applyInputStatus(state.copyWith(missedNoteIndexes: updatedMisses)),
      );
    }
  }

  void _completePlayback() {
    _baseElapsedMs = maxDurationMs;
    _elapsedMsNotifier.value = maxDurationMs;
    _stopwatch
      ..stop()
      ..reset();
    _ticker.stop();
    _stopSongPlaybackScheduler();
    unawaited(_silenceSongPlaybackNotes());
    _emitState(_applyInputStatus(state.copyWith(isPlaying: false)));
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
  ValueListenable<Map<int, int>>
  get passAnimationStartMsByNoteIndexListenable =>
      _passAnimationStartMsByNoteIndexNotifier;

  int get maxDurationMs => _maxDurationMs;

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
      if (!_shouldPlayAudioStaff(note.staffNumber)) {
        continue;
      }
      final noteOnTimeMs = _songPlaybackStartMs(note);
      final noteOffTimeMs = _songPlaybackEndMs(note);
      events.add(
        _ScheduledMidiEvent(
          timeMs: noteOnTimeMs,
          midi: note.midi,
          staffNumber: note.staffNumber,
          token: i,
          type: _ScheduledMidiEventType.noteOn,
        ),
      );
      events.add(
        _ScheduledMidiEvent(
          timeMs: noteOffTimeMs,
          midi: note.midi,
          staffNumber: note.staffNumber,
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
        !_isSongAudioEnabled ||
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
      if (!_shouldPlayAudioStaff(note.staffNumber)) {
        continue;
      }
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
        !_isSongAudioEnabled ||
        state.score == null ||
        !_isSynthReady) {
      return;
    }

    final nowMs = currentOverrideMs ?? currentMs;
    final dispatchThresholdMs = nowMs + _songPlaybackDispatchLookaheadMs;
    while (_nextSongPlaybackEventIndex < _scheduledSongEvents.length) {
      final event = _scheduledSongEvents[_nextSongPlaybackEventIndex];
      if (event.timeMs > dispatchThresholdMs) {
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
    if (!_isSynthReady || !_shouldPlayAudioStaff(event.staffNumber)) {
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

  bool get _isSongAudioEnabled =>
      state.audioStaffMode != GameAudioStaffMode.off;

  bool _shouldPlayAudioStaff(int? staffNumber) {
    final resolvedStaff = staffNumber ?? 1;
    return switch (state.audioStaffMode) {
      GameAudioStaffMode.off => false,
      GameAudioStaffMode.upperOnly => resolvedStaff == 1,
      GameAudioStaffMode.lowerOnly => resolvedStaff == 2,
      GameAudioStaffMode.both => true,
    };
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
    await _teardownInputAdapter();
    if (_isSynthReady) {
      try {
        await _midiEngine.stopAllNotes();
        await _midiEngine.unloadSoundfont();
      } catch (_) {
        // Ignore teardown errors during disposal.
      }
    }
    _ticker.dispose();
    _stopwatch
      ..stop()
      ..reset();
    _elapsedMsNotifier.dispose();
    _passedNoteIndexesNotifier.dispose();
    _missedNoteIndexesNotifier.dispose();
    _passAnimationStartMsByNoteIndexNotifier.dispose();
    return super.close();
  }
}

enum _ScheduledMidiEventType { noteOn, noteOff }

class _ScheduledMidiEvent {
  const _ScheduledMidiEvent({
    required this.timeMs,
    required this.midi,
    required this.staffNumber,
    required this.token,
    required this.type,
  });

  final int timeMs;
  final int midi;
  final int? staffNumber;
  final int token;
  final _ScheduledMidiEventType type;
}
