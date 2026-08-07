import 'dart:convert';
import 'package:flutter/foundation.dart';

class JwtHelper {
  JwtHelper._();

  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');

      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64.decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String? getUserId(String token) => decode(token)?['sub'] as String?;

  /// Lê roles do claim "role", "roles" ou do ClaimTypes.Role do ASP.NET Identity.
  static List<String> getRoles(String token) {
    final payload = decode(token);
    if (payload == null) return [];

    const msRoleClaim =
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

    // Tenta todas as variações conhecidas do claim de roles.
    final raw = payload['role'] ?? payload['roles'] ?? payload[msRoleClaim];

    if (raw == null) {
      // Imprime o payload completo para diagnóstico caso não encontre roles.
      debugPrint(
          '⚠ JwtHelper — nenhum claim de role encontrado. Claims: ${payload.keys.toList()}');
      return [];
    }
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [raw.toString()];
  }

  /// Retorna true se o token expira nos próximos [bufferSeconds] segundos.
  static bool isExpiring(String token, {int bufferSeconds = 60}) {
    final payload = decode(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp == null) return true;

    final expDate = DateTime.fromMillisecondsSinceEpoch(
      (exp as int) * 1000,
    );
    return DateTime.now()
        .isAfter(expDate.subtract(Duration(seconds: bufferSeconds)));
  }

  /// Retorna true se o token já expirou.
  static bool isExpired(String token) {
    final payload = decode(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return false;
    return DateTime.now().isAfter(
      DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000),
    );
  }

  /// Retorna o DateTime de expiração do token, ou null se não disponível.
  static DateTime? expiresAt(String token) {
    final payload = decode(token);
    final exp = payload?['exp'];
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
  }
}
