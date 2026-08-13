import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/realtime/realtime_provider.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../polls/domain/entities/poll_detail.dart';
import '../../../polls/domain/entities/poll_summary.dart';
import '../../../polls/presentation/providers/polls_provider.dart';
import '../../../polls/presentation/widgets/event_detail_sheet.dart';
import '../../../polls/presentation/widgets/poll_detail_sheet.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_stepper_header.dart';
import 'step2_aceitacao_page.dart';
import 'step3_matchmaking_page.dart';
import 'step4_jogo_page.dart';
import 'step5_encerrar_page.dart';
import 'step6_pos_jogo_page.dart';
import 'step7_final_page.dart';

final _linkedPollDetailProvider = FutureProvider.autoDispose
    .family<PollDetail, ({String groupId, String pollId})>(
  (ref, args) => ref.watch(pollsDsProvider).getPoll(args.groupId, args.pollId),
);

class MatchesPage extends ConsumerStatefulWidget {
  final String? initialMatchId;
  const MatchesPage({super.key, this.initialMatchId});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  // ── Formulário Step 1 ─────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _placeCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _formInited = false;

  // ── Pré-visualização (admin) ──────────────────────────────────────────────
  MatchStep? _previewStep;

  // ── Criação inline de nova partida ────────────────────────────────────────
  bool _creatingNew = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = widget.initialMatchId;
      if (id != null && id.isNotEmpty) {
        await ref.read(matchNotifierProvider.notifier).loadMatchById(id);
      } else {
        await ref.read(matchNotifierProvider.notifier).loadInitial();
      }
    });
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    super.dispose();
  }

  // ── Pré-preenche formulário com defaults do grupo ──────────────────────────
  void _initForm(MatchState s) {
    if (_formInited) return;
    _formInited = true;
    if (s.groupSettings?.defaultPlaceName != null && _placeCtrl.text.isEmpty) {
      _placeCtrl.text = s.groupSettings!.defaultPlaceName!;
    }
    final raw = s.groupSettings?.defaultKickoffTime;
    if (raw != null) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        _time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
  }

  // Não usar ref.read aqui — precisa de ref.watch para reagir ao refreshRoles().
  bool _isAdmin(Account? acc, String groupId) {
    return groupId.isNotEmpty && (acc?.isGroupAdmin(groupId) ?? false);
  }

  // ── Cria partida (Step 1) ─────────────────────────────────────────────────
  Future<void> _createMatch() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final placeName = _placeCtrl.text.trim();
    final playedAt =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    await ref
        .read(matchNotifierProvider.notifier)
        .createMatch(placeName, playedAt);
    if (mounted) setState(() => _creatingNew = false);
  }

  Future<void> _editCurrentMatch(MatchState s) async {
    final matchId = s.matchId;
    final currentDate = s.playedAt;
    if (matchId == null || matchId.isEmpty || currentDate == null) return;

    final placeCtrl = TextEditingController(text: s.placeName ?? '');
    DateTime selected = currentDate;

    final saved = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: selected,
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 3),
            );
            if (picked == null) return;
            setLocalState(() {
              selected = DateTime(
                picked.year,
                picked.month,
                picked.day,
                selected.hour,
                selected.minute,
              );
            });
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(
                hour: selected.hour,
                minute: selected.minute,
              ),
            );
            if (picked == null) return;
            setLocalState(() {
              selected = DateTime(
                selected.year,
                selected.month,
                selected.day,
                picked.hour,
                picked.minute,
              );
            });
          }

          return AlertDialog(
            title: const Text('Alterar partida'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: placeCtrl,
                  decoration: const InputDecoration(labelText: 'Local'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickDate,
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text(
                          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickTime,
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    final place = placeCtrl.text.trim();
    placeCtrl.dispose();
    if (saved == null || place.isEmpty) return;

    final ok = await ref
        .read(matchNotifierProvider.notifier)
        .updateMatch(place, saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Partida atualizada.' : 'Erro ao atualizar partida.'),
      ),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  // ── Conteúdo por etapa ────────────────────────────────────────────────────
  Widget _buildStepContent(MatchState s, bool isAdmin, String groupId) {
    if (!s.hasMatch || _creatingNew) {
      return isAdmin
          ? _CreateMatchView(
              formKey: _formKey,
              placeCtrl: _placeCtrl,
              date: _date,
              time: _time,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
              onCreate: _createMatch,
              mutating: s.mutating,
              onCancel: s.hasMatch
                  ? () => setState(() => _creatingNew = false)
                  : null,
            )
          : const _WaitingForMatchView();
    }

    final display = _previewStep ?? s.step;
    switch (display) {
      case MatchStep.create:
        return isAdmin
            ? _CreateMatchView(
                formKey: _formKey,
                placeCtrl: _placeCtrl,
                date: _date,
                time: _time,
                onPickDate: _pickDate,
                onPickTime: _pickTime,
                onCreate: _createMatch,
                mutating: s.mutating,
              )
            : const _WaitingForMatchView();
      case MatchStep.accept:
        return Step2AceitacaoPage(
          linkedPollStrip: s.hasMatch
              ? _LinkedPollStrip(
                  groupId: groupId,
                  linkedPollId: s.linkedPollId,
                  isAdmin: isAdmin,
                  onLink: (pollId) => ref
                      .read(matchNotifierProvider.notifier)
                      .setLinkedPoll(pollId),
                  onUnlink: () => ref
                      .read(matchNotifierProvider.notifier)
                      .setLinkedPoll(null),
                )
              : null,
        );
      case MatchStep.teams:
        return const Step3MatchmakingPage();
      case MatchStep.playing:
        return const Step4JogoPage();
      case MatchStep.ended:
        return const Step5EncerrarPage();
      case MatchStep.post:
        return const Step6PosJogoPage();
      case MatchStep.done:
        return const Step7FinalPage();
    }
  }

  // ── Excluir partida (com confirmação) ────────────────────────────────────
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir partida'),
        content: const Text(
          'Tem certeza que deseja excluir esta partida? '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(matchNotifierProvider.notifier).deleteMatch();
    }
  }

  // ── Voltar etapa (com confirmação) ───────────────────────────────────────
  Future<void> _rewindStep() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voltar etapa'),
        content: const Text(
          'Tem certeza que deseja voltar para a etapa anterior? '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amber500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Voltar etapa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(matchNotifierProvider.notifier).rewindStep();
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    // watch (não read) para reagir ao refreshRoles() assíncrono do startup
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin = _isAdmin(account, groupId);

    if (groupId.isNotEmpty) {
      ref.listen<AsyncValue<BratnavaRealtimeEvent>>(
        realtimeEventsProvider(groupId),
        (_, next) {
          next.whenData((event) {
            if (event.type == 'match.changed') {
              ref.read(matchNotifierProvider.notifier).refresh();
            } else if (event.type == 'poll.changed') {
              ref.invalidate(pollsListProvider(groupId));
              final pollId = event.pollId;
              if (pollId != null && pollId.isNotEmpty) {
                ref.invalidate(_linkedPollDetailProvider(
                    (groupId: groupId, pollId: pollId)));
              }
            }
          });
        },
      );
    }

    if (!s.loading && s.groupSettings != null) _initForm(s);

    if (s.loading) return const Center(child: CircularProgressIndicator());

    if (s.error != null && !s.hasMatch) {
      return _ErrorView(
        message: s.error!,
        onRetry: () => ref.read(matchNotifierProvider.notifier).loadInitial(),
      );
    }

    final currentStep = s.hasMatch ? s.step : MatchStep.create;
    final displayedStep = _previewStep ?? currentStep;
    final stepHeaderWidgets = <Widget>[
      if (s.upcomingHeaders.length > 1)
        _MatchSelector(
          headers: s.upcomingHeaders,
          selected: s.selectedMatchIdx,
          onSelect: (i) {
            setState(() => _creatingNew = false);
            ref.read(matchNotifierProvider.notifier).selectMatch(i);
          },
        ),
      MatchStepperHeader(
        currentStep: currentStep,
        previewStep: _previewStep,
        onStepTap: isAdmin && s.hasMatch
            ? (step) => setState(() {
                  _previewStep = (_previewStep == step || step == currentStep)
                      ? null
                      : step;
                })
            : null,
      ),
      if (s.hasMatch && currentStep != MatchStep.accept)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _LinkedPollStrip(
            groupId: groupId,
            linkedPollId: s.linkedPollId,
            isAdmin: isAdmin,
            onLink: (pollId) =>
                ref.read(matchNotifierProvider.notifier).setLinkedPoll(pollId),
            onUnlink: () =>
                ref.read(matchNotifierProvider.notifier).setLinkedPoll(null),
          ),
        ),
      if (_previewStep != null && _previewStep != currentStep)
        _PreviewBanner(
          previewStep: _previewStep!,
          currentStep: currentStep,
          onDismiss: () => setState(() => _previewStep = null),
        ),
    ];

    // A formação já possui botão fixo e um scroll próprio. Mantê-la dentro do
    // Expanded + NestedScrollView posicionava o corpo depois de todo o header
    // externo: o RenderBox recebia altura, mas era pintado fora da viewport.
    // Nesta etapa, banner, progresso e gerador formam uma única superfície.
    if (displayedStep == MatchStep.teams) {
      return Step3MatchmakingPage(
        scrollHeader: Column(
          children: [
            _MatchBanner(
              s: s,
              isAdmin: isAdmin,
              canRewind: isAdmin && s.hasMatch && s.canRewind,
              onRefresh: () =>
                  ref.read(matchNotifierProvider.notifier).refresh(),
              onRewind: _rewindStep,
              onEdit: isAdmin && s.hasMatch ? () => _editCurrentMatch(s) : null,
              onDelete: isAdmin && s.hasMatch ? _confirmDelete : null,
              onCreateNew: isAdmin
                  ? () {
                      ref.read(matchNotifierProvider.notifier).clearSelection();
                      setState(() {
                        _creatingNew = true;
                        _previewStep = null;
                      });
                    }
                  : null,
            ),
            ...stepHeaderWidgets,
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            _MatchBanner(
              s: s,
              isAdmin: isAdmin,
              canRewind: isAdmin && s.hasMatch && s.canRewind,
              onRefresh: () =>
                  ref.read(matchNotifierProvider.notifier).refresh(),
              onRewind: _rewindStep,
              onEdit: isAdmin && s.hasMatch ? () => _editCurrentMatch(s) : null,
              onDelete: isAdmin && s.hasMatch ? _confirmDelete : null,
              onCreateNew: isAdmin
                  ? () {
                      ref.read(matchNotifierProvider.notifier).clearSelection();
                      setState(() {
                        _creatingNew = true;
                        _previewStep = null;
                      });
                    }
                  : null,
            ),
            // Seletor, cabeçalho de etapa e banners ficavam empilhados acima do
            // conteúdo, fora de qualquer área rolável: só a metade de baixo da
            // tela rolava, e num passo com muitos jogadores o cabeçalho comia
            // espaço permanentemente. Como slivers de um NestedScrollView eles
            // saem de cena junto com o conteúdo, sem que cada página de etapa
            // precise ser reestruturada — o `Expanded` interno de cada uma
            // continua recebendo altura, e rodapés de ação seguem fixos.
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  if (s.upcomingHeaders.length > 1)
                    SliverToBoxAdapter(
                      child: _MatchSelector(
                        headers: s.upcomingHeaders,
                        selected: s.selectedMatchIdx,
                        onSelect: (i) {
                          setState(() => _creatingNew = false);
                          ref
                              .read(matchNotifierProvider.notifier)
                              .selectMatch(i);
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: MatchStepperHeader(
                      currentStep: currentStep,
                      previewStep: _previewStep,
                      onStepTap: isAdmin && s.hasMatch
                          ? (step) => setState(() {
                                _previewStep = (_previewStep == step ||
                                        step == currentStep)
                                    ? null
                                    : step;
                              })
                          : null,
                    ),
                  ),
                  if (s.hasMatch && currentStep != MatchStep.accept)
                    SliverToBoxAdapter(
                      // O respiro horizontal agora é de quem usa o strip; no
                      // passo 2 ele vem do padding da própria área rolável.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _LinkedPollStrip(
                          groupId: groupId,
                          linkedPollId: s.linkedPollId,
                          isAdmin: isAdmin,
                          onLink: (pollId) => ref
                              .read(matchNotifierProvider.notifier)
                              .setLinkedPoll(pollId),
                          onUnlink: () => ref
                              .read(matchNotifierProvider.notifier)
                              .setLinkedPoll(null),
                        ),
                      ),
                    ),
                  if (_previewStep != null && _previewStep != currentStep)
                    SliverToBoxAdapter(
                      child: _PreviewBanner(
                        previewStep: _previewStep!,
                        currentStep: currentStep,
                        onDismiss: () => setState(() => _previewStep = null),
                      ),
                    ),
                ],
                body: _buildStepContent(s, isAdmin, groupId),
              ),
            ),
          ],
        ), // Column
      ], // Stack
    );
  }
}

