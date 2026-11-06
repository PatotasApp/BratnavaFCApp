import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';

void main() {
  group('matchStepLabel', () {
    test('traduz status técnicos da API', () {
      expect(matchStepLabel('Finalized'), 'Finalizada');
      expect(matchStepLabel('MatchMaking'), 'Montagem dos times');
    });

    test('preserva um rótulo desconhecido', () {
      expect(matchStepLabel('NovaEtapa'), 'NovaEtapa');
    });
  });
}
