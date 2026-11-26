import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/utils/date_input_utils.dart';

void main() {
  test('mostra data no formato brasileiro', () {
    expect(formatBrazilianDate(DateTime(2026, 11, 25)), '25/11/2026');
  });

  test('converte formato brasileiro para contrato da API', () {
    expect(dateInputToApi('25/11/2026'), '2026-11-25');
  });

  test('aceita valor antigo ISO ao carregar uma data', () {
    expect(apiDateToInput('2026-11-25'), '25/11/2026');
  });

  test('rejeita data brasileira inexistente', () {
    expect(dateInputToApi('31/02/2026'), isNull);
  });
}
