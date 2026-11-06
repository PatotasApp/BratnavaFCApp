import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/account_store.dart';
import 'billing_providers.dart';
import 'group_plan_page.dart';

/// Card "Plano da patota" em Minha patota. Some por completo para quem não é
/// admin nem financeiro (jogador comum não vê nada de cobrança).
class GroupPlanCard extends ConsumerWidget {
  final String groupId;
  const GroupPlanCard({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    if (!canSeeBilling(account, groupId)) return const SizedBox.shrink();

    final billing = ref.watch(groupBillingProvider(groupId)).valueOrNull;
    if (billing == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plano da patota',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GroupPlanSummary(billing: billing),
          const SizedBox(height: 8),
          Row(children: [
            if (!billing.isLifetime)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/app/plano?groupId=$groupId'),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Pagar mais meses'),
                ),
              ),
            if (!billing.isLifetime) const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/app/plano?groupId=$groupId'),
                child: const Text('Histórico e restaurar'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Faixa do Dashboard quando faltam 7 dias ou menos (ou já venceu). Só admin e financeiro.
class BillingDueBanner extends ConsumerWidget {
  final String? groupId;
  const BillingDueBanner({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final gid = groupId;
    if (gid == null || !canSeeBilling(account, gid)) {
      return const SizedBox.shrink();
    }

    final billing = ref.watch(groupBillingProvider(gid)).valueOrNull;
    if (billing == null || !billing.showBanner) return const SizedBox.shrink();

    final danger = billing.isExpired || billing.isGrace;
    final color =
        danger ? Theme.of(context).colorScheme.error : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/app/plano?groupId=$gid'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(danger ? Icons.error_outline : Icons.schedule, color: color),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(billing.bannerText,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              Text('Pagar',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}
