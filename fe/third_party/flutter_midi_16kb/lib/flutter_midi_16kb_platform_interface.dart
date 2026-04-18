import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_midi_16kb_method_channel.dart';

abstract class FlutterMidi16kbPlatform extends PlatformInterface {
  /// Constructs a FlutterMidi16kbPlatform.
  FlutterMidi16kbPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterMidi16kbPlatform _instance = MethodChannelFlutterMidi16kb();

  /// The default instance of [FlutterMidi16kbPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterMidi16kb].
  static FlutterMidi16kbPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterMidi16kbPlatform] when
  /// they register themselves.
  static set instance(FlutterMidi16kbPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
