import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:patotas_app/core/location/app_location_service.dart';

void main() {
  group('AppLocationService.formatPlacemarkAddress', () {
    test('não duplica endereço completo devolvido pelo Android', () {
      const placemark = Placemark(
        street: '1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA',
        locality: 'Mountain View',
        administrativeArea: 'California',
        postalCode: '94043',
        country: 'United States',
      );

      expect(
        AppLocationService.formatPlacemarkAddress(placemark),
        '1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA',
      );
    });

    test('monta endereço quando a rua não contém cidade e CEP', () {
      const placemark = Placemark(
        street: 'Rua Ayres Gama, 350',
        subLocality: 'Centro',
        locality: 'Blumenau',
        administrativeArea: 'Santa Catarina',
        postalCode: '89012-480',
        country: 'Brasil',
      );

      expect(
        AppLocationService.formatPlacemarkAddress(placemark),
        'Rua Ayres Gama, 350, Centro, Blumenau, Santa Catarina, '
        '89012-480, Brasil',
      );
    });
  });
}
