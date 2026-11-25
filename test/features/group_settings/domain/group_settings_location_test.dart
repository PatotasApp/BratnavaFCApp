import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/group_settings/domain/entities/group_settings.dart';

void main() {
  test('lê e envia a localização estruturada padrão', () {
    final settings = GroupSettings.fromJson({
      'defaultPlaceName': 'Arena Central',
      'defaultPlaceAddress': 'Rua das Flores, 10',
      'defaultPlaceLatitude': -23.550520,
      'defaultPlaceLongitude': -46.633308,
    });

    expect(settings.defaultPlaceName, 'Arena Central');
    expect(settings.defaultPlaceAddress, 'Rua das Flores, 10');
    expect(settings.defaultPlaceLatitude, -23.550520);
    expect(settings.defaultPlaceLongitude, -46.633308);

    final json = settings.toJson(
      minPlayers: 5,
      maxPlayers: 14,
      defaultPlaceName: settings.defaultPlaceName,
      defaultPlaceAddress: settings.defaultPlaceAddress,
      defaultPlaceLatitude: settings.defaultPlaceLatitude,
      defaultPlaceLongitude: settings.defaultPlaceLongitude,
      defaultDaysOfWeek: const [],
      defaultKickoffTime: null,
      paymentMode: 0,
      monthlyFee: null,
      goalkeeperMonthlyFee: null,
      goalIcon: null,
      goalkeeperIcon: null,
      assistIcon: null,
      ownGoalIcon: null,
      mvpIcon: null,
      playerIcon: null,
      mvpTieRule: 1,
      showPlayerStats: false,
    );

    expect(json['defaultPlaceAddress'], 'Rua das Flores, 10');
    expect(json['defaultPlaceLatitude'], -23.550520);
    expect(json['defaultPlaceLongitude'], -46.633308);
  });
}
