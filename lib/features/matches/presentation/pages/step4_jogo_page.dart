import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/goal_entry_row.dart';
import '../widgets/inline_goal_tracker.dart';

class Step4JogoPage extends ConsumerStatefulWidget {
  const Step4JogoPage({super.key});

  @override
  ConsumerState<Step4JogoPage> createState() => _Step4State();
}

class _Step4State extends ConsumerState<Step4JogoPage> {
  // ── GoalTracker inline state ──────────────────────────────────────────────
  // Minutos desde meia-noite; inicializado com hora atual.
  late int _goalMinute;
  String? _scorerMpId;
  String? _assistMpId;
  bool    _isOwnGoal  = false;
  String? _editingGoalId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _goalMinute = now.hour * 60 + now.minute;
  }

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return (acc?.isAdmin ?? false) || (gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false));
  }

  void _resetGoalForm() {
    final now = DateTime.now();
    setState(() {
      _editingGoalId = null;
      _goalMinute    = now.hour * 60 + now.minute;
      _scorerMpId    = null;
      _assistMpId    = null;
      _isOwnGoal     = false;
    });
  }

  void _editGoal(MatchGoal goal, List<MatchPlayerInfo> allPlayers) {
    int minutes = 0;
    if (goal.time != null) {
      final parts = goal.time!.split(':');
      if (parts.length >= 2) {
        minutes = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }
    }
    final scorerMpId = goal.scorerMatchPlayerId ??
        allPlayers.where((p) => p.playerId == goal.scorerPlayerId).firstOrNull?.matchPlayerId;
    final assistMpId = goal.assistMatchPlayerId ??
        allPlayers.where((p) => p.playerId == goal.assistPlayerId).firstOrNull?.matchPlayerId;
    setState(() {
      _editingGoalId = goal.goalId;
      _goalMinute    = minutes;
      _scorerMpId    = scorerMpId;
      _assistMpId    = assistMpId;
      _isOwnGoal     = goal.isOwnGoal;
    });
  }

  Future<void> _endMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar partida?'),
        content: const Text('A partida será encerrada. Você poderá registrar o placar e MVP no pós-jogo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(matchNotifierProvider.notifier).endMatch();
  }

  void _triggerReplay(String eventType) {
    ref.read(matchNotifierProvider.notifier).publishEvent(eventType);
  }

  Future<void> _saveGoal(List<MatchPlayerInfo> players) async {
    if (_scorerMpId == null) return;
    final scorer = players.where((p) => p.matchPlayerId == _scorerMpId).firstOrNull;
    if (scorer == null) return;
    final assist = _assistMpId != null
        ? players.where((p) => p.matchPlayerId == _assistMpId).firstOrNull
        : null;
    final timeStr = '${(_goalMinute ~/ 60).toString().padLeft(2, '0')}:${(_goalMinute % 60).toString().padLeft(2, '0')}';

    if (_editingGoalId != null) {
      await ref.read(matchNotifierProvider.notifier).updateGoal(
        goalId:         _editingGoalId!,
        scorerPlayerId: scorer.playerId,
        assistPlayerId: assist?.playerId,
        time:           timeStr,
        isOwnGoal:      _isOwnGoal,
      );
    } else {
      await ref.read(matchNotifierProvider.notifier).addGoal(
        scorerPlayerId: scorer.playerId,
        assistPlayerId: assist?.playerId,
        time:           timeStr,
        isOwnGoal:      _isOwnGoal,
      );
    }
    _resetGoalForm();
  }

  @override
  Widget build(BuildContext context) {
    final s       = ref.watch(matchNotifierProvider);
    final fmt     = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    final dateStr = s.playedAt != null ? fmt.format(s.playedAt!.toLocal()) : '—';
    final acc     = ref.watch(accountStoreProvider).activeAccount;
    final gid     = acc?.activeGroupId ?? '';
    final icons   = GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);

    final allPlayers = s.participants.isNotEmpty
        ? s.participants
        : [...s.teamAPlayers, ...s.teamBPlayers];

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Status card ──────────────────────────────────────────
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PulsingDot(),
                                const SizedBox(width: 8),
                                const Text('Em Jogo', style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  color: AppColors.emerald500,
                                )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                            Text(s.placeName ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.slate500)),
                            if (s.teamAColor != null || s.teamBColor != null) ...[
                              const SizedBox(height: 12),
                              _ScoreDisplay(
                                teamAName: s.teamAColor?.name ?? 'Time A',
                                teamBName: s.teamBColor?.name ?? 'Time B',
                                teamAColor: s.teamAColor?.color,
                                teamBColor: s.teamBColor?.color,
                                goalsA: s.goals.where((g) => g.team == 1).length,
                                goalsB: s.goals.where((g) => g.team == 2).length,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── GoalTracker inline ───────────────────────────────────
                    InlineGoalTracker(
                      minute:     _goalMinute,
                      scorerMpId: _scorerMpId,
                      assistMpId: _assistMpId,
                      isOwnGoal:  _isOwnGoal,
                      isEditing:  _editingGoalId != null,
                      teamAPlayers: s.teamAPlayers.isNotEmpty ? s.teamAPlayers : allPlayers,
                      teamBPlayers: s.teamBPlayers,
                      teamAName:  s.teamAColor?.name ?? 'Time A',
                      teamBName:  s.teamBColor?.name ?? 'Time B',
                      teamAColor: s.teamAColor?.color,
                      teamBColor: s.teamBColor?.color,
                      mutating:   s.mutating,
                      icons:      icons,
                      onMinuteChanged: (v) => setState(() => _goalMinute = v),
                      onScorerChanged: (id) => setState(() {
                        _scorerMpId = id;
                        _assistMpId = null;
                      }),
                      onAssistChanged: (id) => setState(() => _assistMpId = id),
                      onOwnGoalChanged: (v) => setState(() => _isOwnGoal = v),
                      onSave: () => _saveGoal(allPlayers),
                      onCancel: _resetGoalForm,
                    ),
                    const SizedBox(height: 8),

                    // ── Replay ───────────────────────────────────────────────
                    if (_isAdmin)
                      _ReplaySection(
                        onGol:    () => _triggerReplay('Gol'),
                        onJogada: () => _triggerReplay('Jogada'),
                      ),
                    const SizedBox(height: 8),

                    // ── Lista de gols ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gols da Partida (${s.goals.length})',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (s.goals.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Nenhum gol registrado', style: TextStyle(color: AppColors.slate400)),
                        ),
                      )
                    else
                      ...s.goals.map((g) => GoalEntryRow(
                        goal:      g,
                        teamAName: s.teamAColor?.name ?? 'Time A',
                        teamBName: s.teamBColor?.name ?? 'Time B',
                        teamAColor: s.teamAColor?.color,
                        teamBColor: s.teamBColor?.color,
                        isAdmin:   _isAdmin,
                        onEdit:    _isAdmin ? () => _editGoal(g, allPlayers) : null,
                        onRemove:  _isAdmin
                            ? () => ref.read(matchNotifierProvider.notifier).removeGoal(g.goalId)
                            : null,
                      )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // ── Encerrar partida (admin) ──────────────────────────────────────
          if (_isAdmin)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
                    onPressed: s.mutating ? null : _endMatch,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.stop_circle_outlined),
                    label: const Text('⏹ Encerrar Partida'),
                  ),
                ),
              ),
            ),
        ],
    );
  }
}

