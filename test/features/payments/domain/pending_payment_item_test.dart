import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/payments/domain/entities/payment_entities.dart';

void main() {
  group('PendingPaymentItem', () {
    test('interpreta o contrato camelCase e gera a marcação como paga', () {
      final item = PendingPaymentItem.fromJson({
        'id': 'm-2026-8',
        'description': 'Agosto 2026',
        'amount': 75,
        'discount': 5,
        'finalAmount': 70,
        'type': 0,
        'year': 2026,
        'month': 8,
        'chargeId': null,
        'isPaid': false,
      });

      expect(item.description, 'Agosto 2026');
      expect(item.finalAmount, 70);
      expect(item.isPaid, isFalse);
      expect(item.toPaidRequest(), {
        'type': 0,
        'year': 2026,
        'month': 8,
        'chargeId': null,
        'isPaid': true,
      });
    });

    test('aceita o contrato PascalCase de cobrança extra', () {
      final item = PendingPaymentItem.fromJson({
        'Id': 'e-charge-id',
        'Description': 'Churrasco',
        'Amount': 25.5,
        'Discount': 3.5,
        'FinalAmount': 22,
        'Type': 1,
        'ChargeId': 'charge-id',
        'IsPaid': false,
      });

      expect(item.type, 1);
      expect(item.chargeId, 'charge-id');
      expect(item.finalAmount, 22);
    });
  });
}
