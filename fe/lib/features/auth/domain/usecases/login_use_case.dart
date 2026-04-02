import '../../../../core/result/result.dart';
import '../entities/auth_tokens.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Result<AuthTokens>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}