// ── Banner escuro ─────────────────────────────────────────────────────────────

class _MatchBanner extends StatelessWidget {
  final MatchState s;
  final bool isAdmin;
  final bool canRewind;
  final VoidCallback onRefresh;
  final VoidCallback onRewind;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCreateNew;

  const _MatchBanner({
    required this.s,
    required this.isAdmin,
    required this.canRewind,
    required this.onRefresh,
    required this.onRewind,
    this.onEdit,
    this.onDelete,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final rewindBlockedReason = switch (s.step) {
      MatchStep.accept =>
        'A etapa de aceitação não pode voltar para a criação.',
      MatchStep.playing ||
      MatchStep.ended ||
      MatchStep.post ||
      MatchStep.done =>
        'Uma partida já iniciada não pode voltar de etapa.',
      MatchStep.create => 'Esta já é a primeira etapa da partida.',
      MatchStep.teams => null,
    };

    return AppPageHeader.main(
      title: 'Partidas',
      icon: Icons.sports_soccer_rounded,
      footer: AppPageHeaderActionBar(actions: [
        PopupMenuButton<_MatchHeaderAction>(
          tooltip: 'Mais ações',
          onSelected: (action) {
            switch (action) {
              case _MatchHeaderAction.edit:
                onEdit?.call();
              case _MatchHeaderAction.rewind:
                // A etapa atual prevalece sobre `canRewind`, pois esse valor
                // pode ter vindo de um header anterior durante um refresh.
                // Aceitação nunca pode retornar para criação.
                if (rewindBlockedReason != null) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(rewindBlockedReason)),
                    );
                } else if (canRewind) {
                  onRewind();
                }
              case _MatchHeaderAction.delete:
                onDelete?.call();
              case _MatchHeaderAction.create:
                onCreateNew?.call();
              case _MatchHeaderAction.refresh:
                onRefresh();
            }
          },
          itemBuilder: (context) => [
            if (onEdit != null)
              const PopupMenuItem(
                value: _MatchHeaderAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Alterar partida'),
                ),
              ),
            if (isAdmin && s.hasMatch)
              const PopupMenuItem(
                value: _MatchHeaderAction.rewind,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.undo_rounded),
                  title: Text('Voltar uma etapa'),
                ),
              ),
            if (onDelete != null)
              const PopupMenuItem(
                value: _MatchHeaderAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Excluir partida'),
                ),
              ),
            if (isAdmin && onCreateNew != null)
              const PopupMenuItem(
                value: _MatchHeaderAction.create,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_circle_outline_rounded),
                  title: Text('Nova partida'),
                ),
              ),
            const PopupMenuItem(
              value: _MatchHeaderAction.refresh,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.refresh_rounded),
                title: Text('Atualizar'),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz_rounded, size: 18),
                SizedBox(width: 8),
                Text('Ações'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

enum _MatchHeaderAction { edit, rewind, delete, create, refresh }

// ── Strip de votação/evento vinculado ────────────────────────────────────────

class _LinkedPollStrip extends ConsumerWidget {
  final String groupId;
  final String? linkedPollId;
  final bool isAdmin;
  final void Function(String) onLink;
  final VoidCallback onUnlink;

  const _LinkedPollStrip({
    required this.groupId,
    required this.linkedPollId,
    required this.isAdmin,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pollsAsync = ref.watch(pollsListProvider(groupId));
    final polls = pollsAsync.valueOrNull ?? [];

    // Encontra o poll vinculado na lista
    PollSummary? linked;
    if (linkedPollId != null && linkedPollId!.isNotEmpty) {
      try {
        linked = polls.firstWhere((p) => p.id == linkedPollId);
      } catch (_) {
        linked = null;
      }
    }

    // Se não tem vínculo e não é admin → não mostra nada
    if (linked == null && !isAdmin) return const SizedBox.shrink();

    // Sem faixa cinza de ponta a ponta: no protótipo isto é um card, com
    // borda e cantos, igual aos demais da tela. O respiro horizontal fica com
    // quem usa o widget — dentro do passo 2 ele já vive numa área com padding.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: linked != null
          ? _LinkedRow(
              poll: linked,
              detail: ref
                  .watch(_linkedPollDetailProvider(
                      (groupId: groupId, pollId: linked.id)))
                  .valueOrNull,
              isAdmin: isAdmin,
              onUnlink: onUnlink,
              onOpen: (ctx) => _openPollModal(ctx, ref, linked!),
            )
          : _UnlinkRow(
              isDark: isDark,
              onTap: () => _openPicker(context, polls),
            ),
    );
  }

  void _openPicker(BuildContext context, List<PollSummary> all) {
    final open = all.where((p) => p.isOpen).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _PollPickerSheet(
        polls: open,
        onPick: onLink,
      ),
    );
  }

  Future<void> _openPollModal(
      BuildContext context, WidgetRef ref, PollSummary summary) async {
    try {
      final detail =
          await ref.read(pollsDsProvider).getPoll(groupId, summary.id);
      if (!context.mounted) return;
      final sheet = detail.isEvent
          ? EventDetailSheet(
              poll: detail,
              groupId: groupId,
              isAdmin: isAdmin,
              onUpdated: (_) {},
            )
          : PollDetailSheet(
              poll: detail,
              groupId: groupId,
              isAdmin: isAdmin,
              onUpdated: (_) {},
            );
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.transparent,
        builder: (_) => sheet,
      );
    } catch (_) {}
  }
}

