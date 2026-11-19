import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  bool _finished(MatchApplication x) => x.matchStatus >= 4;

  /// A partida ainda aceita respostas (criada ou em aceitação). Depois que a
  /// patota passa para a formação dos times, o convite não pode mais ser aceito.
  bool _open(MatchApplication x) => x.matchStatus <= 1;

  /// Aguardando resposta ou partida ainda por jogar. O que pede resposta vem primeiro.
  List<MatchApplication> get _active => (_items
      .where((x) =>
          (x.status == 3 && !_finished(x)) ||
          ((x.status == 1 || x.status == 2) && _open(x)))
      .toList()
    ..sort((a, b) {
      int rank(MatchApplication x) => x.status == 2 ? 0 : 1;
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.playedAt.compareTo(b.playedAt);
    }));

  /// Partidas em que jogou. Nos primeiros 7 dias ficam em destaque; depois, só no histórico.
  List<MatchApplication> _played({required bool recent}) {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    return (_items
        .where((x) =>
            x.status == 3 &&
            _finished(x) &&
            (x.playedAt.isAfter(limit) == recent))
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt)));
  }

  /// Recusadas, canceladas e as que nunca chegaram a ser respondidas. Nada some.
  List<MatchApplication> get _notConcluded => (_items
      .where((x) => x.status >= 4 || (x.status < 3 && !_open(x)))
      .toList()
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt)));

  List<Object> get _rows => [
        if (_active.isNotEmpty) 'PRÓXIMAS',
        ..._active,
        if (_played(recent: true).isNotEmpty) 'ENCERRADAS RECENTEMENTE',
        ..._played(recent: true),
        if (_played(recent: false).isNotEmpty) 'JOGOS QUE JOGUEI',
        ..._played(recent: false),
        if (_notConcluded.isNotEmpty) _notConcluded,
      ];

  Widget _card(MatchApplication item) => _InvitationCard(
        item: item,
        loading: _answering == item.id,
        onAccept: () => _answer(item, true),
        onReject: () => _answer(item, false),
      );

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
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final row = _rows[index];
                          if (row is String) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                row,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            );
                          }
                          if (row is List<MatchApplication>) {
                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              shape: const Border(),
                              collapsedShape: const Border(),
                              title: Text(
                                'NÃO CONCLUÍDOS (${row.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              childrenPadding: EdgeInsets.zero,
                              children: [
                                for (final item in row)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _card(item),
                                  ),
                              ],
                            );
                          }
                          return _card(row as MatchApplication);
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
    final open = item.matchStatus <= 1;
    final needsAnswer = item.status == 2 && open;
    final status = switch (item.status) {
      1 when !open => 'Sem análise · a partida seguiu sem essa candidatura',
      2 when !open =>
        'Você foi aceito, mas não respondeu a tempo · a partida já seguiu',
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
            // Os dados da partida só abrem para quem jogou (confirmado) ou
            // enquanto ainda dá para responder. Quem ficou de fora vê só o status.
            if (item.matchId.isNotEmpty &&
                (item.status == 3 ||
                    ((item.status == 2 || item.status == 5) && open))) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/app/guest-match/${item.matchId}'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(item.matchStatus >= 4
                      ? 'Ver resultado'
                      : 'Acompanhar partida'),
                ),
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
