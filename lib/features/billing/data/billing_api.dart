import 'package:dio/dio.dart';

import '../domain/group_billing.dart';

/// Endpoints do plano da patota (`/api/billing`).
class BillingApi {
  final Dio _dio;
  const BillingApi(this._dio);

  static dynamic _unwrap(dynamic data) =>
      (data is Map && data.containsKey('data')) ? data['data'] : data;

  /// Nulo quando a API responde 403 (o usuário não é admin nem financeiro):
  /// o app simplesmente não mostra nada de cobrança.
  Future<GroupBilling?> getStatus(String groupId, String platform) async {
    try {
      final res = await _dio.get('/api/billing/groups/$groupId',
          queryParameters: {'platform': platform});
      final d = _unwrap(res.data);
      return d is Map ? GroupBilling.fromJson(d.cast<String, dynamic>()) : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Manda a compra concluída na loja para o servidor conferir e somar os meses.
  Future<GroupBilling> submitPurchase({
    required String groupId,
    required String platform,
    required String store,
    required String productId,
    String? transactionId,
    String? purchaseToken,
  }) async {
    final res = await _dio.post(
      '/api/billing/groups/$groupId/purchases',
      queryParameters: {'platform': platform},
      data: {
        'store': store,
        'productId': productId,
        'transactionId': transactionId,
        'purchaseToken': purchaseToken,
      },
    );
    final d = _unwrap(res.data);
    return GroupBilling.fromJson((d as Map).cast<String, dynamic>());
  }

  /// Reenvia compras que a loja devolveu (restaurar). Devolve quantas patotas foram atualizadas.
  Future<({int restored, List<String> groups, List<String> errors})> restore({
    required String store,
    required List<
            ({String productId, String? transactionId, String? purchaseToken})>
        items,
  }) async {
    final res = await _dio.post('/api/billing/restore', data: {
      'store': store,
      'items': [
        for (final i in items)
          {
            'productId': i.productId,
            'transactionId': i.transactionId,
            'purchaseToken': i.purchaseToken,
          }
      ],
    });
    final d = (_unwrap(res.data) as Map?) ?? const {};
    return (
      restored: (d['restored'] as num?)?.toInt() ?? 0,
      groups: ((d['groups'] as List?) ?? const []).map((e) => '$e').toList(),
      errors: ((d['errors'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}
