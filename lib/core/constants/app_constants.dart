import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String productionApiUrl = 'https://production-env.fly.dev';
  static const String developmentApiUrl = 'https://development-env.fly.dev';

  /// Permite sobrescrever o endpoint sem alterar o código, por exemplo:
  /// `flutter run --dart-define=API_URL=https://localhost:44356`.
  static const String _apiUrlOverride = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  /// Release aponta para produção; debug e profile apontam para desenvolvimento.
  static String get apiUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    return kReleaseMode ? productionApiUrl : developmentApiUrl;
  }

  static String get environmentName =>
      kReleaseMode ? 'production' : 'development';

  static const String accountsStorageKey = 'patotas.accounts.v2';
  static const String activeAccountKey = 'patotas.activeAccountId';
  static const String themeStorageKey = 'patotas-theme';

  /// A API roda no Fly.io com autostop: quando a máquina está parada, a primeira
  /// requisição paga o cold start (subir a VM + iniciar o runtime). O TCP costuma
  /// conectar rápido — quem demora é a resposta —, por isso o `receive` é o mais
  /// folgado. Estes valores se combinam com o RetryInterceptor: no pior caso são
  /// 3 tentativas, então esticar demais o connect trava a tela por minutos.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 60);

  /// Menor que o tempo em que o proxy do Fly.io derruba conexões ociosas, para
  /// o pool local não guardar socket morto e tomar "connection reset by peer".
  static const Duration httpIdleTimeout = Duration(seconds: 10);

  /// O `HttpClient` do Dart não limita conexões por host por padrão. No startup
  /// o app dispara ~12 requisições de uma vez (providers da Dashboard + shell),
  /// e abrir 12 conexões TCP+TLS simultâneas faz o proxy do Fly.io derrubar as
  /// excedentes — daí o "connection reset by peer" em algumas e não em outras.
  ///
  /// O navegador nunca faz isso: em HTTP/1.1 ele limita a 6 por host, e em
  /// HTTP/2 usa uma conexão só com streams multiplexados. É por isso que o site
  /// carrega na hora e o app não. 6 replica o comportamento do navegador.
  static const int maxConnectionsPerHost = 6;
}
