import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/location/app_location_service.dart';

void main() {
  test('prioriza resultados mais proximos da localizacao informada', () {
    const blumenau = AppLocationResult(
      name: 'Boca Juniors Blumenau',
      address: 'Rua Ayres Gama, Blumenau',
      latitude: -26.9187,
      longitude: -49.0660,
    );
    const campinas = AppLocationResult(
      name: 'Boca Juniors Campinas',
      address: 'Campinas, SP',
      latitude: -22.9056,
      longitude: -47.0608,
    );

    final sorted = AppLocationService.sortByDistance(
      const [campinas, blumenau],
      latitude: -26.92,
      longitude: -49.07,
    );

    expect(sorted.first.name, 'Boca Juniors Blumenau');
  });
}
