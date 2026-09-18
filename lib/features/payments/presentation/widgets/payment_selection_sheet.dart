import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment_entities.dart';
import '../providers/payments_provider.dart';

class PaymentSelectionSheet extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onSaved;

  const PaymentSelectionSheet({
    super.key,
    required this.groupId,
    required this.onSaved,
  });

  @override
  ConsumerState<PaymentSelectionSheet> createState() =>
      _PaymentSelectionSheetState();
}

class _PaymentSelectionSheetState extends ConsumerState<PaymentSelectionSheet> {
  final Set<String> _selectedIds = {};
  bool _saving = false;

  static final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  void _toggle(String id) {
    if (_saving) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _save(List<PendingPaymentItem> items) async {
    final selected =
        items.where((item) => _selectedIds.contains(item.id)).toList();
    if (selected.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(paymentsDsProvider).paySelected(
        widget.groupId,
        {'items': selected.map((item) => item.toPaidRequest()).toList()},
      );
      ref.invalidate(myPendingPaymentItemsProvider(widget.groupId));
      widget.onSaved();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? 'Pagamento registrado com sucesso.'
                : '${selected.length} pagamentos registrados com sucesso.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final itemsAsync = ref.watch(myPendingPaymentItemsProvider(widget.groupId));

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .86,
        child: Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.credit_card_rounded,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerenciar pagamentos',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Selecione as pendências que deseja marcar como pagas.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => _ErrorState(
                    onRetry: () => ref.invalidate(
                      myPendingPaymentItemsProvider(widget.groupId),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) return const _EmptyState();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, index) => index == 0
                          ? const SizedBox(height: 10)
                          : const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Text(
                            'PENDÊNCIAS · ${items.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          );
                        }
                        final item = items[index - 1];
                        return _PaymentItemTile(
                          item: item,
                          selected: _selectedIds.contains(item.id),
                          currency: _currency,
                          onTap: () => _toggle(item.id),
                        );
                      },
                    );
                  },
                ),
              ),
              itemsAsync.maybeWhen(
                data: (items) {
                  final selected = items
                      .where((item) => _selectedIds.contains(item.id))
                      .toList();
                  final total = selected.fold<double>(
                    0,
                    (sum, item) => sum + item.finalAmount,
                  );
                  return _Footer(
                    selectedCount: selected.length,
                    total: total,
                    currency: _currency,
                    saving: _saving,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () => _save(items),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentItemTile extends StatelessWidget {
  final PendingPaymentItem item;
  final bool selected;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _PaymentItemTile({
    required this.item,
    required this.selected,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: .45)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              IgnorePointer(
                child: Checkbox(
                  value: selected,
                  onChanged: (_) {},
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.discount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'De ${currency.format(item.amount)} · desconto de ${currency.format(item.discount)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currency.format(item.finalAmount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int selectedCount;
  final double total;
  final NumberFormat currency;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _Footer({
    required this.selectedCount,
    required this.total,
    required this.currency,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedCount == 0
                    ? 'Nenhum item selecionado'
                    : '$selectedCount ${selectedCount == 1 ? 'item selecionado' : 'itens selecionados'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                currency.format(total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: selectedCount == 0 || saving ? null : onSave,
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar alterações'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 38,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Tudo em dia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Você não possui pagamentos pendentes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar suas pendências.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}
