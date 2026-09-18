class AppConstants {
  AppConstants._();

  // ── Configuração de ambiente ────────────────────────────────────────────────
  //
  // Tudo aqui vem de `--dart-define-from-file=config/<env>.json`, que precisa
  // acompanhar o `--flavor`: o flavor decide qual `google-services.json` entra
  // no APK, e a API valida o audience do ID token contra o próprio projeto
  // Firebase. Flavor e config divergentes resultam em 401 em toda request
  // autenticada. O `.vscode/launch.json` amarra o par.
  //
  // Antes o ambiente vinha de `kReleaseMode`, o que quebrava as variantes
  // cruzadas: `prodDebug` usava o Firebase de produção contra a API de
  // desenvolvimento.
  //
  // Nenhum destes valores é segredo — são URLs públicas, e tudo que é compilado
  // no app é extraível de um APK. Por isso os arquivos são versionados.

  static const String environmentName = String.fromEnvironment(
    'ENV',
    defaultValue: '',
  );

  static bool get isProduction => environmentName == 'production';

  /// Rótulo curto do ambiente para o selo no topbar. Vazio em produção — lá o
  /// app não deve ostentar nada; a ausência do selo já significa "produção".
  /// Qualquer ambiente não-produção aparece para evitar mexer em dados reais
  /// achando que é dev.
  static String get environmentBadge {
    if (isProduction) return '';
    switch (environmentName) {
      case 'development':
        return 'DEV';
      case '':
        return 'SEM ENV';
      default:
        return environmentName.toUpperCase();
    }
  }

  static const String _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static const String _webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: '',
  );

  /// Endpoint da API. Para apontar a uma instância local, sobrescreva a chave
  /// depois do arquivo: `--dart-define=API_URL=https://localhost:44356`.
  static String get apiUrl => _require(_apiUrl, 'API_URL');

  /// Site público, usado para montar links compartilháveis de replay.
  static String get webUrl => _require(_webUrl, 'WEB_URL');

  /// Falha explícita em vez de cair num padrão silencioso.
  ///
  /// Mesma postura do `api/http.ts` no front web: um build sem config quebraria
  /// toda request com erro de rede obscuro. É melhor dizer o que faltou.
  static String _require(String value, String key) {
    if (value.isNotEmpty) return value;
    throw StateError(
      '$key não definida. Rode com --dart-define-from-file=config/dev.json '
      '(ou config/prod.json), casando com o --flavor.',
    );
  }

  /// Perfil da sessão única. A chave subiu para v3 porque o formato deixou de
  /// ser uma lista de contas com tokens e passou a ser um objeto só, sem token —
  /// a sessão agora é do Firebase. Ler o v2 daria erro de tipo.
  static const String accountStorageKey = 'patotas.account.v3';
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
