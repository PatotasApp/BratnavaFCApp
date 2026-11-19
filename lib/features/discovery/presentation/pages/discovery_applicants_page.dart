import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class DiscoveryApplicantsPage extends ConsumerStatefulWidget {
  const DiscoveryApplicantsPage({super.key});
  @override
  ConsumerState<DiscoveryApplicantsPage> createState() => _State();
}

class _State extends ConsumerState<DiscoveryApplicantsPage> {
  List<MatchApplication> items = [];
  bool loading = true;
  DiscoveryDataSource get api => DiscoveryDataSource(ref.read(dioProvider));
  String get groupId =>
      ref.read(accountStoreProvider).activeAccount?.activeGroupId ?? '';
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  /// Pendentes primeiro; o histórico (confirmadas, recusadas, canceladas)
  /// vem depois e nunca some da lista.
  List<Object> get _rows {
    final open = items.where((x) => x.status == 1 || x.status == 2).toList();
    final done = items.where((x) => x.status >= 3).toList();
    return [
      if (open.isNotEmpty) 'PENDENTES',
      ...open,
      if (done.isNotEmpty) 'HISTÓRICO',
      ...done,
    ];
  }

  Future<void> load() async {
    final value = groupId.isEmpty
        ? <MatchApplication>[]
        : await api.applications(groupId);
    if (mounted)
      setState(() {
        items = value;
        loading = false;
      });
  }

  Future<void> approve(MatchApplication item) async {
    final guests = await api.guestCandidates(groupId, item.userId);
    if (!mounted) return;
    final linked = guests.where((g) => g.linked);
    String? selected = linked.isEmpty ? null : linked.first.id;
    final reason = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Aprovar ${item.name}',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Reaproveite um convidado antigo se for a mesma pessoa.',
              ),
              const SizedBox(height: 18),
              if (item.message?.trim().isNotEmpty == true) ...[
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color:
                            Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14)),
                    child: Text('“${item.message!.trim()}”')),
                const SizedBox(height: 14),
              ],
              DropdownButtonFormField<String?>(
                value: selected,
                decoration: const InputDecoration(
                  labelText: 'Perfil de convidado',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Criar jogador externo'),
                  ),
                  ...guests.map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(
                        '${g.name} · ${g.origin == 1 ? 'manual' : 'externo'}',
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setModal(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: reason,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Mensagem da aprovação (opcional)')),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aprovar e convidar'),
              ),
            ],
          ),
        ),
      ),
    );
    final note = reason.text.trim();
    reason.dispose();
    if (ok == true) {
      final done = await _run(
        () => api.approve(groupId, item.id, selected,
            reason: note.isEmpty ? null : note),
        'Não foi possível aprovar ${item.name}. A solicitação pode já ter sido '
        'respondida.',
      );
      if (done) {
        _toast('${item.name} aprovado. Agora ele precisa confirmar que vai '
            'jogar.');
      }
      await load();
    }
  }

  /// Executa a ação e avisa o administrador se falhar, em vez de deixar a
  /// exceção solta (o botão parecia não fazer nada ou repetia o erro).
  Future<bool> _run(Future<void> Function() action, String error) async {
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) _toast(error, isError: true);
      return false;
    }
  }

  void _toast(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        content: Text(text),
      ));
  }

  Future<void> reject(MatchApplication item) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Recusar solicitação'),
                content: TextField(
                    controller: controller,
                    maxLength: 500,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Motivo (opcional)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Recusar'))
                ]));
    if (ok != true) {
      controller.dispose();
      return;
    }
    final note = controller.text.trim();
    controller.dispose();
    final done = await _run(
      () => api.reject(groupId, item.id, reason: note.isEmpty ? null : note),
      'Não foi possível recusar ${item.name}. A solicitação pode já ter sido '
      'respondida.',
    );
    if (done) _toast('Solicitação de ${item.name} recusada.');
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Interessados em jogar')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 150),
                          Icon(Icons.person_search_outlined, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma candidatura pendente.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final row = _rows[i];
                          if (row is String) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
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
                          final x = row as MatchApplication;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      AvatarWidget(
                                        name: x.name,
                                        photoUrl: x.photoUrl,
                                        size: 52,
                                        borderRadius: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              x.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              '@${x.userName}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '${DateFormat('dd/MM · HH:mm').format(x.playedAt)}${x.position == null ? '' : ' · ${x.position == 2 ? 'Linha' : x.position == 3 ? 'Goleiro' : 'Qualquer posição'}'}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (x.status == 3 ||
                                          x.status == 4 ||
                                          x.status == 5)
                                        // Histórico: a solicitação foi
                                        // concluída, mas continua visível.
                                        Text(
                                          x.status == 3
                                              ? 'Confirmado'
                                              : x.status == 4
                                                  ? 'Recusado'
                                                  : 'Cancelado',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: x.status == 3
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                          ),
                                        )
                                      else if (x.status == 2)
                                        // PendingPlayer: o administrador já
                                        // aprovou; falta o jogador confirmar.
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.hourglass_top_rounded,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Aguardando\no jogador',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        IconButton(
                                          onPressed: () => reject(x),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          tooltip: 'Recusar',
                                        ),
                                        const SizedBox(width: 12),
                                        FilledButton.tonal(
                                          onPressed: () => approve(x),
                                          child: const Text('Aprovar'),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (x.status >= 3 &&
                                      x.decisionReason?.trim().isNotEmpty ==
                                          true) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Motivo: ${x.decisionReason!.trim()}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                  if (x.message?.trim().isNotEmpty == true) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('“${x.message!.trim()}”'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      );
}
