DateTime nearestConfiguredMatchDate(
  DateTime reference,
  Iterable<int> configuredDays,
) {
  final days = configuredDays.where((day) => day >= 0 && day <= 6).toSet();
  final date = DateTime(reference.year, reference.month, reference.day);
  if (days.isEmpty) return date;

  // API: 0=Sunday ... 6=Saturday. Dart: 1=Monday ... 7=Sunday.
  final currentDay = reference.weekday % 7;
  final offset = days
      .map((day) => (day - currentDay + 7) % 7)
      .reduce((left, right) => left < right ? left : right);
  return date.add(Duration(days: offset));
}