class _LinkedRow extends StatelessWidget {
  final PollSummary poll;
  final PollDetail? detail;
  final bool isAdmin;
  final VoidCallback onUnlink;
  final void Function(BuildContext) onOpen;
  const _LinkedRow({
    required this.poll,
    required this.detail,
    required this.isAdmin,
    required this.onUnlink,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final responses = poll.totalVoters;
    final presence = detail != null ? _EventPresenceStats.from(detail!) : null;
    final summaryText = poll.isEvent && presence != null
        ? '$responses ${responses == 1 ? 'voto' : 'votos'} - ${presence.label}'
        : '$responses ${responses == 1 ? 'resposta' : 'respostas'}';
    final label = poll.isEvent ? 'Evento' : 'Votação';
    final statusText = poll.isOpen ? 'Aberta' : 'Encerrada';
    final statusColor = poll.isOpen
        ? AppColors.successOf(theme.brightness)
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => onOpen(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .22)),
              ),
              child: poll.eventIcon != null && poll.eventIcon!.isNotEmpty
                  ? Text(poll.eventIcon!, style: const TextStyle(fontSize: 20))
                  : Icon(
                      poll.isEvent ? Icons.event_rounded : Icons.poll_rounded,
                      size: 20,
                      color: color,
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          poll.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          onPressed: onUnlink,
                          tooltip: 'Desvincular evento',
                          visualDensity: VisualDensity.compact,
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _Badge(
                        label: statusText,
                        fg: statusColor,
                        bg: statusColor.withValues(alpha: .1),
                        border: statusColor.withValues(alpha: .3),
                      ),
                      if (poll.hasVoted)
                        _Badge(
                          label: '✓ Votou',
                          fg: color,
                          bg: color.withValues(alpha: .08),
                          border: color.withValues(alpha: .25),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$summaryText · $label',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Abrir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventPresenceStats {
  final int going;
  final int guests;

  const _EventPresenceStats({required this.going, required this.guests});

  int get total => going + guests;

  String get label {
    return '$total ${total == 1 ? 'presença' : 'presenças'}';
  }

  factory _EventPresenceStats.from(PollDetail poll) {
    String? goingOptionId;
    try {
      goingOptionId =
          poll.options.firstWhere((o) => o.text.toLowerCase() == 'sim').id;
    } catch (_) {
      goingOptionId = null;
    }

    final goingVotes = goingOptionId == null
        ? <PollVote>[]
        : (poll.votes ?? <PollVote>[])
            .where((vote) => vote.optionId == goingOptionId)
            .toList();
    final guestCount = poll.allowGuests
        ? goingVotes.fold<int>(0, (sum, vote) => sum + vote.guests.length)
        : 0;

    return _EventPresenceStats(
      going: goingVotes.length,
      guests: guestCount,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color fg, bg, border;
  const _Badge(
      {required this.label,
      required this.fg,
      required this.bg,
      required this.border});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      );
}

class _UnlinkRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _UnlinkRow({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Card com borda e chevron, como no protótipo. Antes era uma linha solta
    // de texto cinza-claro sobre faixa cinza: não parecia clicável e o
    // contraste do rótulo ficava fraco.
    final label = isDark ? AppColors.slate300 : AppColors.slate700;
    return Material(
      color: isDark ? AppColors.slate800 : AppColors.onDark,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_link_rounded, size: 18, color: label),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vincular votação ou evento',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: label,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? AppColors.slate500 : AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollPickerSheet extends StatelessWidget {
  final List<PollSummary> polls;
  final void Function(String) onPick;
  const _PollPickerSheet({required this.polls, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Vincular votação / evento',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.onDark : AppColors.slate900,
                )),
          ),
          if (polls.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.poll_outlined,
                    size: 36,
                    color: isDark ? AppColors.slate600 : AppColors.slate300),
                const SizedBox(height: 10),
                Text('Nenhuma votação/evento aberto',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    )),
              ]),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: polls.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? AppColors.slate800 : AppColors.slate100),
                itemBuilder: (_, i) {
                  final p = polls[i];
                  final color =
                      p.isEvent ? AppColors.violet600 : AppColors.infoLight;
                  return ListTile(
                    leading: p.eventIcon != null && p.eventIcon!.isNotEmpty
                        ? Text(p.eventIcon!,
                            style: const TextStyle(fontSize: 20))
                        : Icon(
                            p.isEvent
                                ? Icons.event_rounded
                                : Icons.poll_rounded,
                            size: 20,
                            color: color),
                    title: Text(p.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.onDark : AppColors.slate900,
                        )),
                    subtitle: Text(p.isEvent ? 'Evento' : 'Votação',
                        style: TextStyle(fontSize: 12, color: color)),
                    trailing: Icon(Icons.link_rounded,
                        size: 18,
                        color:
                            isDark ? AppColors.slate500 : AppColors.slate400),
                    onTap: () {
                      Navigator.pop(context);
                      onPick(p.id);
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── Seletor de partidas (quando há mais de 1 upcoming) ───────────────────────

class _MatchSelector extends StatelessWidget {
  final List<MatchHeaderDto> headers;
  final int selected;
  final void Function(int) onSelect;

  const _MatchSelector({
    required this.headers,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM', 'pt_BR');
    final safeSelected = selected.clamp(0, headers.length - 1);
    return Container(
      color: AppColors.slate800,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _SelectorArrow(
            icon: Icons.chevron_left_rounded,
            enabled: safeSelected > 0,
            onTap: () => onSelect(safeSelected - 1),
          ),
          const SizedBox(width: 8),
          Text(
            '${safeSelected + 1}/${headers.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.slate300,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(headers.length, (i) {
                  final h = headers[i];
                  final active = i == safeSelected;
                  final date = h.playedAt;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.infoLight : AppColors.slate700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          fmt.format(date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                active ? AppColors.onDark : AppColors.slate300,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          h.placeName.isNotEmpty ? h.placeName : 'Partida',
                          style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? AppColors.onDark.withValues(alpha: .85)
                                : AppColors.slate400,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 2),
          _SelectorArrow(
            icon: Icons.chevron_right_rounded,
            enabled: safeSelected < headers.length - 1,
            onTap: () => onSelect(safeSelected + 1),
          ),
        ],
      ),
    );
  }
}

class _SelectorArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _SelectorArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: enabled
                ? AppColors.slate700.withValues(alpha: .8)
                : AppColors.slate900.withValues(alpha: .25),
          ),
          child: Icon(
            icon,
            size: 19,
            color: enabled ? AppColors.slate200 : AppColors.slate600,
          ),
        ),
      );
}

