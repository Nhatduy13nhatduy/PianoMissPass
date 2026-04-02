import '../../../../core/result/result.dart';
import '../entities/auth_tokens.dart';

abstract class AuthRepository {
  Future<Result<AuthTokens>> login({
    required String email,
    required String password,
  });
}
