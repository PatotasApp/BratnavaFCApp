import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Reenvia requisições que falharam por erro de conexão.
///
/// O caso que motivou isto: o Dart mantém um pool de conexões HTTP keep-alive.
/// Quando o app fica em segundo plano, o socket morre do outro lado (proxy do
/// Fly.io encerrando conexões ociosas, ou o próprio Android derrubando o socket
/// em Doze), mas o pool local não percebe. Na primeira requisição após o resume
/// o Dart reutiliza esse socket morto e o servidor responde com RST —
/// `SocketException: Connection reset by peer (errno = 104)`.
///
/// Reenviar resolve porque a segunda tentativa abre uma conexão nova. Também
/// cobre o cold start do Fly: se a máquina estava parada, a primeira tentativa
/// pode falhar enquanto a VM sobe.
class RetryInterceptor extends Interceptor {
  /// Marque uma requisição com `extra: {RetryInterceptor.skipRetryKey: true}`
  /// para desativar o reenvio (útil em POSTs não idempotentes).
  static const String skipRetryKey = 'skipRetry';
  static const String _attemptKey = 'retryAttempt';

  final Dio dio;
  final int maxAttempts;
  final List<Duration> backoff;
  final void Function(String message)? logPrint;

  RetryInterceptor({
    required this.dio,
    this.maxAttempts = 4,
    this.backoff = const [
      Duration(milliseconds: 750),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.logPrint,
  });

  /// Só reenvia o que é seguro repetir. POST/PATCH ficam de fora por padrão:
  /// se a primeira tentativa chegou ao servidor, repetir criaria registro duplicado.
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  bool _isRetriable(DioException err) {
    if (err.requestOptions.extra[skipRetryKey] == true) return false;

    final method = err.requestOptions.method.toUpperCase();
    if (!_idempotentMethods.contains(method)) return false;

    // Corpo em stream não pode ser reenviado — já foi consumido.
    if (err.requestOptions.data is Stream) return false;

    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return true;
      case DioExceptionType.unknown:
        // "Connection reset by peer", "Software caused connection abort",
        // "Connection closed before full header was received".
        return err.error is SocketException || err.error is HttpException;
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isRetriable(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (attempt >= maxAttempts - 1) {
      logPrint?.call(
        'Retry esgotado após $maxAttempts tentativas: ${options.method} ${options.path}',
      );
      handler.next(err);
      return;
    }

    final delay = attempt < backoff.length ? backoff[attempt] : backoff.last;
    logPrint?.call(
      'Reenviando (${attempt + 2}/$maxAttempts) em ${delay.inMilliseconds}ms: '
      '${options.method} ${options.path} — ${err.error ?? err.type}',
    );
    await Future<void>.delayed(delay);

    options.extra = {...options.extra, _attemptKey: attempt + 1};

    try {
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
