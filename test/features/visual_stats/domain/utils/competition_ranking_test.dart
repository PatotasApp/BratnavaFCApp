import 'package:patotas_app/features/visual_stats/domain/utils/competition_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateClassificationPoints', () {
    test('soma três por vitória e um por empate', () {
      expect(calculateClassificationPoints(wins: 19, ties: 4), 61);
    });

    test('derrotas não participam do cálculo', () {
      expect(calculateClassificationPoints(wins: 0, ties: 0), 0);
    });
  });

  group('buildCompetitionRanks', () {
    test('atribui a mesma posição para valores empatados', () {
      final ranks = buildCompetitionRanks<(String, int), String>(
        items: const [('a', 10), ('b', 8), ('c', 8), ('d', 5)],
        keyOf: (item) => item.$1,
        valueOf: (item) => item.$2,
      );

      expect(ranks, {'a': 1, 'b': 2, 'c': 2, 'd': 4});
    });

    test('mantém todos os jogadores zerados na mesma posição', () {
      final ranks = buildCompetitionRanks<(String, int), String>(
        items: const [('a', 0), ('b', 0), ('c', 0)],
        keyOf: (item) => item.$1,
        valueOf: (item) => item.$2,
      );

      expect(ranks, {'a': 1, 'b': 1, 'c': 1});
    });

    test('usa o desempate apenas para ordenar, sem quebrar empates', () {
      final ranks = buildCompetitionRanks<(String, int), String>(
        items: const [('z', 4), ('a', 4), ('b', 2)],
        keyOf: (item) => item.$1,
        valueOf: (item) => item.$2,
        tieBreaker: (a, b) => a.$1.compareTo(b.$1),
      );

      expect(ranks, {'a': 1, 'z': 1, 'b': 3});
    });
  });
}
