import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/goal_entry_row.dart';

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
  String? _publishingReplayType;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _goalMinute = now.hour * 60 + now.minute;
  }

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
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
        title: const Text('Finalizar partida?'),
        content: const Text(
          'Deseja realmente finalizar esta partida? Depois disso, não será possível voltar para a etapa de jogo. Você ainda poderá registrar o placar e o MVP no pós-jogo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose500),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, finalizar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(matchNotifierProvider.notifier).endMatch();
  }

  Future<void> _triggerReplay(String eventType) async {
    if (_publishingReplayType != null) return;
    setState(() => _publishingReplayType = eventType);
    try {
      await ref.read(matchNotifierProvider.notifier).publishEvent(eventType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eventType == 'Jogada'
                ? 'Evento registrado com sucesso.'
                : 'Gol registrado com sucesso.'),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } finally {
      if (mounted) {
        setState(() => _publishingReplayType = null);
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

  Future<void> _openQuickGoalSheet(
    List<MatchPlayerInfo> players, {
    MatchGoal? editingGoal,
  }) async {
    if (editingGoal == null) {
      _resetGoalForm();
    } else {
      _editGoal(editingGoal, players);
    }

    if (!mounted) return;
    final match = ref.read(matchNotifierProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => _QuickGoalSheet(
        players: players,
        initialMinute: _goalMinute,
        initialScorerMpId: _scorerMpId,
        initialAssistMpId: _assistMpId,
        initialOwnGoal: _isOwnGoal,
        editing: editingGoal != null,
        teamAName: match.teamAColor?.name ?? 'Time A',
        teamBName: match.teamBColor?.name ?? 'Time B',
        teamAColor: match.teamAColor?.color ?? AppColors.infoLight,
        teamBColor: match.teamBColor?.color ?? AppColors.rose500,
        onSave: (scorer, assist, minute, isOwnGoal) async {
          setState(() {
            _scorerMpId = scorer.matchPlayerId;
            _assistMpId = assist?.matchPlayerId;
            _goalMinute = minute;
            _isOwnGoal = isOwnGoal;
          });
          await _saveGoal(players);
        },
      ),
    );
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
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () =>
                    ref.read(matchNotifierProvider.notifier).refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LiveStatusCard(
                        admin: _isAdmin,
                        teamAGoals: s.teamAGoals ?? 0,
                        teamBGoals: s.teamBGoals ?? 0,
                        onRefresh: () =>
                            ref.read(matchNotifierProvider.notifier).refresh(),
                      ),
                      const SizedBox(height: 16),
                      _ReplaySection(
                        publishingType: _publishingReplayType,
                        teamAName: s.teamAColor?.name ?? 'Time A',
                        teamBName: s.teamBColor?.name ?? 'Time B',
                        teamAColor: s.teamAColor?.color,
                        teamBColor: s.teamBColor?.color,
                        onGolA: () => _triggerReplay('GolTimeA'),
                        onGolB: () => _triggerReplay('GolTimeB'),
                        onJogada: () => _triggerReplay('Jogada'),
                      ),
                      const SizedBox(height: 16),
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
                            icons: icons,
                            isAdmin: _isAdmin,
                            loading: s.mutating,
                            onEdit: _isAdmin
                                ? () => _openQuickGoalSheet(
                                      allPlayers,
                                      editingGoal: g,
                                    )
                                : null,
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
              if (_isAdmin)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton(
                    heroTag: 'quick-goal',
                    tooltip: 'Registrar gol',
                    backgroundColor: AppColors.onDark,
                    foregroundColor: AppColors.infoLight,
                    elevation: 5,
                    onPressed: s.mutating
                        ? null
                        : () => _openQuickGoalSheet(allPlayers),
                    child: const Icon(Icons.sports_soccer_rounded, size: 30),
                  ),
                ),
            ],
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
                              strokeWidth: 2, color: AppColors.onDark),
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
  final int teamAGoals;
  final int teamBGoals;
  final Future<void> Function() onRefresh;

  const _LiveStatusCard({
    required this.admin,
    required this.teamAGoals,
    required this.teamBGoals,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'PLACAR',
                      style: TextStyle(
                        color: AppColors.slate500,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$teamAGoals × $teamBGoals',
                      style: const TextStyle(
                        color: AppColors.slate900,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (admin) const SizedBox(width: 12),
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

class _QuickGoalSheet extends StatefulWidget {
  final List<MatchPlayerInfo> players;
  final int initialMinute;
  final String? initialScorerMpId;
  final String? initialAssistMpId;
  final bool initialOwnGoal;
  final bool editing;
  final String teamAName;
  final String teamBName;
  final Color teamAColor;
  final Color teamBColor;
  final Future<void> Function(
    MatchPlayerInfo scorer,
    MatchPlayerInfo? assist,
    int minute,
    bool isOwnGoal,
  ) onSave;

  const _QuickGoalSheet({
    required this.players,
    required this.initialMinute,
    required this.initialScorerMpId,
    required this.initialAssistMpId,
    required this.initialOwnGoal,
    required this.editing,
    required this.teamAName,
    required this.teamBName,
    required this.teamAColor,
    required this.teamBColor,
    required this.onSave,
  });

  @override
  State<_QuickGoalSheet> createState() => _QuickGoalSheetState();
}

class _QuickGoalSheetState extends State<_QuickGoalSheet> {
  late final TextEditingController _timeController;
  late String? _scorerMpId;
  late String? _assistMpId;
  late bool _isOwnGoal;
  late bool _choosingAssist;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timeController =
        TextEditingController(text: _formatTime(widget.initialMinute));
    _scorerMpId = widget.initialScorerMpId;
    _assistMpId = widget.initialAssistMpId;
    _isOwnGoal = widget.initialOwnGoal;
    _choosingAssist = _scorerMpId != null;
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  String _formatTime(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  int? get _parsedTime {
    final parts = _timeController.text.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  MatchPlayerInfo? get _scorer => widget.players
      .where((player) => player.matchPlayerId == _scorerMpId)
      .firstOrNull;

  List<MatchPlayerInfo> get _assistPlayers {
    final scorer = _scorer;
    if (scorer == null) return const [];
    return widget.players
        .where(
          (player) =>
              player.team ==
                  (_isOwnGoal ? (scorer.team == 1 ? 2 : 1) : scorer.team) &&
              player.matchPlayerId != scorer.matchPlayerId,
        )
        .toList();
  }

  Color _teamColor(int team) =>
      team == 1 ? widget.teamAColor : widget.teamBColor;

  String _teamName(int team) => team == 1 ? widget.teamAName : widget.teamBName;

  void _selectScorer(MatchPlayerInfo player) {
    setState(() {
      _scorerMpId = player.matchPlayerId;
      _assistMpId = null;
      _choosingAssist = true;
    });
  }

  Future<void> _save([MatchPlayerInfo? assist]) async {
    final scorer = _scorer;
    final time = _parsedTime;
    if (scorer == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe uma hora válida no formato HH:mm.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(scorer, assist, time, _isOwnGoal);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scorer = _scorer;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * .82),
        decoration: const BoxDecoration(
          color: AppColors.lightSubtle,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(
                    _choosingAssist
                        ? Icons.assistant_rounded
                        : Icons.sports_soccer_rounded,
                    color: AppColors.infoLight,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _choosingAssist
                          ? (_isOwnGoal
                              ? 'Quem ocasionou o gol contra?'
                              : 'Quem deu a assistência?')
                          : 'Quem marcou o gol?',
                      style: const TextStyle(
                        color: AppColors.darkSubtle,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_choosingAssist)
                    IconButton(
                      tooltip: 'Trocar artilheiro',
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _choosingAssist = false;
                                _scorerMpId = null;
                                _assistMpId = null;
                              }),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.editing
                    ? 'Edite o lance e confirme.'
                    : 'Toque uma vez para registrar o lance.',
                style: const TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _ClockField(controller: _timeController, enabled: !_saving),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: const Text('Gol contra'),
                  selected: _isOwnGoal,
                  onSelected: _saving
                      ? null
                      : (value) => setState(() {
                            _isOwnGoal = value;
                            _assistMpId = null;
                          }),
                  selectedColor: AppColors.rose500.withValues(alpha: .15),
                  checkmarkColor: AppColors.rose500,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _choosingAssist && scorer != null
                    ? _AssistPicker(
                        key: const ValueKey('assist-picker'),
                        scorer: scorer,
                        players: _assistPlayers,
                        color: _teamColor(
                          _isOwnGoal ? (scorer.team == 1 ? 2 : 1) : scorer.team,
                        ),
                        teamName: _teamName(
                          _isOwnGoal ? (scorer.team == 1 ? 2 : 1) : scorer.team,
                        ),
                        isOwnGoal: _isOwnGoal,
                        saving: _saving,
                        selectedAssistMpId: _assistMpId,
                        onSelect: (player) {
                          setState(() => _assistMpId = player.matchPlayerId);
                          _save(player);
                        },
                        onSkip: () => _save(),
                      )
                    : _ScorerPicker(
                        key: const ValueKey('scorer-picker'),
                        teamA: widget.players
                            .where((player) => player.team == 1)
                            .toList(),
                        teamB: widget.players
                            .where((player) => player.team == 2)
                            .toList(),
                        teamAName: widget.teamAName,
                        teamBName: widget.teamBName,
                        teamAColor: widget.teamAColor,
                        teamBColor: widget.teamBColor,
                        selectedScorerMpId: _scorerMpId,
                        disabled: _saving,
                        onSelect: _selectScorer,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _ClockField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, color: AppColors.slate500, size: 20),
        const SizedBox(width: 8),
        const Text('Hora do gol',
            style: TextStyle(
                color: AppColors.slate600, fontWeight: FontWeight.w700)),
        const Spacer(),
        SizedBox(
          width: 88,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'HH:mm',
              filled: true,
              fillColor: AppColors.onDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScorerPicker extends StatelessWidget {
  final List<MatchPlayerInfo> teamA;
  final List<MatchPlayerInfo> teamB;
  final String teamAName;
  final String teamBName;
  final Color teamAColor;
  final Color teamBColor;
  final String? selectedScorerMpId;
  final bool disabled;
  final ValueChanged<MatchPlayerInfo> onSelect;

  const _ScorerPicker({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.teamAName,
    required this.teamBName,
    required this.teamAColor,
    required this.teamBColor,
    required this.selectedScorerMpId,
    required this.disabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _TeamGoalPicker(
                title: teamAName,
                color: teamAColor,
                players: teamA,
                selectedId: selectedScorerMpId,
                disabled: disabled,
                onSelect: onSelect)),
        const SizedBox(width: 12),
        Expanded(
            child: _TeamGoalPicker(
                title: teamBName,
                color: teamBColor,
                players: teamB,
                selectedId: selectedScorerMpId,
                disabled: disabled,
                onSelect: onSelect)),
      ],
    );
  }
}

class _TeamGoalPicker extends StatelessWidget {
  final String title;
  final Color color;
  final List<MatchPlayerInfo> players;
  final String? selectedId;
  final bool disabled;
  final ValueChanged<MatchPlayerInfo> onSelect;

  const _TeamGoalPicker({
    required this.title,
    required this.color,
    required this.players,
    required this.selectedId,
    required this.disabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: .5)),
        const SizedBox(height: 8),
        ...players.map((player) => _GoalPlayerButton(
            player: player,
            color: color,
            selected: player.matchPlayerId == selectedId,
            disabled: disabled,
            onTap: () => onSelect(player))),
      ],
    );
  }
}

class _AssistPicker extends StatelessWidget {
  final MatchPlayerInfo scorer;
  final List<MatchPlayerInfo> players;
  final Color color;
  final String teamName;
  final bool isOwnGoal;
  final bool saving;
  final String? selectedAssistMpId;
  final ValueChanged<MatchPlayerInfo> onSelect;
  final VoidCallback onSkip;

  const _AssistPicker({
    super.key,
    required this.scorer,
    required this.players,
    required this.color,
    required this.teamName,
    required this.isOwnGoal,
    required this.saving,
    required this.selectedAssistMpId,
    required this.onSelect,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isOwnGoal
              ? 'Jogadores do $teamName que ocasionaram o lance'
              : 'Jogadores do $teamName',
          style: const TextStyle(
            color: AppColors.slate500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players
              .map((player) => _GoalPlayerButton(
                  player: player,
                  color: color,
                  selected: player.matchPlayerId == selectedAssistMpId,
                  disabled: saving,
                  compact: true,
                  onTap: () => onSelect(player)))
              .toList(),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: saving ? null : onSkip,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.remove_circle_outline_rounded),
          label: Text(isOwnGoal ? 'Nenhum jogador' : 'Sem assistência'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

class _GoalPlayerButton extends StatelessWidget {
  final MatchPlayerInfo player;
  final Color color;
  final bool selected;
  final bool disabled;
  final bool compact;
  final VoidCallback onTap;

  const _GoalPlayerButton({
    required this.player,
    required this.color,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 8),
      child: Material(
        color: selected ? color.withValues(alpha: .14) : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: compact ? const BoxConstraints(minWidth: 128) : null,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? color : AppColors.slate200),
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(Icons.person_rounded, size: 16, color: color),
                const SizedBox(width: 7),
                Flexible(
                    child: Text(player.playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplaySection extends StatelessWidget {
  final String? publishingType;
  final String teamAName;
  final String teamBName;
  final Color? teamAColor;
  final Color? teamBColor;
  final VoidCallback onGolA;
  final VoidCallback onGolB;
  final VoidCallback onJogada;

  const _ReplaySection({
    required this.publishingType,
    required this.teamAName,
    required this.teamBName,
    required this.teamAColor,
    required this.teamBColor,
    required this.onGolA,
    required this.onGolB,
    required this.onJogada,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = publishingType != null;
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
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ReplayButton(
                        label: 'Gol $teamAName',
                        color: teamAColor ?? AppColors.emerald700,
                        loading: publishingType == 'GolTimeA',
                        disabled: disabled,
                        icon: Icons.emoji_events_outlined,
                        onPressed: onGolA,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ReplayButton(
                        label: 'Gol $teamBName',
                        color: teamBColor ?? AppColors.rose500,
                        loading: publishingType == 'GolTimeB',
                        disabled: disabled,
                        icon: Icons.emoji_events_outlined,
                        onPressed: onGolB,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _ReplayButton(
                    label: 'Jogada',
                    color: AppColors.infoLight,
                    loading: publishingType == 'Jogada',
                    disabled: disabled,
                    icon: Icons.bolt_rounded,
                    onPressed: onJogada,
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

class _ReplayButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final bool disabled;
  final IconData icon;
  final VoidCallback onPressed;

  const _ReplayButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.disabled,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: disabled ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.onDark),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
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
