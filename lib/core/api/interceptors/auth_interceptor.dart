import 'package:dio/dio.dart';

import '../../auth/firebase_auth_service.dart';

typedef VoidAsync = Future<void> Function();

/// Anexa o ID token do Firebase a cada request e trata o 401.
///
/// Toda a máquina que existia aqui — Dio dedicado para refresh, mutex de
/// chamadas concorrentes, leitura de `exp` do JWT e POST em
/// `/api/Authentication/refresh-token` — foi removida. O SDK renova o ID token
/// sozinho a cada ~55 min e `getIdToken()` já devolve um token válido,
/// renovando de forma transparente. O endpoint de refresh não existe mais na
/// API.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.authService,
    required this.onUnauthorized,
  });

  static const skipUnauthorizedKey = 'skipUnauthorized';

  /// Marca uma request já reenviada, para não entrar em laço de retry.
  static const _retriedKey = 'authRetried';

  final FirebaseAuthService authService;
  final VoidAsync onUnauthorized;

  /// Impede que um estouro de 401s simultâneos dispare vários logouts.
  bool _isHandlingUnauthorized = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await authService.idToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final options = err.requestOptions;

    // Requests marcadas (ex.: registro de token push) não devem deslogar
    // ninguém — devolvem o erro e quem chamou decide o que fazer.
    if (options.extra[skipUnauthorizedKey] == true) {
      return handler.reject(err);
    }

    if (_isHandlingUnauthorized) {
      return handler.reject(err);
    }

    // Uma única retentativa com token novo. Cobre a janela em que o token
    // expirou entre o envio e a chegada, e o caso das custom claims recém
    // gravadas pelo backend.
    if (options.extra[_retriedKey] != true) {
      final refreshed = await authService.idToken(forceRefresh: true);

      if (refreshed != null) {
        try {
          options
            ..extra[_retriedKey] = true
            ..headers['Authorization'] = 'Bearer $refreshed';

          final retried = await Dio(
            BaseOptions(
              baseUrl: options.baseUrl,
              connectTimeout: options.connectTimeout,
              receiveTimeout: options.receiveTimeout,
              sendTimeout: options.sendTimeout,
            ),
          ).fetch<dynamic>(options);

          return handler.resolve(retried);
        } catch (_) {
          // Cai no tratamento de sessão inválida abaixo.
        }
      }
    }

    // 401 que sobreviveu ao token novo é sessão inválida de verdade.
    if (!_isHandlingUnauthorized) {
      _isHandlingUnauthorized = true;
      await onUnauthorized();
    }

    return handler.reject(err);
  }

  /// Libera o guard depois de um login bem-sucedido.
  void resetUnauthorizedGuard() => _isHandlingUnauthorized = false;
}