// ── Seção Replay ──────────────────────────────────────────────────────────────

class _ReplaySection extends StatelessWidget {
  final VoidCallback onGol;
  final VoidCallback onJogada;

  const _ReplaySection({
    required this.onGol,
    required this.onJogada,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REPLAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.slate400,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onGol,
                    icon: const Icon(Icons.emoji_events_outlined, size: 18),
                    label: const Text('GOL',
                        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5FD9),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onJogada,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('JOGADA',
                        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dot pulsante ──────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: const Icon(Icons.circle, size: 10, color: AppColors.emerald500),
  );
}

// ── Placar ────────────────────────────────────────────────────────────────────

class _ScoreDisplay extends StatelessWidget {
  final String teamAName, teamBName;
  final Color? teamAColor, teamBColor;
  final int goalsA, goalsB;

  const _ScoreDisplay({
    required this.teamAName, required this.teamBName,
    this.teamAColor, this.teamBColor,
    required this.goalsA, required this.goalsB,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _TeamScore(name: teamAName, goals: goalsA, color: teamAColor),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('×', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
      ),
      _TeamScore(name: teamBName, goals: goalsB, color: teamBColor),
    ],
  );
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int goals;
  final Color? color;
  const _TeamScore({required this.name, required this.goals, this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? AppColors.slate300),
      ),
      Text('$goals', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
      Text(name, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
    ],
  );
}
