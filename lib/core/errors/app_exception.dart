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
