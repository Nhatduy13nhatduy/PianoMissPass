import 'package:dio/dio.dart';

import '../../../../core/result/result.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  @override
  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      if (result.accessToken.isEmpty || result.refreshToken.isEmpty) {
        return const Failure<AuthTokens>('Login response khong hop le.');
      }

      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      return Success<AuthTokens>(result);
    } on DioException catch (e) {
      final responseMessage = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['message'] as String?)
          : null;
      return Failure<AuthTokens>(responseMessage ?? 'Dang nhap that bai.');
    } catch (_) {
      return const Failure<AuthTokens>(
        'Co loi xay ra trong qua trinh dang nhap.',
      );
    }
  }
}
