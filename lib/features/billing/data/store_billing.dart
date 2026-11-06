import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/group_billing.dart';
import 'billing_api.dart';

/// Plataforma no formato que a API entende (`?platform=`).
String billingPlatform() {
  if (kIsWeb) return 'web';
  return Platform.isIOS ? 'ios' : 'android';
}

/// Loja do aparelho, no formato da API.
String deviceStore() => billingPlatform() == 'ios' ? 'apple' : 'google';

/// Resultado de uma tentativa de compra.
class PurchaseOutcome {
  final GroupBilling? billing;
  final String? error;
  final bool canceled;
  final bool pending;

  const PurchaseOutcome._(
      {this.billing, this.error, this.canceled = false, this.pending = false});

  const PurchaseOutcome.done(GroupBilling b) : this._(billing: b);
  const PurchaseOutcome.failed(String e) : this._(error: e);
  const PurchaseOutcome.canceled() : this._(canceled: true);
  const PurchaseOutcome.pending() : this._(pending: true);
}

/// Ponte entre a loja (Apple / Google, pelo plugin `in_app_purchase`) e a API.
///
/// Os pacotes são avulsos: na Apple, "assinatura sem renovação"; no Google,
/// produto consumível. A compra leva o ID da patota no `applicationUserName`
/// (vira `appAccountToken` na Apple e `obfuscatedAccountId` no Google), e o
/// servidor confere tudo com a loja antes de somar os meses.
///
/// A transação só é finalizada na loja (`completePurchase`) depois que o
/// servidor aceitou: se a rede cair no meio, a loja entrega a compra de novo
/// na próxima abertura e ela é reenviada.
class StoreBilling {
  final InAppPurchase _iap;
  final BillingApi _api;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  String? _pendingGroupId;
  String? _pendingProductId;
  Completer<PurchaseOutcome>? _pending;

  final List<PurchaseDetails> _restoreBuffer = [];
  Completer<void>? _restoreWindow;

  StoreBilling(this._iap, this._api);

  /// Começa a ouvir a loja. Seguro chamar mais de uma vez.
  void start() {
    if (kIsWeb) return;
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _finishPending(PurchaseOutcome.failed('Erro da loja: $e'));
    });
  }

  void dispose() => _sub?.cancel();

  Future<bool> isAvailable() async => !kIsWeb && await _iap.isAvailable();

  /// Detalhes (preço real da loja) dos pacotes. Os que a loja não conhece ficam de fora.
  Future<Map<String, ProductDetails>> loadProducts(Iterable<String> ids) async {
    if (!await isAvailable()) return {};
    final res = await _iap.queryProductDetails(ids.toSet());
    return {for (final p in res.productDetails) p.id: p};
  }

  /// Compra um pacote para a patota e espera o servidor confirmar.
  Future<PurchaseOutcome> buy(String groupId, ProductDetails product) async {
    start();
    if (_pending != null) {
      return const PurchaseOutcome.failed('Já existe uma compra em andamento.');
    }
    _pendingGroupId = groupId;
    _pendingProductId = product.id;
    _pending = Completer<PurchaseOutcome>();

    final param =
        PurchaseParam(productDetails: product, applicationUserName: groupId);
    try {
      final started = deviceStore() == 'google'
          // O servidor consome; consumir aqui antes de ele conferir perderia a compra
          // se a rede caísse.
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: false)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _finishPending(
            const PurchaseOutcome.failed('A loja não abriu a compra.'));
      }
    } catch (e) {
      _finishPending(
          PurchaseOutcome.failed('Não foi possível abrir a loja: $e'));
    }
    return _pending!.future;
  }

  /// Pede para a loja reentregar as compras desta conta e manda para o servidor.
  Future<({int restored, List<String> groups, List<String> errors})>
      restore() async {
    start();
    if (!await isAvailable()) {
      return (
        restored: 0,
        groups: <String>[],
        errors: ['Loja indisponível neste aparelho.']
      );
    }
    _restoreBuffer.clear();
    _restoreWindow = Completer<void>();
    await _iap.restorePurchases();
    // A loja entrega as compras pelo stream, sem avisar quando acabou.
    await Future.any(
        [_restoreWindow!.future, Future.delayed(const Duration(seconds: 4))]);
    _restoreWindow = null;

    final items = _restoreBuffer.toList();
    _restoreBuffer.clear();
    if (items.isEmpty) {
      return (restored: 0, groups: <String>[], errors: <String>[]);
    }

    final result = await _api.restore(
      store: deviceStore(),
      items: [for (final p in items) _item(p)],
    );
    for (final p in items) {
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    return result;
  }

  ({String productId, String? transactionId, String? purchaseToken}) _item(
          PurchaseDetails p) =>
      (
        productId: p.productID,
        transactionId: deviceStore() == 'apple' ? p.purchaseID : null,
        purchaseToken: deviceStore() == 'google'
            ? p.verificationData.serverVerificationData
            : null,
      );

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          if (_isCurrent(p)) _finishPending(const PurchaseOutcome.pending());
          break;
        case PurchaseStatus.canceled:
          if (_isCurrent(p)) _finishPending(const PurchaseOutcome.canceled());
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          if (_isCurrent(p)) {
            _finishPending(PurchaseOutcome.failed(
                p.error?.message ?? 'A compra não foi concluída.'));
          }
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_restoreWindow != null && p.status == PurchaseStatus.restored) {
            _restoreBuffer.add(p);
            break;
          }
          await _deliver(p);
          break;
      }
    }
  }

  bool _isCurrent(PurchaseDetails p) =>
      _pending != null && p.productID == _pendingProductId;

  /// Compra concluída na loja: confere no servidor e só então finaliza.
  Future<void> _deliver(PurchaseDetails p) async {
    final item = _item(p);
    final groupId = _isCurrent(p) ? _pendingGroupId : null;
    try {
      if (groupId != null) {
        final billing = await _api.submitPurchase(
          groupId: groupId,
          platform: billingPlatform(),
          store: deviceStore(),
          productId: item.productId,
          transactionId: item.transactionId,
          purchaseToken: item.purchaseToken,
        );
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        _finishPending(PurchaseOutcome.done(billing));
      } else {
        // Reentregue pela loja (app fechou no meio): o servidor descobre a patota
        // pelo que ficou gravado na compra.
        await _api.restore(store: deviceStore(), items: [item]);
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      }
    } catch (e) {
      // Não finaliza: a loja entrega de novo e o "Restaurar compras" reenvia.
      if (groupId != null) {
        _finishPending(const PurchaseOutcome.failed(
            'Pagamento feito na loja, mas o servidor ainda não confirmou. '
            'Toque em "Restaurar compras" em instantes.'));
      }
    }
  }

  void _finishPending(PurchaseOutcome outcome) {
    final c = _pending;
    _pending = null;
    _pendingGroupId = null;
    _pendingProductId = null;
    if (c != null && !c.isCompleted) c.complete(outcome);
  }
}
