import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late int _goalMinute;
  String? _scorerMpId;
  String? _assistMpId;
  bool _isOwnGoal = false;
  String? _editingGoalId;
  bool _publishingGol = false;
  bool _publishingJogada = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _goalMinute = now.hour * 60 + now.minute;
  }

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return (acc?.isAdmin ?? false) ||
        (gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false));
  }

  void _resetGoalForm() {
    final now = DateTime.now();
    setState(() {
      _editingGoalId = null;
      _goalMinute = now.hour * 60 + now.minute;
      _scorerMpId = null;
      _assistMpId = null;
      _isOwnGoal = false;
    });
  }

  void _editGoal(MatchGoal goal, List<MatchPlayerInfo> allPlayers) {
    var minutes = 0;
    if (goal.time != null) {
      final parts = goal.time!.split(':');
      if (parts.length >= 2) {
        minutes =
            (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }
    }
    final scorerMpId = goal.scorerMatchPlayerId ??
        allPlayers
            .where((p) => p.playerId == goal.scorerPlayerId)
            .firstOrNull
            ?.matchPlayerId;
    final assistMpId = goal.assistMatchPlayerId ??
        allPlayers
            .where((p) => p.playerId == goal.assistPlayerId)
            .firstOrNull
            ?.matchPlayerId;
    setState(() {
      _editingGoalId = goal.goalId;
      _goalMinute = minutes;
      _scorerMpId = scorerMpId;
      _assistMpId = assistMpId;
      _isOwnGoal = goal.isOwnGoal;
    });
  }

  Future<void> _endMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar partida?'),
        content: const Text(
            'A partida será encerrada. Você poderá registrar o placar e MVP no pós-jogo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
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

  Future<void> _triggerReplay(String eventType) async {
    if (_publishingGol || _publishingJogada) return;
    setState(() {
      _publishingGol = eventType == 'Gol';
      _publishingJogada = eventType == 'Jogada';
    });
    try {
      await ref.read(matchNotifierProvider.notifier).publishEvent(eventType);
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } finally {
      if (mounted) {
        setState(() {
          _publishingGol = false;
          _publishingJogada = false;
        });
      }
    }
  }

  Future<void> _saveGoal(List<MatchPlayerInfo> players) async {
    if (_scorerMpId == null) return;
    final scorer =
        players.where((p) => p.matchPlayerId == _scorerMpId).firstOrNull;
    if (scorer == null) return;
    final assist = _assistMpId != null
        ? players.where((p) => p.matchPlayerId == _assistMpId).firstOrNull
        : null;
    final timeStr =
        '${(_goalMinute ~/ 60).toString().padLeft(2, '0')}:${(_goalMinute % 60).toString().padLeft(2, '0')}';

    if (_editingGoalId != null) {
      await ref.read(matchNotifierProvider.notifier).updateGoal(
            goalId: _editingGoalId!,
            scorerPlayerId: scorer.playerId,
            assistPlayerId: assist?.playerId,
            time: timeStr,
            isOwnGoal: _isOwnGoal,
          );
    } else {
      await ref.read(matchNotifierProvider.notifier).addGoal(
            scorerPlayerId: scorer.playerId,
            assistPlayerId: assist?.playerId,
            time: timeStr,
            isOwnGoal: _isOwnGoal,
          );
    }
    _resetGoalForm();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    final acc = ref.watch(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);

    final participants = s.participants.isNotEmpty
        ? s.participants
        : [
            ..._playersForTeam(teamPlayers: s.teamAPlayers, team: 1),
            ..._playersForTeam(teamPlayers: s.teamBPlayers, team: 2),
          ];
    final teamAPlayers = participants.where((p) => p.team == 1).toList();
    final teamBPlayers = participants.where((p) => p.team == 2).toList();
    final allPlayers = [...teamAPlayers, ...teamBPlayers];

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
                  _LiveStatusCard(
                    admin: _isAdmin,
                    onRefresh: () =>
                        ref.read(matchNotifierProvider.notifier).refresh(),
                  ),
                  const SizedBox(height: 16),
                  _ReplaySection(
                    publishingGol: _publishingGol,
                    publishingJogada: _publishingJogada,
                    onGol: () => _triggerReplay('Gol'),
                    onJogada: () => _triggerReplay('Jogada'),
                  ),
                  const SizedBox(height: 16),
                  InlineGoalTracker(
                    minute: _goalMinute,
                    scorerMpId: _scorerMpId,
                    assistMpId: _assistMpId,
                    isOwnGoal: _isOwnGoal,
                    isEditing: _editingGoalId != null,
                    participants: participants,
                    teamAPlayers: teamAPlayers,
                    teamBPlayers: teamBPlayers,
                    teamAName: s.teamAColor?.name ?? 'Time A',
                    teamBName: s.teamBColor?.name ?? 'Time B',
                    teamAColor: s.teamAColor?.color,
                    teamBColor: s.teamBColor?.color,
                    mutating: s.mutating,
                    icons: icons,
                    isAdmin: _isAdmin,
                    onMinuteChanged: (v) => setState(() => _goalMinute = v),
                    onScorerChanged: (id) => setState(() {
                      _scorerMpId = id;
                      _assistMpId = null;
                      _isOwnGoal = false;
                    }),
                    onAssistChanged: (id) => setState(() => _assistMpId = id),
                    onOwnGoalChanged: (v) => setState(() => _isOwnGoal = v),
                    onSave: () => _saveGoal(allPlayers),
                    onCancel: _resetGoalForm,
                  ),
                  if (s.goals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...s.goals.map(
                      (g) => GoalEntryRow(
                        goal: g,
                        teamAName: s.teamAColor?.name ?? 'Time A',
                        teamBName: s.teamBColor?.name ?? 'Time B',
                        teamAColor: s.teamAColor?.color,
                        teamBColor: s.teamBColor?.color,
                        participants: allPlayers,
                        isAdmin: _isAdmin,
                        loading: s.mutating,
                        onEdit:
                            _isAdmin ? () => _editGoal(g, allPlayers) : null,
                        onRemove: _isAdmin
                            ? () => ref
                                .read(matchNotifierProvider.notifier)
                                .removeGoal(g.goalId)
                            : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
        if (_isAdmin)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose500,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                  ),
                  onPressed: s.mutating ? null : _endMatch,
                  icon: s.mutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: const Text('Encerrar partida'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

List<MatchPlayerInfo> _playersForTeam({
  required List<MatchPlayerInfo> teamPlayers,
  required int team,
}) {
  return teamPlayers
      .map(
        (p) => MatchPlayerInfo(
          matchPlayerId: p.matchPlayerId,
          playerId: p.playerId,
          playerName: p.playerName,
          isGoalkeeper: p.isGoalkeeper,
          isGuest: p.isGuest,
          team: team,
          inviteResponse: p.inviteResponse,
          absenceType: p.absenceType,
          absenceDescription: p.absenceDescription,
          didNotPlay: p.didNotPlay,
          isMvp: p.isMvp,
        ),
      )
      .toList();
}

class _LiveStatusCard extends StatelessWidget {
  final bool admin;
  final Future<void> Function() onRefresh;

  const _LiveStatusCard({
    required this.admin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(height: 4, color: AppColors.emerald500),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.emerald50),
                  child: _PulsingDot(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Em Jogo',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        admin
                            ? 'Partida em andamento.'
                            : 'Partida em andamento (visualização).',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                if (admin)
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Recarregar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplaySection extends StatelessWidget {
  final bool publishingGol;
  final bool publishingJogada;
  final VoidCallback onGol;
  final VoidCallback onJogada;

  const _ReplaySection({
    required this.publishingGol,
    required this.publishingJogada,
    required this.onGol,
    required this.onJogada,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = publishingGol || publishingJogada;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REPLAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emerald700,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: disabled ? null : onGol,
                    icon: publishingGol
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.emoji_events_outlined, size: 18),
                    label: const Text('GOL',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: disabled ? null : onJogada,
                    icon: publishingJogada
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('JOGADA',
                        style: TextStyle(fontWeight: FontWeight.w800)),
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

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _anim = Tween(begin: 0.45, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Icon(Icons.circle, size: 13, color: AppColors.emerald500),
    );
  }
}
