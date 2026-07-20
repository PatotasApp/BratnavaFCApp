import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/payments_provider.dart';

class ExitPendingPaymentsSheet extends ConsumerStatefulWidget {
  const ExitPendingPaymentsSheet({
    super.key,
    required this.pending,
    required this.title,
    required this.forceLabel,
    required this.onContinueAfterPayment,
    required this.onForceContinue,
  });

  final Map<String, dynamic> pending;
  final String title;
  final String forceLabel;
  final Future<void> Function() onContinueAfterPayment;
  final Future<void> Function() onForceContinue;

  @override
  ConsumerState<ExitPendingPaymentsSheet> createState() =>
      _ExitPendingPaymentsSheetState();
}

class _ExitPendingPaymentsSheetState
    extends ConsumerState<ExitPendingPaymentsSheet> {
  late final Set<String> _selected;
  bool _saving = false;

  List<Map<String, dynamic>> get _groups =>
      ((widget.pending['groups'] ?? widget.pending['Groups']) as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final group in _groups)
        for (final item in ((group['items'] ?? group['Items']) as List? ?? []))
          if (item is Map) (item['id'] ?? item['Id']).toString(),
    };
  }

  String _money(num value) => 'R\$ ${value.toStringAsFixed(2)}';

  Future<void> _payAndContinue() async {
    setState(() => _saving = true);
    try {
      final ds = ref.read(paymentsDsProvider);
      for (final group in _groups) {
        final groupId = (group['groupId'] ?? group['GroupId']).toString();
        final rawItems = ((group['items'] ?? group['Items']) as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((item) => _selected.contains((item['id'] ?? item['Id']).toString()))
            .toList();
        if (rawItems.isEmpty) continue;
        await ds.paySelected(groupId, {
          'items': rawItems.map((item) => {
                'type': item['type'] ?? item['Type'],
                'year': item['year'] ?? item['Year'],
                'month': item['month'] ?? item['Month'],
                'chargeId': item['chargeId'] ?? item['ChargeId'],
                'isPaid': true,
              }).toList(),
        });
      }
      await widget.onContinueAfterPayment();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _forceContinue() async {
    setState(() => _saving = true);
    try {
      await widget.onForceContinue();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.pending['count'] ?? widget.pending['Count'] ?? 0;
    final selectedTotal = _groups.fold<double>(0, (sum, group) {
      final items = ((group['items'] ?? group['Items']) as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e));
      return sum +
          items
              .where((item) => _selected.contains((item['id'] ?? item['Id']).toString()))
              .fold<double>(0, (s, item) => s + ((item['finalAmount'] ?? item['FinalAmount'] ?? 0) as num).toDouble());
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$count pendência(s) encontrada(s).', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final group = _groups[index];
                    final items = ((group['items'] ?? group['Items']) as List? ?? [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text((group['groupName'] ?? group['GroupName'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text((group['playerName'] ?? group['PlayerName'] ?? '').toString()),
                            trailing: Text(_money(((group['total'] ?? group['Total'] ?? 0) as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          ...items.map((item) {
                            final id = (item['id'] ?? item['Id']).toString();
                            final checked = _selected.contains(id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (_) => setState(() {
                                checked ? _selected.remove(id) : _selected.add(id);
                              }),
                              title: Text((item['description'] ?? item['Description'] ?? '').toString()),
                              secondary: Text(_money(((item['finalAmount'] ?? item['FinalAmount'] ?? 0) as num).toDouble())),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Selecionado'),
                  const Spacer(),
                  Text(_money(selectedTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _forceContinue,
                      child: Text(widget.forceLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving || _selected.isEmpty ? null : _payAndContinue,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Pagar e continuar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