// ── Sheet: criar nova partida (quando já há partida ativa) ───────────────────

// ── Banner de pré-visualização ────────────────────────────────────────────────

class _PreviewBanner extends StatelessWidget {
  final MatchStep previewStep;
  final MatchStep currentStep;
  final VoidCallback onDismiss;
  const _PreviewBanner(
      {required this.previewStep,
      required this.currentStep,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.amber200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 14, color: AppColors.warningLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Pré-visualização · etapa real: ${currentStep.label}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warningLight,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 16, color: AppColors.warningLight),
          ),
        ],
      ),
    );
  }
}

// ── Vista: criar partida (Step 1 embutido) ────────────────────────────────────

class _CreateMatchView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController placeCtrl;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onCreate;
  final bool mutating;
  final VoidCallback? onCancel;

  const _CreateMatchView({
    required this.formKey,
    required this.placeCtrl,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    required this.onCreate,
    required this.mutating,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nova Partida',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      // Local
                      TextFormField(
                        controller: placeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Local *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Informe o local'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Data
                      InkWell(
                        onTap: onPickDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data *',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(fmt.format(date),
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Horário
                      InkWell(
                        onTap: onPickTime,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Horário *',
                            prefixIcon: Icon(Icons.access_time_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(time.format(context),
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              if (onCancel != null) ...[
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: mutating ? null : onCreate,
                  icon: mutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onDark))
                      : const Icon(Icons.add),
                  label: const Text('Criar Partida'),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Vista: aguardando o admin criar partida ────────────────────────────────────

class _WaitingForMatchView extends StatelessWidget {
  const _WaitingForMatchView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.slate800.withValues(alpha: 0.5)
                : AppColors.onDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                ),
                child: const Icon(Icons.access_time_rounded,
                    size: 22, color: AppColors.slate400),
              ),
              const SizedBox(height: 12),
              Text(
                'Aguardando o admin criar uma partida',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? AppColors.slate100 : AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Assim que houver uma partida ativa, ela aparecerá aqui automaticamente.',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista: erro ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.rose400),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}
