import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_response.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/account.dart';

/// Acesso ao perfil e às permissões do usuário logado.
///
/// Não há mais `login` nem `register`: a API deletou esses endpoints, e quem
/// autentica é o SDK do Firebase. O que restou é ler quem o backend diz que
/// somos.
class AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSource(this._dio);

  /// Espelha `UserRole` no backend. GodMode não é traduzido de propósito — é
  /// função administrativa da plataforma, do site, e não existe no aplicativo.
  static const Map<int, String> _roleNames = {1: 'User', 2: 'Admin'};

  /// `GET /api/users/me` — provisiona o usuário no primeiro acesso e devolve a
  /// identidade INTERNA.
  ///
  /// Este é o único lugar de onde o `userId` pode vir. Derivá-lo do token daria
  /// o UID do Firebase, que não é FK de nada no banco.
  Future<Account> fetchMe() async {
    try {
      final res = await _dio.get(ApiConstants.usersMe);

      final envelope = res.data as Map<String, dynamic>;
      final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;

      final userId = (data['id'] ?? data['userId'])?.toString() ?? '';

      if (userId.isEmpty) {
        throw const AppException('O perfil não veio com identificador.');
      }

      final firstName = (data['firstName'] as String?)?.trim() ?? '';
      final lastName = (data['lastName'] as String?)?.trim() ?? '';
      final userName = (data['userName'] as String?)?.trim() ?? '';
      final email = (data['email'] as String?)?.trim() ?? '';

      final fullName = '$firstName $lastName'.trim();

      return Account(
        userId: userId,
        name: fullName.isNotEmpty
            ? fullName
            : (userName.isNotEmpty ? userName : email),
        email: email,
        roles: _parseRoles(data['role']),
        // URL absoluta do bucket público; nula quando o usuário não tem foto.
        photoUrl: (data['photoUrl'] as String?)?.trim().isNotEmpty == true
            ? (data['photoUrl'] as String).trim()
            : null,
      );
    } on DioException catch (e) {
      throw ServerException(
        extractDioError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// `PUT /api/users/me` — edição do próprio perfil.
  ///
  /// E-mail não entra: é read-only na API, gerenciado no Firebase, e tem fluxo
  /// próprio com confirmação no endereço novo. Campo ausente MANTÉM o valor
  /// atual, então enviar só o que mudou é seguro.
  ///
  /// O backend sincroniza DisplayName e telefone no Firebase e faz rollback do
  /// SQL se a chamada falhar — uma falha aqui é falha de salvamento inteira,
  /// não parcial.
  Future<void> updateMe({
    String? firstName,
    String? lastName,
    String? userName,
    String? phone,
    DateTime? birthDate,
  }) async {
    try {
      await _dio.put(ApiConstants.usersMe, data: {
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
        if (userName != null && userName.isNotEmpty) 'userName': userName,
        'phone': (phone == null || phone.isEmpty) ? null : phone,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
      });
    } on DioException catch (e) {
      throw ServerException(
        extractDioError(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// A role chega como inteiro do enum. Aceita string por robustez, caso o
  /// backend passe a usar `JsonStringEnumConverter`.
  static List<String> _parseRoles(Object? raw) {
    if (raw is int) {
      final name = _roleNames[raw];
      return name == null ? const [] : [name];
    }

    if (raw is String) {
      final normalized = raw.trim();
      if (normalized.isEmpty) return const [];
      if (normalized.toLowerCase() == 'godmode') return const [];
      return [normalized];
    }

    return const [];
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
