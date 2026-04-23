import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';

import '../../presentation/cubit/game_prototype_state.dart';
import 'game_input_adapter.dart';

class MidiGameInputAdapter implements GameInputAdapter {
  MidiGameInputAdapter({MidiCommand? midiCommand})
    : _midiCommand = midiCommand ?? MidiCommand();

  final MidiCommand _midiCommand;

  StreamSubscription<MidiPacket>? _midiSub;
  StreamSubscription<String>? _midiSetupSub;
  MidiDevice? _connectedInputDevice;
  final Set<int> _activeInputNotes = <int>{};
  bool _isBluetoothScanActive = false;
  bool _isStarted = false;
  int _connectionGeneration = 0;
  GameInputSnapshotCallback? _onSnapshot;
  GameInputStatusCallback? _onStatusChanged;
  GameInputMode _inputMode = GameInputMode.wiredMidi;

  @override
  Future<void> start({
    required GameInputMode inputMode,
    required GameInputSnapshotCallback onSnapshot,
    required GameInputStatusCallback onStatusChanged,
  }) async {
    _inputMode = inputMode;
    _onSnapshot = onSnapshot;
    _onStatusChanged = onStatusChanged;
    _isStarted = true;
    final generation = ++_connectionGeneration;

    try {
      if (_inputMode == GameInputMode.bluetoothMidi) {
        await _midiCommand.startBluetoothCentral();
        await _midiCommand.waitUntilBluetoothIsInitialized();
        await _midiCommand.startScanningForBluetoothDevices();
        _isBluetoothScanActive = true;
      }

      if (!_isCurrentGeneration(generation)) {
        return;
      }

      await _connectPreferredMidiInputDevice(generation);
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      _midiSetupSub = _midiCommand.onMidiSetupChanged?.listen((_) {
        _connectPreferredMidiInputDevice(generation);
      });
      _midiSub = _midiCommand.onMidiDataReceived?.listen(_handleMidiPacket);
    } catch (error) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      debugPrint('MIDI input init failed: $error');
      _emitStatus(const GameInputStatus(isReady: false));
    }
  }

  @override
  Future<void> stop() async {
    _isStarted = false;
    _connectionGeneration++;
    await _midiSub?.cancel();
    _midiSub = null;
    await _midiSetupSub?.cancel();
    _midiSetupSub = null;

    if (_isBluetoothScanActive) {
      _midiCommand.stopScanningForBluetoothDevices();
      _isBluetoothScanActive = false;
    }

    if (_connectedInputDevice != null) {
      _midiCommand.disconnectDevice(_connectedInputDevice!);
    }
    _midiCommand.teardown();
    _connectedInputDevice = null;
    _activeInputNotes.clear();
    _emitSnapshot();
    _emitStatus(const GameInputStatus(isReady: false));
  }

  Future<void> _connectPreferredMidiInputDevice(int generation) async {
    if (!_isCurrentGeneration(generation)) {
      return;
    }

    try {
      final devices = await _midiCommand.devices ?? const <MidiDevice>[];
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      final target = _selectPreferredMidiInputDevice(devices);
      if (target == null) {
        if (_connectedInputDevice != null) {
          _midiCommand.disconnectDevice(_connectedInputDevice!);
        }
        _connectedInputDevice = null;
        _emitStatus(const GameInputStatus(isReady: false));
        return;
      }

      if (_connectedInputDevice?.id == target.id) {
        _emitStatus(
          GameInputStatus(isReady: true, label: _connectedInputDevice?.name),
        );
        return;
      }

      if (_connectedInputDevice != null) {
        _midiCommand.disconnectDevice(_connectedInputDevice!);
      }
      await _midiCommand.connectToDevice(target);
      if (!_isCurrentGeneration(generation)) {
        _midiCommand.disconnectDevice(target);
        return;
      }
      _connectedInputDevice = target;
      _emitStatus(GameInputStatus(isReady: true, label: target.name));
    } catch (error) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      _connectedInputDevice = null;
      debugPrint('MIDI connect failed: $error');
      _emitStatus(const GameInputStatus(isReady: false));
    }
  }

  bool _isCurrentGeneration(int generation) {
    return _isStarted && generation == _connectionGeneration;
  }

  MidiDevice? _selectPreferredMidiInputDevice(List<MidiDevice> devices) {
    final preferred = devices
        .where((device) => device.inputPorts.isNotEmpty)
        .where(_deviceMatchesSelectedInputMode)
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

  bool _deviceMatchesSelectedInputMode(MidiDevice device) {
    final type = device.type.trim().toLowerCase();
    return switch (_inputMode) {
      GameInputMode.wiredMidi => type == 'native',
      GameInputMode.bluetoothMidi => type == 'ble' || type == 'bonded',
      GameInputMode.microphone => false,
    };
  }

  void _handleMidiPacket(MidiPacket packet) {
    if (packet.data.length < 3) {
      return;
    }

    if (_connectedInputDevice != null &&
        packet.device.id != _connectedInputDevice!.id) {
      return;
    }

    final data = packet.data;
    final status = data[0] & 0xF0;
    final note = data[1];
    final velocity = data[2];

    if (status == 0x90 && velocity > 0) {
      _activeInputNotes.add(note);
      _emitSnapshot();
      return;
    }

    if (status == 0x80 || (status == 0x90 && velocity == 0)) {
      _activeInputNotes.remove(note);
      _emitSnapshot();
    }
  }

  void _emitSnapshot() {
    _onSnapshot?.call(
      GameInputSnapshot(
        detectedMidis: Set<int>.from(_activeInputNotes),
      ),
    );
  }

  void _emitStatus(GameInputStatus status) {
    _onStatusChanged?.call(status);
  }
}
