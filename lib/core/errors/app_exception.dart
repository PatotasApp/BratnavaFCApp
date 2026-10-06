class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Sessão expirada. Faça login novamente.',
  ]) : super(statusCode: 401);
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Patota citada pelo backend como bloqueio para a exclusão da conta.
///
/// Só o par id/nome interessa: a tela precisa apenas nomear onde a pessoa tem
/// de promover outro administrador.
class PendingAdminGroup {
  final String groupId;
  final String groupName;

  const PendingAdminGroup({required this.groupId, required this.groupName});
}

/// 409 do `DELETE /api/Users/me`: a conta não pode ser apagada enquanto a
/// pessoa for a ÚNICA administradora de alguma patota — apagá-la deixaria essas
/// patotas sem ninguém capaz de administrá-las.
///
/// Carrega [groups] porque a mensagem do servidor só diz *quantas* patotas
/// bloqueiam; sem a lista a pessoa não saberia em quais agir.
class SoleAdminGroupsException extends AppException {
  final List<PendingAdminGroup> groups;

  const SoleAdminGroupsException(super.message, {required this.groups})
      : super(statusCode: 409);
}

/// Extrai mensagem legível de um DioException ou Exception simples.
String extractDioError(dynamic e,
    [String fallback = 'Ocorreu um erro inesperado.']) {
  // Plain Exception(msg) thrown by _throwIfError soft-error helpers
  if (e is Exception) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) {
      final msg = s.substring(11);
      if (msg.isNotEmpty) return msg;
    }
  }

  try {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;

      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = (errors.values.first as List?)?.first as String?;
        if (first != null) return first;
      }
      final raw = data['error'] as String?;
      if (raw != null && raw.isNotEmpty) return raw.split('\n').first;
    }
    if (data is String && data.isNotEmpty) return data.split('\n').first;
  } catch (_) {}

  try {
    return e.message as String? ?? fallback;
  } catch (_) {
    return fallback;
  }
}
