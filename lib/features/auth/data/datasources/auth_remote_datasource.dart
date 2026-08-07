import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/auth/jwt_helper.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/account.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSource(this._dio);

  Future<Account> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.login,
        data: {'username': email, 'password': password},
      );

      final envelope = res.data as Map<String, dynamic>;

      // A API retorna { success, data: { token, refreshToken }, ... }
      // Suporta resposta com envelope e sem envelope.
      final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;

      // Extrai tokens com fallbacks.
      final access =
          (data['token'] ?? data['accessToken'] ?? data['jwt']) as String?;
      final refresh = (data['refreshToken'] ?? data['refresh']) as String?;

      if (access == null || refresh == null) {
        throw const AppException('Token não encontrado na resposta.');
      }

      // Extrai userId do JWT sub ou do campo user.
      final userId = JwtHelper.getUserId(access) ??
          (data['user'] as Map?)?['id'] as String? ??
          (data['user'] as Map?)?['userId'] as String? ??
          '';

      if (userId.isEmpty) {
        throw const AppException('ID do usuário não encontrado no token.');
      }

      final roles = JwtHelper.getRoles(access);
      final payload = JwtHelper.decode(access) ?? {};

      // Tenta pegar nome/email do campo user (se vier), senão usa claims do JWT.
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final name = (user['firstName'] != null
              ? '${user['firstName']} ${user['lastName'] ?? ''}'.trim()
              : null) ??
          payload['name'] as String? ??
          payload['unique_name'] as String? ??
          '';
      final emailR =
          (user['email'] as String?) ?? payload['email'] as String? ?? email;

      return Account(
        userId: userId,
        name: name.isEmpty ? emailR : name,
        email: emailR,
        roles: roles,
        accessToken: access,
        refreshToken: refresh,
      );
    } on DioException catch (e) {
      throw ServerException(extractDioError(e),
          statusCode: e.response?.statusCode);
    }
  }

  Future<void> register({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post(
        ApiConstants.users,
        data: {
          'userName': userName,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw ServerException(extractDioError(e),
          statusCode: e.response?.statusCode);
    }
  }

  /// Busca os grupos onde o usuário é admin ou financeiro para pré-popular o store.
  ///
  /// Devolve `null` quando a consulta falha. É diferente de devolver listas
  /// vazias: vazio significa "não é admin de nada" e apagaria a permissão que já
  /// estava salva — bastava uma queda de rede no resume para o usuário perder o
  /// acesso de admin até reiniciar o app.
  Future<Map<String, List<String>>?> fetchGroupRoles(String userId) async {
    try {
      final results = await Future.wait([
        _dio.get(ApiConstants.groupsByAdmin(userId)),
        _dio.get(ApiConstants.groupsByFinanceiro(userId)),
      ]);

      List<String> extractIds(Response r) {
        return unwrapList(r.data)
            .map((e) =>
                (e as Map<String, dynamic>)['id'] as String? ??
                (e)['groupId'] as String? ??
                '')
            .where((id) => id.isNotEmpty)
            .toList();
      }

      return {
        'adminIds': extractIds(results[0]),
        'financeiroIds': extractIds(results[1]),
      };
    } catch (_) {
      return null;
    }
  }

  /// Verifica se o usuário logado é admin e/ou financeiro de um grupo específico.
  ///
  /// Devolve `null` em caso de falha — ver a justificativa em [fetchGroupRoles].
  Future<({bool isAdmin, bool isFinanceiro})?> fetchMyGroupRoles(
      String groupId) async {
    try {
      final res = await _dio.get(ApiConstants.myGroupRoles(groupId));
      final data = (res.data as Map<String, dynamic>?)?['data']
              as Map<String, dynamic>? ??
          {};
      return (
        isAdmin: data['isAdmin'] == true,
        isFinanceiro: data['isFinanceiro'] == true
      );
    } catch (_) {
      return null;
    }
  }

  /// Retorna os groupIds distintos dos jogadores do usuário logado.
  Future<List<String>> fetchMyGroupIds() async {
    try {
      final res = await _dio.get(ApiConstants.playersMe);
      return unwrapList(res.data)
          .map((e) => (e as Map<String, dynamic>)['groupId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
