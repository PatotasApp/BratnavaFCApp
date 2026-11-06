import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../auth/domain/entities/account.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/billing_api.dart';
import '../data/store_billing.dart';
import '../domain/group_billing.dart';

final billingApiProvider =
    Provider<BillingApi>((ref) => BillingApi(ref.watch(dioProvider)));

final storeBillingProvider = Provider<StoreBilling>((ref) {
  final store =
      StoreBilling(InAppPurchase.instance, ref.watch(billingApiProvider));
  store.start();
  ref.onDispose(store.dispose);
  return store;
});

/// Plano da patota. Nulo para quem não é admin nem financeiro (a API responde 403).
final groupBillingProvider = FutureProvider.autoDispose
    .family<GroupBilling?, String>((ref, groupId) async {
  if (groupId.isEmpty) return null;
  return ref.watch(billingApiProvider).getStatus(groupId, billingPlatform());
});

/// Só admin e financeiro da patota veem qualquer coisa de cobrança.
bool canSeeBilling(Account? account, String? groupId) {
  if (account == null || groupId == null || groupId.isEmpty) return false;
  return account.isGroupAdmin(groupId) || account.isGroupFinanceiro(groupId);
}
