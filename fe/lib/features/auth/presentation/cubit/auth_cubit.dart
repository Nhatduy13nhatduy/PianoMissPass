import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/usecases/login_use_case.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;

  AuthCubit(this._loginUseCase) : super(const AuthInitial());

  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());

    final result = await _loginUseCase(email: email, password: password);

    switch (result) {
      case Success<AuthTokens>():
        emit(const AuthSuccess());
      case Failure<AuthTokens>(:final message):
        emit(AuthError(message));
    }
  }
}
