import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/next_match_date.dart';

void main() {
  group('nearestConfiguredMatchDate', () {
    test('sugere quinta quando hoje é quarta e os jogos são terça e quinta',
        () {
      final result = nearestConfiguredMatchDate(
        DateTime(2026, 11, 11, 18),
        const [2, 4],
      );
      expect(result, DateTime(2026, 11, 12));
    });

    test('sugere a próxima terça quando hoje é sexta', () {
      final result = nearestConfiguredMatchDate(
        DateTime(2026, 11, 13, 10),
        const [2, 4],
      );
      expect(result, DateTime(2026, 11, 17));
    });

    test('mantém hoje quando hoje é um dos dias configurados', () {
      final result = nearestConfiguredMatchDate(
        DateTime(2026, 11, 10, 22),
        const [2, 4],
      );
      expect(result, DateTime(2026, 11, 10));
    });

    test('mantém hoje quando não existem dias configurados', () {
      final result = nearestConfiguredMatchDate(
        DateTime(2026, 11, 13, 10),
        const [],
      );
      expect(result, DateTime(2026, 11, 13));
    });
  });
}
