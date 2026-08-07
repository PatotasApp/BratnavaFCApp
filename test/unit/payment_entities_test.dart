import 'package:flutter_test/flutter_test.dart';
import 'package:bratnava_fc_app/features/payments/domain/entities/payment_entities.dart';

void main() {
  // ── MonthlyGrid.fromJson ───────────────────────────────────────────────────

  group('MonthlyGrid.fromJson', () {
    test('parses both fees when both present', () {
      final json = {
        'year': 2026,
        'monthlyFee': 100.0,
        'goalkeeperMonthlyFee': 60.0,
        'players': <dynamic>[],
      };

      final grid = MonthlyGrid.fromJson(json);

      expect(grid.year, 2026);
      expect(grid.monthlyFee, 100.0);
      expect(grid.goalkeeperMonthlyFee, 60.0);
    });

    test('goalkeeperMonthlyFee is null when absent', () {
      final json = {
        'year': 2026,
        'monthlyFee': 100.0,
        'players': <dynamic>[],
      };

      final grid = MonthlyGrid.fromJson(json);

      expect(grid.monthlyFee, 100.0);
      expect(grid.goalkeeperMonthlyFee, isNull);
    });

    test('goalkeeperMonthlyFee is null when explicitly null', () {
      final json = {
        'year': 2026,
        'monthlyFee': 100.0,
        'goalkeeperMonthlyFee': null,
        'players': <dynamic>[],
      };

      final grid = MonthlyGrid.fromJson(json);

      expect(grid.goalkeeperMonthlyFee, isNull);
    });

    test('parses integer fees as double', () {
      final json = {
        'year': 2026,
        'monthlyFee': 100,
        'goalkeeperMonthlyFee': 60,
        'players': <dynamic>[],
      };

      final grid = MonthlyGrid.fromJson(json);

      expect(grid.monthlyFee, isA<double>());
      expect(grid.goalkeeperMonthlyFee, isA<double>());
    });

    test('parses players list', () {
      final json = {
        'year': 2026,
        'monthlyFee': 100.0,
        'goalkeeperMonthlyFee': 60.0,
        'players': [
          {
            'playerId': 'abc',
            'playerName': 'GK',
            'isGoalkeeper': true,
            'months': <dynamic>[],
          },
          {
            'playerId': 'def',
            'playerName': 'Line',
            'isGoalkeeper': false,
            'months': <dynamic>[],
          },
        ],
      };

      final grid = MonthlyGrid.fromJson(json);

      expect(grid.players.length, 2);
      expect(grid.players[0].isGoalkeeper, isTrue);
      expect(grid.players[1].isGoalkeeper, isFalse);
    });
  });

  // ── PlayerRow.fromJson ─────────────────────────────────────────────────────

  group('PlayerRow.fromJson', () {
    test('isGoalkeeper is true when set', () {
      final json = {
        'playerId': 'abc',
        'playerName': 'Felipe GK',
        'isGoalkeeper': true,
        'months': <dynamic>[],
      };

      final row = PlayerRow.fromJson(json);

      expect(row.isGoalkeeper, isTrue);
    });

    test('isGoalkeeper defaults to false when absent', () {
      final json = {
        'playerId': 'def',
        'playerName': 'Caio',
        'months': <dynamic>[],
      };

      final row = PlayerRow.fromJson(json);

      expect(row.isGoalkeeper, isFalse);
    });

    test('isGoalkeeper is false when explicitly false', () {
      final json = {
        'playerId': 'ghi',
        'playerName': 'Lucas',
        'isGoalkeeper': false,
        'months': <dynamic>[],
      };

      final row = PlayerRow.fromJson(json);

      expect(row.isGoalkeeper, isFalse);
    });

    test('parses months list', () {
      final json = {
        'playerId': 'abc',
        'playerName': 'P',
        'months': [
          {
            'month': 5,
            'status': 0,
            'amount': 60.0,
            'discount': 0,
            'hasProof': false,
          },
        ],
      };

      final row = PlayerRow.fromJson(json);

      expect(row.months.length, 1);
      expect(row.months[0].month, 5);
      expect(row.months[0].amount, 60.0);
    });
  });

  group('ExtraChargePayment.fromJson', () {
    Map<String, dynamic> json({bool? isGoalkeeper}) => {
          'playerId': 'player-1',
          'playerName': 'Jogador',
          if (isGoalkeeper != null) 'isGoalkeeper': isGoalkeeper,
          'amount': 50.0,
          'discount': 0,
          'finalAmount': 50.0,
          'status': 0,
          'hasProof': false,
        };

    test('parses goalkeeper role when present', () {
      final payment = ExtraChargePayment.fromJson(json(isGoalkeeper: true));

      expect(payment.isGoalkeeper, isTrue);
    });

    test('defaults goalkeeper role to false when absent', () {
      final payment = ExtraChargePayment.fromJson(json());

      expect(payment.isGoalkeeper, isFalse);
    });
  });
}
