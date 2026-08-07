import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../data/datasources/transactions_remote_datasource.dart';
import '../../domain/entities/payment_entities.dart';

// ── Datasource ────────────────────────────────────────────────────────────────

final paymentsDsProvider = Provider<PaymentsRemoteDataSource>(
  (ref) => PaymentsRemoteDataSource(ref.watch(dioProvider)),
);

final transactionsDsProvider = Provider<TransactionsRemoteDataSource>(
  (ref) => TransactionsRemoteDataSource(ref.watch(dioProvider)),
);

// ── Admin providers ───────────────────────────────────────────────────────────

final monthlyGridProvider = FutureProvider.autoDispose
    .family<MonthlyGrid, ({String groupId, int year})>(
  (ref, args) =>
      ref.watch(paymentsDsProvider).getMonthlyGrid(args.groupId, args.year),
);

final extraChargesProvider =
    FutureProvider.autoDispose.family<List<ExtraCharge>, String>(
  (ref, groupId) => ref.watch(paymentsDsProvider).getExtraCharges(groupId),
);

// ── User providers ────────────────────────────────────────────────────────────

final myMonthlyRowProvider =
    FutureProvider.autoDispose.family<PlayerRow?, ({String groupId, int year})>(
  (ref, args) =>
      ref.watch(paymentsDsProvider).getMyMonthlyRow(args.groupId, args.year),
);

final myExtraChargesProvider =
    FutureProvider.autoDispose.family<List<ExtraCharge>, String>(
  (ref, groupId) => ref.watch(paymentsDsProvider).getMyExtraCharges(groupId),
);

// ── Dashboard ─────────────────────────────────────────────────────────────────
// Computa o resumo a partir das mesmas fontes que a tela de Financeiro usa,
// evitando dependência do endpoint /payments/my cujos campos variam por versão.

final myPaymentSummaryProvider =
    FutureProvider.autoDispose.family<PaymentSummary?, String>(
  (ref, groupId) async {
    final ds = ref.watch(paymentsDsProvider);
    final year = DateTime.now().year;

    final results = await Future.wait([
      ds.getMyMonthlyRow(groupId, year).catchError((_) => null as PlayerRow?),
      ds.getMyExtraCharges(groupId).catchError((_) => <ExtraCharge>[]),
    ]);

    final row = results[0] as PlayerRow?;
    final extras = results[1] as List<ExtraCharge>;

    // Mensalidades pendentes no ano corrente
    final pendingMonths = row?.months.where((m) => !m.isPaid).toList() ?? [];
    final pendingMonthlyCount = pendingMonths.length;
    final pendingMonthlyAmount =
        pendingMonths.fold(0.0, (sum, m) => sum + (m.amount - m.discount));

    // Cobranças extras pendentes (não canceladas, não finalizadas)
    final pendingExtras =
        extras.where((e) => !e.isCancelled && !e.isFinalized).toList();
    final pendingExtraCount = pendingExtras.length;
    final pendingExtraAmount = pendingExtras.fold(
        0.0,
        (sum, e) =>
            sum +
            (e.payments.isEmpty
                ? e.amount
                : e.payments
                    .where((p) => !p.isPaid)
                    .fold(0.0, (s, p) => s + (p.amount - p.discount))));

    return PaymentSummary(
      pendingMonthlyCount: pendingMonthlyCount,
      pendingExtraCount: pendingExtraCount,
      totalPendingAmount: pendingMonthlyAmount + pendingExtraAmount,
      paymentMode: 0,
    );
  },
);
