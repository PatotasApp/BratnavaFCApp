import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/group_settings/domain/entities/group_settings.dart';

void main() {
  // ── GroupSettings.fromJson ─────────────────────────────────────────────────

  group('GroupSettings.fromJson', () {
    test('parses goalkeeperMonthlyFee when present', () {
      final json = {
        'minPlayers': 5,
        'maxPlayers': 10,
        'paymentMode': 0,
        'monthlyFee': 100.0,
        'goalkeeperMonthlyFee': 60.0,
        'isPersisted': true,
        'showPlayerStats': false,
      };

      final gs = GroupSettings.fromJson(json);

      expect(gs.monthlyFee, 100.0);
      expect(gs.goalkeeperMonthlyFee, 60.0);
    });

    test('goalkeeperMonthlyFee is null when absent', () {
      final json = {
        'minPlayers': 5,
        'maxPlayers': 10,
        'paymentMode': 0,
        'monthlyFee': 100.0,
        'isPersisted': true,
        'showPlayerStats': false,
      };

      final gs = GroupSettings.fromJson(json);

      expect(gs.goalkeeperMonthlyFee, isNull);
    });

    test('goalkeeperMonthlyFee is null when explicitly null in json', () {
      final json = {
        'minPlayers': 5,
        'maxPlayers': 10,
        'paymentMode': 0,
        'monthlyFee': 100.0,
        'goalkeeperMonthlyFee': null,
        'isPersisted': true,
        'showPlayerStats': false,
      };

      final gs = GroupSettings.fromJson(json);

      expect(gs.goalkeeperMonthlyFee, isNull);
    });

    test('parses integer goalkeeperMonthlyFee as double', () {
      final json = {
        'minPlayers': 5,
        'maxPlayers': 10,
        'paymentMode': 0,
        'goalkeeperMonthlyFee': 60,
        'isPersisted': false,
        'showPlayerStats': false,
      };

      final gs = GroupSettings.fromJson(json);

      expect(gs.goalkeeperMonthlyFee, 60.0);
      expect(gs.goalkeeperMonthlyFee, isA<double>());
    });

    test('unwraps data envelope', () {
      final json = {
        'data': {
          'minPlayers': 5,
          'maxPlayers': 10,
          'paymentMode': 0,
          'monthlyFee': 80.0,
          'goalkeeperMonthlyFee': 50.0,
          'isPersisted': true,
          'showPlayerStats': false,
        }
      };

      final gs = GroupSettings.fromJson(json);

      expect(gs.monthlyFee, 80.0);
      expect(gs.goalkeeperMonthlyFee, 50.0);
    });
  });

  // ── GroupSettings.toJson ───────────────────────────────────────────────────

  group('GroupSettings.toJson', () {
    test('includes goalkeeperMonthlyFee when paymentMode == 0', () {
      final body = const GroupSettings().toJson(
        minPlayers:          5,
        maxPlayers:          10,
        defaultPlaceName:    null,
        defaultDayOfWeek:    null,
        defaultKickoffTime:  null,
        paymentMode:         0,
        monthlyFee:          100.0,
        goalkeeperMonthlyFee: 60.0,
        goalIcon:            null,
        goalkeeperIcon:      null,
        assistIcon:          null,
        ownGoalIcon:         null,
        mvpIcon:             null,
        playerIcon:          null,
        mvpTieRule:          1,
        showPlayerStats:     false,
      );

      expect(body['goalkeeperMonthlyFee'], 60.0);
      expect(body['monthlyFee'], 100.0);
    });

    test('sends null for goalkeeperMonthlyFee when paymentMode == 1', () {
      final body = const GroupSettings().toJson(
        minPlayers:          5,
        maxPlayers:          10,
        defaultPlaceName:    null,
        defaultDayOfWeek:    null,
        defaultKickoffTime:  null,
        paymentMode:         1,
        monthlyFee:          100.0,
        goalkeeperMonthlyFee: 60.0,
        goalIcon:            null,
        goalkeeperIcon:      null,
        assistIcon:          null,
        ownGoalIcon:         null,
        mvpIcon:             null,
        playerIcon:          null,
        mvpTieRule:          1,
        showPlayerStats:     false,
      );

      expect(body['goalkeeperMonthlyFee'], isNull);
      expect(body['monthlyFee'], isNull);
    });

    test('sends null goalkeeperMonthlyFee when fee is null and paymentMode == 0', () {
      final body = const GroupSettings().toJson(
        minPlayers:          5,
        maxPlayers:          10,
        defaultPlaceName:    null,
        defaultDayOfWeek:    null,
        defaultKickoffTime:  null,
        paymentMode:         0,
        monthlyFee:          100.0,
        goalkeeperMonthlyFee: null,
        goalIcon:            null,
        goalkeeperIcon:      null,
        assistIcon:          null,
        ownGoalIcon:         null,
        mvpIcon:             null,
        playerIcon:          null,
        mvpTieRule:          1,
        showPlayerStats:     false,
      );

      expect(body['goalkeeperMonthlyFee'], isNull);
      expect(body['monthlyFee'], 100.0);
    });
  });
}
