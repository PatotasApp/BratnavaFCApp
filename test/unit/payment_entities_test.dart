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

  group('MonthlyCell.fromJson', () {
    test('parses payment audit fields', () {
      final json = {
        'month': 7,
        'status': 1,
        'amount': 75,
        'discount': 10,
        'discountReason': 'Cortesia',
        'paidAt': '2026-07-18T12:34:56Z',
        'markedByUserId': 'user-1',
        'markedByUserName': 'Luis',
        'markedByUserKind': 'self',
        'hasProof': true,
        'proofFileName': 'recibo.pdf',
      };

      final cell = MonthlyCell.fromJson(json);

      expect(cell.isPaid, isTrue);
      expect(cell.paidAt, '2026-07-18T12:34:56Z');
      expect(cell.markedByUserId, 'user-1');
      expect(cell.markedByUserName, 'Luis');
      expect(cell.markedByUserKind, 'self');
      expect(cell.discount, 10);
      expect(cell.discountReason, 'Cortesia');
    });
  });

  group('ExtraChargePayment.fromJson', () {
    test('parses payment audit fields', () {
      final json = {
        'playerId': 'player-1',
        'playerName': 'Luis',
        'amount': 90,
        'discount': 15,
        'finalAmount': 75,
        'discountReason': 'Ajuste',
        'status': 1,
        'paidAt': '2026-07-18T12:34:56Z',
        'markedByUserId': 'finance-1',
        'markedByUserName': 'Andrei',
        'markedByUserKind': 'financeiro',
        'hasProof': false,
      };

      final payment = ExtraChargePayment.fromJson(json);

      expect(payment.isPaid, isTrue);
      expect(payment.paidAt, '2026-07-18T12:34:56Z');
      expect(payment.markedByUserId, 'finance-1');
      expect(payment.markedByUserName, 'Andrei');
      expect(payment.markedByUserKind, 'financeiro');
      expect(payment.finalAmount, 75);
      expect(payment.discount, 15);
      expect(payment.discountReason, 'Ajuste');
    });
  });
}
