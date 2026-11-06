import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/account_store.dart';
import '../data/store_billing.dart';
import '../domain/group_billing.dart';
import 'billing_providers.dart';

/// Plano da patota: situação, vencimento, pacotes para pagar mais meses,
/// histórico, "Restaurar compras" e links de Termos/Privacidade.
///
/// Só admin e financeiro chegam aqui (o card e a faixa só aparecem para eles,
/// e a API responde 403 para os demais).
class GroupPlanPage extends ConsumerStatefulWidget {
  final String? groupId;
  const GroupPlanPage({super.key, this.groupId});

  @override
  ConsumerState<GroupPlanPage> createState() => _GroupPlanPageState();
}

class _GroupPlanPageState extends ConsumerState<GroupPlanPage> {
  Map<String, ProductDetails> _storeProducts = const {};
  bool _loadingProducts = false;
  bool _busy = false;
  String? _loadedFor;

  String get _groupId =>
      widget.groupId ??
      ref.read(accountStoreProvider).activeAccount?.activeGroupId ??
      '';

  Future<void> _loadStoreProducts(GroupBilling billing) async {
    final key = billing.storePackages.map((p) => p.productId).join(',');
    if (_loadedFor == key) return;
    _loadedFor = key;
    if (billing.storePackages.isEmpty) return;
    setState(() => _loadingProducts = true);
    try {
      final products = await ref.read(storeBillingProvider).loadProducts(
            billing.storePackages.map((p) => p.productId),
          );
      if (mounted) setState(() => _storeProducts = products);
    } catch (_) {
      // Sem loja (emulador sem Play, por exemplo): os botões mostram o preço de referência.
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _buy(GroupBilling billing, BillingPackage pkg) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(pkg);
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      PurchaseOutcome outcome;
      if (pkg.isSimulated) {
        final updated = await ref.read(billingApiProvider).submitPurchase(
              groupId: _groupId,
              platform: billingPlatform(),
              store: 'simulated',
              productId: pkg.productId,
            );
        outcome = PurchaseOutcome.done(updated);
      } else {
        final product = _storeProducts[pkg.productId];
        if (product == null) {
          outcome = const PurchaseOutcome.failed(
              'Este pacote ainda não está disponível na loja deste aparelho.');
        } else {
          outcome = await ref.read(storeBillingProvider).buy(_groupId, product);
        }
      }

      if (!mounted) return;
      if (outcome.billing != null) {
        ref.invalidate(groupBillingProvider(_groupId));
        messenger.showSnackBar(SnackBar(
          content: Text('Pagamento confirmado. ${outcome.billing!.dueText}.'),
        ));
      } else if (outcome.pending) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Pagamento pendente na loja. Os meses entram quando a loja confirmar.'),
        ));
      } else if (outcome.error != null) {
        messenger.showSnackBar(SnackBar(content: Text(outcome.error!)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(extractDioError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(BillingPackage pkg) {
    final price = _priceOf(pkg);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pagar mais ${pkg.monthsLabel}?'),
        content: Text(
          '${pkg.isSimulated ? 'Compra SIMULADA (teste local). ' : ''}'
          'Valor: $price, pagamento único, sem renovação automática.\n\n'
          'Os meses somam ao vencimento atual: a patota fica paga até ${formatDay(pkg.extendsUntilOn)}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pagar')),
        ],
      ),
    );
  }

  String _priceOf(BillingPackage pkg) =>
      _storeProducts[pkg.productId]?.price ?? formatBrl(pkg.referencePrice);

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref.read(storeBillingProvider).restore();
      ref.invalidate(groupBillingProvider(_groupId));
      if (!mounted) return;
      final text = r.restored > 0
          ? 'Compras restauradas: ${r.groups.join(', ')}.'
          : r.errors.isNotEmpty
              ? r.errors.first
              : 'Nenhuma compra pendente nesta conta da loja. O histórico do plano fica salvo no servidor.';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(extractDioError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = _groupId;
    final async = ref.watch(groupBillingProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Plano da patota')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
            text: extractDioError(e),
            onRetry: () => ref.invalidate(groupBillingProvider(groupId))),
        data: (billing) {
          if (billing == null) {
            return const _Message(
                text:
                    'Só administradores e financeiros da patota veem o plano.');
          }
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _loadStoreProducts(billing));
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(groupBillingProvider(groupId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                GroupPlanSummary(billing: billing),
                const SizedBox(height: 16),
                if (!billing.isLifetime) ...[
                  Text('Pagar mais meses',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Pagamento único, sem renovação automática. Cada pacote soma ao vencimento '
                    'atual, então dá para pagar antes de vencer. Qualquer administrador ou '
                    'financeiro da patota pode pagar.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (billing.purchaseBlockedReason != null)
                    Text(billing.purchaseBlockedReason!)
                  else ...[
                    for (final pkg in billing.storePackages)
                      _PackageTile(
                        pkg: pkg,
                        price: _priceOf(pkg),
                        available: _storeProducts.containsKey(pkg.productId),
                        loading: _loadingProducts,
                        busy: _busy,
                        onTap: () => _buy(billing, pkg),
                      ),
                    if (billing.simulatedPackages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Compra simulada (só no ambiente de teste)',
                          style: Theme.of(context).textTheme.labelLarge),
                      for (final pkg in billing.simulatedPackages)
                        _PackageTile(
                          pkg: pkg,
                          price: formatBrl(pkg.referencePrice),
                          available: true,
                          loading: false,
                          busy: _busy,
                          onTap: () => _buy(billing, pkg),
                        ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar compras'),
                  ),
                  const SizedBox(height: 16),
                ],
                _History(items: billing.history),
                const SizedBox(height: 16),
                _LegalLinks(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Situação, vencimento e dias restantes. Usado na página e no card de Minha patota.
class GroupPlanSummary extends StatelessWidget {
  final GroupBilling billing;
  const GroupPlanSummary({super.key, required this.billing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = billing.isLifetime || billing.status == 'active'
        ? context.appSuccess
        : billing.isExpired || billing.isGrace
            ? theme.colorScheme.error
            : (billing.daysRemaining ?? 99) <= 7
                ? AppColors.warning
                : AppColors.info;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.workspace_premium_outlined, color: color),
              const SizedBox(width: 8),
              Text(billing.statusLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(billing.dueText,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (!billing.trialGranted && billing.status == 'trial') ...[
              const SizedBox(height: 4),
              Text('O teste grátis vale uma vez por criador de patota.',
                  style: theme.textTheme.bodySmall),
            ],
            if (billing.isGrace) ...[
              const SizedBox(height: 4),
              Text(
                  'Ainda dá para usar tudo por ${billing.graceDays} dia(s) depois do vencimento.',
                  style: theme.textTheme.bodySmall),
            ],
            if (billing.isReadOnly) ...[
              const SizedBox(height: 4),
              Text('A patota está em modo somente leitura até alguém pagar.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final BillingPackage pkg;
  final String price;
  final bool available;
  final bool loading;
  final bool busy;
  final VoidCallback onTap;

  const _PackageTile({
    required this.pkg,
    required this.price,
    required this.available,
    required this.loading,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Pagar mais ${pkg.monthsLabel}'),
        subtitle: Text(available || pkg.isSimulated
            ? 'Fica paga até ${formatDay(pkg.extendsUntilOn)}'
            : loading
                ? 'Consultando a loja...'
                : 'Indisponível na loja deste aparelho'),
        trailing:
            Text(price, style: const TextStyle(fontWeight: FontWeight.w800)),
        enabled: !busy && (available || pkg.isSimulated),
        onTap: onTap,
      ),
    );
  }
}

class _History extends StatelessWidget {
  final List<BillingHistoryItem> items;
  const _History({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Histórico', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text('Nenhum pagamento ainda.', style: theme.textTheme.bodySmall),
        for (final h in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              h.state == 'refunded'
                  ? Icons.undo
                  : h.state == 'pending'
                      ? Icons.hourglass_top
                      : Icons.check_circle_outline,
            ),
            title: Text(
                '${h.months == 1 ? '1 mês' : '${h.months} meses'} · ${h.stateLabel}'
                '${h.price != null ? ' · ${formatBrl(h.price!)}' : ''}'),
            subtitle: Text(
              'Pago em ${formatBrasiliaDate(h.purchasedAt)}'
              '${h.payerName != null ? ' por ${h.payerName}' : ''} · ${h.storeLabel}'
              '${h.periodStart != null && h.periodEnd != null ? '\nCobre ${formatBrasiliaDate(h.periodStart!)} a ${formatBrasiliaDate(h.periodEnd!.subtract(const Duration(seconds: 1)))}' : ''}',
            ),
          ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future<void> open(String url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return Wrap(
      spacing: 8,
      children: [
        TextButton(
            onPressed: () => open(AppConstants.termsOfUseUrl),
            child: const Text('Termos de uso')),
        TextButton(
            onPressed: () => open(AppConstants.privacyPolicyUrl),
            child: const Text('Política de privacidade')),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Tentar de novo')),
            ],
          ]),
        ),
      );
}
