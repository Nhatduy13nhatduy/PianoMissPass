import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    final dotenvValue = _dotenvValueForPlatform();
    if (dotenvValue.isNotEmpty) {
      return dotenvValue;
    }

    if (kIsWeb) {
      return 'https://localhost:7245';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5250';
      default:
        return 'https://localhost:7245';
    }
  }

  static String _dotenvValueForPlatform() {
    if (kIsWeb) {
      return dotenv.env['API_BASE_URL_WEB'] ?? dotenv.env['API_BASE_URL'] ?? '';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return dotenv.env['API_BASE_URL_ANDROID'] ??
            dotenv.env['API_BASE_URL'] ??
            '';
      case TargetPlatform.iOS:
        return dotenv.env['API_BASE_URL_IOS'] ??
            dotenv.env['API_BASE_URL'] ??
            '';
      case TargetPlatform.macOS:
        return dotenv.env['API_BASE_URL_MACOS'] ??
            dotenv.env['API_BASE_URL'] ??
            '';
      case TargetPlatform.linux:
        return dotenv.env['API_BASE_URL_LINUX'] ??
            dotenv.env['API_BASE_URL'] ??
            '';
      case TargetPlatform.windows:
        return dotenv.env['API_BASE_URL_WINDOWS'] ??
            dotenv.env['API_BASE_URL'] ??
            '';
      case TargetPlatform.fuchsia:
        return dotenv.env['API_BASE_URL'] ?? '';
    }
  }
}
