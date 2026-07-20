class AppConstants {
  AppConstants._();

  /// Produção: https://bratnavafcapi.fly.dev
  /// Local:    flutter run --dart-define=API_URL=https://localhost:44356
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://bratnavafcapi.fly.dev',
  );

  static const String accountsStorageKey = 'bratnava.accounts.v2';
  static const String activeAccountKey = 'bratnava.activeAccountId';
  static const String themeStorageKey = 'bratnava-theme';

  static const Duration connectTimeout = Duration(seconds: 45);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
