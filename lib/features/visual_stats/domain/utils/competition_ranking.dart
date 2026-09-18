int calculateClassificationPoints({
  required int wins,
  required int ties,
}) =>
    (wins * 3) + ties;

Map<K, int> buildCompetitionRanks<T, K>({
  required Iterable<T> items,
  required K Function(T item) keyOf,
  required num Function(T item) valueOf,
  int Function(T a, T b)? tieBreaker,
}) {
  final ordered = items.toList()
    ..sort((a, b) {
      final comparison = valueOf(b).compareTo(valueOf(a));
      if (comparison != 0) return comparison;
      return tieBreaker?.call(a, b) ?? 0;
    });

  final ranks = <K, int>{};
  for (var index = 0; index < ordered.length; index++) {
    final current = ordered[index];
    final tied = index > 0 && valueOf(current) == valueOf(ordered[index - 1]);
    ranks[keyOf(current)] =
        tied ? ranks[keyOf(ordered[index - 1])]! : index + 1;
  }
  return ranks;
}
