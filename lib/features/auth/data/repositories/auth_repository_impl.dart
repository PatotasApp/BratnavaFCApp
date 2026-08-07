import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;

  const AuthRepositoryImpl(this._remote);

  @override
  Future<Account> login({
    required String email,
    required String password,
  }) =>
      _remote.login(email: email, password: password);

  @override
  Future<void> register({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) =>
      _remote.register(
        userName: userName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
}
