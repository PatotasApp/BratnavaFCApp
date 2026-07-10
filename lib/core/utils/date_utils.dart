String _stripTimezone(String raw) => raw
    .replaceFirst(RegExp(r'Z$', caseSensitive: false), '')
    .replaceFirst(RegExp(r'([+-]\d{2}:\d{2})$'), '');

DateTime _parseWallTime(String? raw, {DateTime? fallback}) {
  if (raw == null || raw.isEmpty) return fallback ?? DateTime.now();
  return DateTime.tryParse(_stripTimezone(raw)) ?? fallback ?? DateTime.now();
}

DateTime? _parseWallTimeOrNull(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(_stripTimezone(raw));
}

/// Parseia data da API preservando o horario literal recebido.
///
/// Datas de partida no Bratnava sao horarios do dominio: se o admin salva
/// 21:00, todos os clientes devem exibir 21:00, independente do fuso do
/// dispositivo.
DateTime parseApiDate(String? raw, {DateTime? fallback}) =>
    _parseWallTime(raw, fallback: fallback);

/// Parseia data da API. Retorna null se a string for invalida.
DateTime? parseApiDateOrNull(String? raw) => _parseWallTimeOrNull(raw);

class AppDateUtils {
  const AppDateUtils._();

  /// Parseia string ISO-8601 preservando o horario literal. Nunca retorna null.
  static DateTime parseOrNow(String? raw) => _parseWallTime(raw);

  /// Parseia string ISO-8601 preservando o horario literal.
  static DateTime? parse(String? raw) => _parseWallTimeOrNull(raw);
}
