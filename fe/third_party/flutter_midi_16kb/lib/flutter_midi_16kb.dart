import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlutterMidi16kb {
  static const MethodChannel _channel = MethodChannel('flutter_midi_16kb');
  static bool _initialized = false;

  static Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _initialized = result ?? false;
      return _initialized;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing: $e');
      }
      return false;
    }
  }

  static Future<bool> loadSoundfont(String path) async {
    if (!_initialized) await initialize();
    try {
      final result = await _channel.invokeMethod<bool>('loadSoundfont', {'path': path});
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading soundfont: $e');
      }
      return false;
    }
  }

  static Future<bool> unloadSoundfont() async {
    try {
      final result = await _channel.invokeMethod<bool>('unloadSoundfont');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error unloading soundfont: $e');
      }
      return false;
    }
  }

  static Future<void> playNote({int channel = 0, required int key, int velocity = 100}) async {
    if (!_initialized) await initialize();
    try {
      await _channel.invokeMethod('playNote', {'channel': channel, 'key': key, 'velocity': velocity});
    } catch (e) {
      if (kDebugMode) {
        print('Error playing note: $e');
      }
    }
  }

  static Future<void> stopNote({int channel = 0, required int key}) async {
    try {
      await _channel.invokeMethod('stopNote', {'channel': channel, 'key': key});
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping note: $e');
      }
    }
  }

  static Future<void> stopAllNotes() async {
    try {
      await _channel.invokeMethod('stopAllNotes');
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping all notes: $e');
      }
    }
  }

  static Future<void> changeProgram({int channel = 0, required int program}) async {
    try {
      await _channel.invokeMethod('changeProgram', {'channel': channel, 'program': program});
    } catch (e) {
      if (kDebugMode) {
        print('Error changing program: $e');
      }
    }
  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _initialized = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing: $e');
      }
    }
  }
}
