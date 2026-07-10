import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
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
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isAdmin = _isAdmin(account, groupId);

    if (!s.loading && s.groupSettings != null) _initForm(s);

    if (s.loading) return const Center(child: CircularProgressIndicator());

    if (s.error != null && !s.hasMatch) {
      return _ErrorView(
        message: s.error!,
        onRetry: () => ref.read(matchNotifierProvider.notifier).loadInitial(),
      );
    }

    final currentStep = s.hasMatch ? s.step : MatchStep.create;

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
                        _previewStep =
                            (_previewStep == step || step == currentStep)
                                ? null
                                : step;
                      })
                  : null,
            ),
            if (s.hasMatch && currentStep != MatchStep.accept)
              _LinkedPollStrip(
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
            if (_previewStep != null && _previewStep != currentStep)
              _PreviewBanner(
                previewStep: _previewStep!,
                currentStep: currentStep,
                onDismiss: () => setState(() => _previewStep = null),
              ),
            Expanded(
              child: _buildStepContent(s, isAdmin, groupId),
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
  final VoidCallback? onDelete;
  final VoidCallback? onCreateNew;

  const _MatchBanner({
    required this.s,
    required this.isAdmin,
    required this.canRewind,
    required this.onRefresh,
    required this.onRewind,
    this.onDelete,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM HH:mm', 'pt_BR');
    return Container(
      color: AppColors.slate900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Partidas',
                  style: TextStyle(
                      color: AppColors.slate400,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                if (s.hasMatch)
                  Text(
                    '${s.placeName ?? "—"} · ${s.playedAt != null ? fmt.format(s.playedAt!) : "—"}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // ── Nova Partida (só admin) ───────────────────────────────────────
          if (isAdmin && onCreateNew != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 20),
              onPressed: onCreateNew,
              tooltip: 'Nova partida',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          if (isAdmin && s.hasMatch)
            TextButton.icon(
              onPressed: canRewind ? onRewind : null,
              icon: Icon(Icons.undo_rounded,
                  size: 16,
                  color: canRewind ? AppColors.amber400 : AppColors.slate600),
              label: Text(
                'Voltar etapa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: canRewind ? AppColors.amber400 : AppColors.slate600,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 34),
              ),
            ),
          // ── Excluir (só admin, com confirmação) ──────────────────────────
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.rose400, size: 20),
              onPressed: onDelete,
              tooltip: 'Excluir partida',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // ── Refresh ──────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

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

    return Container(
      color: isDark ? AppColors.slate800 : AppColors.slate50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: linked != null
          ? _LinkedRow(
              poll: linked,
              groupId: groupId,
              isAdmin: isAdmin,
              isDark: isDark,
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
      backgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
        builder: (_) => sheet,
      );
    } catch (_) {}
  }
}

class _LinkedRow extends StatelessWidget {
  final PollSummary poll;
  final String groupId;
  final bool isAdmin;
  final bool isDark;
  final VoidCallback onUnlink;
  final void Function(BuildContext) onOpen;
  const _LinkedRow({
    required this.poll,
    required this.groupId,
    required this.isAdmin,
    required this.isDark,
    required this.onUnlink,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = poll.isEvent ? AppColors.violet600 : AppColors.blue600;
    final responses = poll.totalVoters;
    final label = poll.isEvent ? 'Evento' : 'Votação';
    final statusText = poll.isOpen ? 'Aberta' : 'Encerrada';
    final statusColor = poll.isOpen ? AppColors.emerald500 : AppColors.slate400;

    return GestureDetector(
      onTap: () => onOpen(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Linha principal ──────────────────────────────────────
            Row(children: [
              // Ícone do evento ou ícone padrão
              if (poll.eventIcon != null && poll.eventIcon!.isNotEmpty)
                Text(poll.eventIcon!, style: const TextStyle(fontSize: 15))
              else
                Icon(poll.isEvent ? Icons.event_rounded : Icons.poll_rounded,
                    size: 15, color: color),
              const SizedBox(width: 8),

              // Título
              Expanded(
                child: Text(
                  poll.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate100 : AppColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Badge status (Aberta / Encerrada)
              _Badge(
                label: statusText,
                fg: statusColor,
                bg: statusColor.withValues(alpha: .1),
                border: statusColor.withValues(alpha: .3),
              ),

              // Badge "✓ Votou"
              if (poll.hasVoted) ...[
                const SizedBox(width: 6),
                _Badge(
                  label: '✓ Votou',
                  fg: AppColors.blue600,
                  bg: AppColors.blue600.withValues(alpha: .08),
                  border: AppColors.blue600.withValues(alpha: .25),
                ),
              ],

              // Botão desvincular (admin)
              if (isAdmin) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onUnlink,
                  child: Icon(Icons.close_rounded,
                      size: 16,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ],
            ]),

            // ── Linha secundária: N respostas · abrir ───────────────
            const SizedBox(height: 3),
            Row(children: [
              const SizedBox(width: 23), // alinha com o título
              Text(
                '$responses ${responses == 1 ? 'resposta' : 'respostas'} · $label · abrir →',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ]),
          ],
        ),
      ),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Icon(Icons.add_link_rounded,
              size: 14,
              color: isDark ? AppColors.slate500 : AppColors.slate400),
          const SizedBox(width: 8),
          Text('Vincular votação ou evento',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              )),
        ]),
      );
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
        color: isDark ? AppColors.slate900 : Colors.white,
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
                  color: isDark ? Colors.white : AppColors.slate900,
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
                      p.isEvent ? AppColors.violet600 : AppColors.blue600;
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
                          color: isDark ? Colors.white : AppColors.slate900,
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
                        color: active ? AppColors.blue600 : AppColors.slate700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          fmt.format(date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.slate300,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          h.placeName.isNotEmpty ? h.placeName : 'Partida',
                          style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? Colors.white.withValues(alpha: .85)
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
              size: 14, color: AppColors.orange700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Pré-visualização · etapa real: ${currentStep.label}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.orange700,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child:
                const Icon(Icons.close, size: 16, color: AppColors.orange700),
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
                              strokeWidth: 2, color: Colors.white))
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
                : Colors.white,
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
