import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

class DioClient {
  final TokenStorage _tokenStorage;
  late final Dio _dio;

  DioClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(AuthInterceptor(_tokenStorage));
  }

  Dio get instance => _dio;
}
