import 'package:dio/dio.dart';

import '../../../../core/constants/api_routes.dart';
import '../models/auth_tokens_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokensModel> login({
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<AuthTokensModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiRoutes.login,
      data: {'email': email, 'password': password},
    );

    return AuthTokensModel.fromJson(response.data as Map<String, dynamic>);
  }
}
