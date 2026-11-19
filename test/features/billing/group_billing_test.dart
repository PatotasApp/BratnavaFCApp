import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/billing/domain/group_billing.dart';
import 'package:patotas_app/features/billing/presentation/patota_vencida.dart';

Map<String, dynamic> _json({
  String status = 'trial',
  int? days = 12,
  String? endsOn = '2026-12-06',
  bool lifetime = false,
  bool enforcement = false,
}) =>
    {
      'groupId': 'g1',
      'status': status,
      'isLifetime': lifetime,
      'accessEndsOn': endsOn,
      'daysRemaining': days,
      'trialGranted': true,
      'isReadOnly': false,
      'enforcementEnabled': enforcement,
      'graceDays': 3,
      'showBanner': (days ?? 99) <= 7,
      'canPurchase': !lifetime,
      'purchaseBlockedReason': null,
      'products': [
        {
          'store': 'google',
          'productId': 'patota_1m',
          'months': 1,
          'referencePrice': 29.9,
          'extendsUntilOn': '2027-01-06'
        },
        {
          'store': 'google',
          'productId': 'patota_12m',
          'months': 12,
          'referencePrice': 322.9,
          'extendsUntilOn': '2027-12-06'
        },
        {
          'store': 'simulated',
          'productId': 'patota_1m',
          'months': 1,
          'referencePrice': 29.9,
          'extendsUntilOn': '2027-01-06'
        },
      ],
      'simulatedPurchasesEnabled': true,
      'history': [
        {
          'purchasedAt': '2026-11-06T15:00:00.000',
          'periodStart': '2026-12-06T15:00:00.000',
          'periodEnd': '2027-01-06T15:00:00.000',
          'months': 1,
          'store': 'google',
          'state': 'confirmed',
          'payerName': 'Ana Teste',
          'price': 29.9,
          'currency': 'BRL',
        }
      ],
      'termsUrl': 'https://patotasapp.com.br/termos.html',
      'privacyUrl': 'https://patotasapp.com.br/privacidade.html',
    };

void main() {
  group('GroupBilling', () {
    test('lê o plano da API e separa pacotes da loja e simulados', () {
      final b = GroupBilling.fromJson(_json());
      expect(b.statusLabel, 'Teste grátis');
      expect(b.storePackages.map((p) => p.months), [1, 12]);
      expect(b.simulatedPackages, hasLength(1));
      expect(b.storePackages.last.monthsLabel, '12 meses');
      expect(b.history.single.payerName, 'Ana Teste');
      // A API manda UTC sem "Z".
      expect(b.history.single.purchasedAt.isUtc, isTrue);
      expect(b.history.single.purchasedAt.hour, 15);
    });

    test('vencimento claro: dia e quanto falta', () {
      expect(GroupBilling.fromJson(_json(days: 12)).dueText,
          'Vence em 06/12/2026 · faltam 12 dias');
      expect(GroupBilling.fromJson(_json(days: 1)).dueText,
          'Vence amanhã (06/12/2026)');
      expect(GroupBilling.fromJson(_json(days: 0)).dueText,
          'Vence hoje (06/12/2026)');
      expect(GroupBilling.fromJson(_json(status: 'expired', days: -4)).dueText,
          'Venceu em 06/12/2026 · há 4 dias');
      expect(
          GroupBilling.fromJson(_json(
                  lifetime: true, status: 'lifetime', days: null, endsOn: null))
              .dueText,
          'Sem vencimento');
    });

    test('faixa do Dashboard', () {
      expect(GroupBilling.fromJson(_json(days: 3)).bannerText,
          'O plano da patota vence em 3 dias.');
      expect(GroupBilling.fromJson(_json(days: 3)).showBanner, isTrue);
      expect(GroupBilling.fromJson(_json(days: 12)).showBanner, isFalse);
      expect(
          GroupBilling.fromJson(
                  _json(status: 'expired', days: -5, enforcement: true))
              .bannerText,
          contains('somente leitura'));
    });

    test('formatos', () {
      expect(formatBrl(29.9), r'R$ 29,90');
      expect(formatBrl(1322.9), r'R$ 1.322,90');
      expect(formatDay('2027-01-06'), '06/01/2027');
      expect(formatBrasiliaDate(DateTime.utc(2026, 12, 6, 2)), '05/12/2026');
    });
  });

  group('PATOTA_VENCIDA', () {
    Response<dynamic> res(int code, dynamic data) => Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: code,
        data: data);

    test('reconhece o 402 da API', () {
      expect(
          isPatotaVencida(
              res(402, {'code': 'PATOTA_VENCIDA', 'groupId': 'g1'})),
          isTrue);
      expect(
          isPatotaVencida(res(402, {
            'errors': ['PATOTA_VENCIDA']
          })),
          isTrue);
      expect(isPatotaVencida(res(400, {'code': 'PATOTA_VENCIDA'})), isFalse);
      expect(isPatotaVencida(res(402, 'texto')), isFalse);
      expect(isPatotaVencida(null), isFalse);
    });
  });
}
