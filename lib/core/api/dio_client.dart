import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

Dio buildDio({required AuthInterceptor authInterceptor}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      // Assim como o navegador, reaproveita a conexão HTTPS. O `idleTimeout`
      // abaixo ainda remove sockets ociosos antes de eles ficarem inválidos.
      persistentConnection: true,
      // Não envia Content-Type em GETs; o Axios do site também não o envia.
      headers: {'Accept': 'application/json'},
    ),
  );

  // Descarta conexões ociosas antes do proxy do Fly.io fazer isso por nós —
  // é o que evita reutilizar socket morto e tomar "connection reset by peer".
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient()
      ..idleTimeout = AppConstants.httpIdleTimeout
      ..connectionTimeout = AppConstants.connectTimeout
      // Sem este limite o Dart abre uma conexão por requisição pendente.
      ..maxConnectionsPerHost = AppConstants.maxConnectionsPerHost;

    // Em debug, ignora certificado autoassinado do servidor local.
    assert(() {
      client.badCertificateCallback = (_, __, ___) => true;
      return true;
    }());

    return client;
  };

  dio.interceptors.add(authInterceptor);
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      logPrint: (message) {
        assert(() {
          _log.w(message);
          return true;
        }());
      },
    ),
  );

  // Log only in debug builds.
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        // Cabeçalhos e corpos podem conter Bearer token, senha e refresh token.
        // Para diagnóstico bastam método/URL/status e a exceção.
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => _log.d(obj),
      ),
    );
    return true;
  }());

  return dio;
}
