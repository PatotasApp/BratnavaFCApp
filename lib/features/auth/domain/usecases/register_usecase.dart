import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<void> call({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) =>
      _repository.register(
        userName: userName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
}
