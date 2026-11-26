String formatBrazilianDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';

DateTime? parseDateInput(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;

  final brazilian = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
  if (brazilian != null) {
    final day = int.parse(brazilian.group(1)!);
    final month = int.parse(brazilian.group(2)!);
    final year = int.parse(brazilian.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year == year && parsed.month == month && parsed.day == day) {
      return parsed;
    }
    return null;
  }

  return DateTime.tryParse(value);
}

String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String? dateInputToApi(String? raw) {
  final parsed = parseDateInput(raw);
  return parsed == null ? null : formatApiDate(parsed);
}

String apiDateToInput(String? raw) {
  final parsed = parseDateInput(raw);
  return parsed == null ? (raw?.trim() ?? '') : formatBrazilianDate(parsed);
}
