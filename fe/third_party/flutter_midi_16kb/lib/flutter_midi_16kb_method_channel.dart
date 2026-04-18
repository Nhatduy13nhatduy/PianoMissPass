import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_midi_16kb_platform_interface.dart';

/// An implementation of [FlutterMidi16kbPlatform] that uses method channels.
class MethodChannelFlutterMidi16kb extends FlutterMidi16kbPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_midi_16kb');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
