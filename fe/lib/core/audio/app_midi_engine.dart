import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_16kb/flutter_midi_16kb.dart';
import 'package:path_provider/path_provider.dart';

class AppMidiEngine {
  AppMidiEngine();

  final Set<int> _activeNotes = <int>{};
  bool _isSoundfontLoaded = false;

  bool get _supportsNativeMidi => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> unmute() async {
    // This backend does not require an explicit unmute step.
  }

  Future<bool> loadSoundfontFromAsset(
    String assetPath, {
    String? fileName,
  }) async {
    if (!_supportsNativeMidi) {
      debugPrint('MIDI synth is not available on this platform.');
      return false;
    }

    try {
      final byteData = await rootBundle.load(assetPath);
      final soundfontFile = await _writeAssetToTempFile(
        byteData,
        fileName ?? assetPath.split('/').last,
      );
      if (soundfontFile == null) {
        return false;
      }

      await FlutterMidi16kb.loadSoundfont(soundfontFile.path);
      _isSoundfontLoaded = true;
      return true;
    } catch (error) {
      debugPrint('Native MIDI synth load failed: $error');
      _isSoundfontLoaded = false;
      return false;
    }
  }

  Future<bool> unloadSoundfont() async {
    if (!_supportsNativeMidi) {
      return true;
    }

    if (!_isSoundfontLoaded) {
      return true;
    }

    try {
      await FlutterMidi16kb.stopAllNotes();
      await FlutterMidi16kb.unloadSoundfont();
      _isSoundfontLoaded = false;
      _activeNotes.clear();
      return true;
    } catch (error) {
      debugPrint('Native MIDI synth unload failed: $error');
      return false;
    }
  }

  Future<void> playNote({
    required int note,
    int velocity = 64,
    int channel = 0,
  }) async {
    if (!_supportsNativeMidi) {
      return;
    }

    if (!_isSoundfontLoaded) {
      return;
    }

    await FlutterMidi16kb.playNote(
      channel: channel,
      key: note,
      velocity: velocity,
    );
    _activeNotes.add(note);
  }

  Future<void> stopNote({
    required int note,
    int velocity = 64,
    int channel = 0,
  }) async {
    if (!_supportsNativeMidi) {
      return;
    }

    if (!_isSoundfontLoaded) {
      return;
    }

    await FlutterMidi16kb.stopNote(channel: channel, key: note);
    _activeNotes.remove(note);
  }

  Future<void> changeProgram({
    required int program,
    int channel = 0,
  }) async {
    if (!_supportsNativeMidi) {
      return;
    }

    try {
      await FlutterMidi16kb.changeProgram(
        channel: channel,
        program: program,
      );
    } catch (_) {
      // The Android fallback may expose a smaller control surface.
    }
  }

  Future<void> setVolume({
    required int volume,
    int channel = 0,
  }) async {}

  Future<void> setPan({
    required int pan,
    int channel = 0,
  }) async {}

  Future<void> stopAllNotes() async {
    if (!_supportsNativeMidi) {
      return;
    }

    await FlutterMidi16kb.stopAllNotes();
    _activeNotes.clear();
  }

  Future<File?> _writeAssetToTempFile(ByteData data, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await file.writeAsBytes(bytes);
      return file;
    } catch (error) {
      debugPrint('Failed to cache soundfont asset: $error');
      return null;
    }
  }
}
