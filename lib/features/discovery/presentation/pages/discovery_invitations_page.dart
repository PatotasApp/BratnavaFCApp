import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class DiscoveryInvitationsPage extends ConsumerStatefulWidget {
  const DiscoveryInvitationsPage({super.key});

  @override
  ConsumerState<DiscoveryInvitationsPage> createState() => _State();
}

class _State extends ConsumerState<DiscoveryInvitationsPage> {
  List<MatchApplication> _items = [];
  bool _loading = true;
  String? _answering;

  DiscoveryDataSource get _api => DiscoveryDataSource(ref.read(dioProvider));

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final items = await _api.myApplications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _answer(MatchApplication item, bool accept) async {
    setState(() => _answering = item.id);
    try {
      if (accept) {
        await _api.acceptInvitation(item.id);
      } else {
        await _api.rejectInvitation(item.id);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Presença confirmada. Bom jogo!' : 'Convite recusado.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _answering = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Convites para jogar')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 160),
                          Icon(Icons.sports_soccer_rounded, size: 52),
                          SizedBox(height: 14),
                          Text(
                            'Nenhum convite ou candidatura.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          return _InvitationCard(
                            item: item,
                            loading: _answering == item.id,
                            onAccept: () => _answer(item, true),
                            onReject: () => _answer(item, false),
                          );
                        },
                      ),
              ),
      );
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.item,
    required this.loading,
    required this.onAccept,
    required this.onReject,
  });

  final MatchApplication item;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final needsAnswer = item.status == 2;
    final status = switch (item.status) {
      1 => 'Aguardando análise da patota',
      2 => 'Você foi aceito · confirme sua presença',
      3 => 'Presença confirmada',
      4 => 'Não aprovado',
      _ => 'Cancelado',
    };
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.groupName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        DateFormat("dd/MM 'às' HH:mm").format(item.playedAt),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((item.placeName ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 17),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item.placeName!)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: needsAnswer ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            if ((item.decisionReason ?? item.message)?.trim().isNotEmpty ==
                true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14)),
                child: Text((item.decisionReason ?? item.message)!.trim()),
              ),
            ],
            if (needsAnswer) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : onReject,
                      child: const Text('Não vou'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading ? null : onAccept,
                      icon: loading
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Estou dentro'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
