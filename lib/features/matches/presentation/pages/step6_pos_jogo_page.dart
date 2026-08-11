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

class Step6PosJogoPage extends ConsumerStatefulWidget {
  const Step6PosJogoPage({super.key});

  @override
  ConsumerState<Step6PosJogoPage> createState() => _Step6State();
}

class _Step6State extends ConsumerState<Step6PosJogoPage> {
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  String? _voterMpId;
  String? _votedMpId;
  bool _scoreInited = false;

  int _goalMinute = 0;
  String? _scorerMpId;
  String? _assistMpId;
  bool _isOwnGoal = false;
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
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false);
  }

  String get _myPlayerId =>
      ref.read(accountStoreProvider).activeAccount?.activePlayerId ?? '';

  @override
  void dispose() {
    _scoreACtrl.dispose();
    _scoreBCtrl.dispose();
    super.dispose();
  }

  void _initScoreFields(MatchState s) {
    if (_scoreInited) return;
    _scoreInited = true;
    if (s.teamAGoals != null) _scoreACtrl.text = '${s.teamAGoals}';
    if (s.teamBGoals != null) _scoreBCtrl.text = '${s.teamBGoals}';
    // Para não-admins, pré-seleciona o voter como o próprio jogador
    if (!_isAdmin) {
      final myMp =
          s.eligibleVoters.where((p) => p.playerId == _myPlayerId).firstOrNull;
      if (myMp != null) _voterMpId = myMp.matchPlayerId;
    }
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
    int minutes = 0;
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

  Future<void> _saveGoal(List<MatchPlayerInfo> allPlayers) async {
    if (_scorerMpId == null) return;
    final scorer =
        allPlayers.where((p) => p.matchPlayerId == _scorerMpId).firstOrNull;
    if (scorer == null) return;
    final assist = _assistMpId != null
        ? allPlayers.where((p) => p.matchPlayerId == _assistMpId).firstOrNull
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

  Future<void> _saveScore() async {
    final a = int.tryParse(_scoreACtrl.text);
    final b = int.tryParse(_scoreBCtrl.text);
    if (a == null || b == null || a < 0 || b < 0) return;
    await ref.read(matchNotifierProvider.notifier).setScore(a, b);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Placar salvo!')),
      );
    }
  }

  Future<void> _vote() async {
    if (_votedMpId == null) return;
    final s = ref.read(matchNotifierProvider);
    final allPlayers = [...s.participants, ...s.eligibleVoters];

    // Para não-admin o voter é sempre o próprio usuário (derivado do estado atual).
    final effectiveVoterMpId = _isAdmin
        ? _voterMpId
        : allPlayers
            .where((p) => p.playerId == _myPlayerId)
            .firstOrNull
            ?.matchPlayerId;

    if (effectiveVoterMpId == null) return;

    final voter = allPlayers
        .where((p) => p.matchPlayerId == effectiveVoterMpId)
        .firstOrNull;
    final voted =
        allPlayers.where((p) => p.matchPlayerId == _votedMpId).firstOrNull;
    if (voter == null || voted == null) return;

    final ok = await ref
        .read(matchNotifierProvider.notifier)
        .voteMvp(voter.matchPlayerId, voted.matchPlayerId);
    if (!mounted) return;

    if (ok) {
      // Limpa seleção do admin para o próximo voto.
      setState(() {
        _voterMpId = null;
        _votedMpId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voto registrado!')),
      );
    } else {
      final err = ref.read(matchNotifierProvider).error ?? 'Erro desconhecido';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Falha: $err'),
            backgroundColor: AppColors.prototypeDanger),
      );
    }
  }

  Future<void> _finalize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar partida?'),
        content: const Text(
            'Os dados não poderão ser alterados após a finalização.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(matchNotifierProvider.notifier).finalizeMatch();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    final acc = ref.watch(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);
    if (!_scoreInited && !s.loading) _initScoreFields(s);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _isAdmin
                  ? _buildAdminView(context, s, icons)
                  : _buildUserView(context, s, icons),
            ),
          ),
        ),
        // ── Finalizar (admin) ──────────────────────────────────────────
        if (_isAdmin)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: s.mutating ? null : _finalize,
                  icon: s.mutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onDark))
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Finalizar →'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── View do não-admin ──────────────────────────────────────────────────────

  Widget _buildUserView(BuildContext context, MatchState s, GroupIcons icons) {
    final myPlayerId = _myPlayerId;
    final myMatchPlayer =
        s.participants.where((p) => p.playerId == myPlayerId).firstOrNull;
    final myMatchPlayerId = myMatchPlayer?.matchPlayerId ?? '';

    final isParticipant = myMatchPlayerId.isNotEmpty;
    final canVote =
        s.eligibleVoters.any((p) => p.matchPlayerId == myMatchPlayerId);
    final myVote = s.votes
        .where((v) => v.voterMatchPlayerId == myMatchPlayerId)
        .firstOrNull;
    final hasVoted = myVote != null;

    final scoreText = (s.teamAGoals == null || s.teamBGoals == null)
        ? '—'
        : '${s.teamAGoals} × ${s.teamBGoals}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        _SectionCard(
          title: 'Pós-jogo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Visualização + voto MVP',
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Placar ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'PLACAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scoreText,
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── MVP / Voto ───────────────────────────────────────────────────
        if (s.computedMvps.isNotEmpty)
          _MvpResultCard(
            mvpPlayers: s.computedMvps.map((m) {
              final participant = s.participants
                  .where((p) => p.playerId == m.playerId)
                  .firstOrNull;
              return (
                name: m.playerName,
                isGoalkeeper: participant?.isGoalkeeper ?? false,
              );
            }).toList(),
            icons: icons,
          )
        else
          _buildMyVoteSection(s, isParticipant, canVote, hasVoted, myVote,
              myMatchPlayerId, icons),

        const SizedBox(height: 12),

        // ── Gols (read-only) ─────────────────────────────────────────────
        _SectionCard(
          title: 'Gols da Partida',
          child: s.goals.isEmpty
              ? const Text('Nenhum gol registrado.',
                  style: TextStyle(color: AppColors.slate400))
              : Column(
                  children: s.goals
                      .map((g) => GoalEntryRow(
                            goal: g,
                            teamAName: s.teamAColor?.name ?? 'Time A',
                            teamBName: s.teamBColor?.name ?? 'Time B',
                            teamAColor: s.teamAColor?.color,
                            teamBColor: s.teamBColor?.color,
                            participants: s.participants,
                            icons: icons,
                            isAdmin: false,
                            onEdit: null,
                            onRemove: null,
                          ))
                      .toList(),
                ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMyVoteSection(
    MatchState s,
    bool isParticipant,
    bool canVote,
    bool hasVoted,
    VoteInfo? myVote,
    String myMatchPlayerId,
    GroupIcons icons,
  ) {
    return _SectionCard(
      title: 'Seu voto MVP',
      child: Builder(builder: (context) {
        // Não está entre os participantes
        if (!isParticipant) {
          return const Text(
            'Você não está entre os participantes desta partida.',
            style: TextStyle(fontSize: 13, color: AppColors.slate400),
          );
        }

        // Já votou — checado antes de canVote porque ao votar o jogador
        // sai de eligibleVoters (canVote = false), mas o voto já está em s.votes.
        if (hasVoted) {
          final votedPlayer = s.participants
              .where((p) => p.matchPlayerId == myVote!.votedMatchPlayerId)
              .firstOrNull;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.emerald200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.check_circle,
                      size: 14, color: AppColors.emerald700),
                  SizedBox(width: 6),
                  Text(
                    'Você já votou no MVP',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald700,
                        fontSize: 13),
                  ),
                ]),
                if (votedPlayer != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      'Votado: ${votedPlayer.playerName}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.slate600),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text(
                    'Aguardando os outros votarem...',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                ),
              ],
            ),
          );
        }

        // Convidado — não pode votar
        if (!canVote) {
          return const Text(
            'Convidados não participam da votação. Aguardando resultado...',
            style: TextStyle(fontSize: 13, color: AppColors.slate400),
          );
        }

        // Pode votar — mostra lista de jogadores
        final candidates = s.participants
            .where((p) => p.matchPlayerId != myMatchPlayerId)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...candidates.map((p) {
              final isSelected = _votedMpId == p.matchPlayerId;
              return GestureDetector(
                onTap: () => setState(
                    () => _votedMpId = isSelected ? null : p.matchPlayerId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.emerald500
                          : AppColors.slate200,
                    ),
                    color: isSelected ? AppColors.emerald50 : AppColors.slate50,
                  ),
                  child: Row(children: [
                    renderGroupIcon(
                      p.isGoalkeeper ? icons.goalkeeper : icons.player,
                      size: 14,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.playerName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppColors.emerald700
                              : AppColors.slate800,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          size: 16, color: AppColors.emerald500),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_votedMpId == null || s.mutating) ? null : _vote,
                child: s.mutating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onDark))
                    : const Text('Votar'),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── View do admin ─────────────────────────────────────────────────────────

  Widget _buildAdminView(BuildContext context, MatchState s, GroupIcons icons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Votar MVP ──────────────────────────────────────────────────
        _SectionCard(
          title: 'Votar MVP',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MVP já definido
              if (s.computedMvps.isNotEmpty) ...[
                _MvpResultCard(
                  mvpPlayers: s.computedMvps.map((m) {
                    final participant = s.participants
                        .where((p) => p.playerId == m.playerId)
                        .firstOrNull;
                    return (
                      name: m.playerName,
                      isGoalkeeper: participant?.isGoalkeeper ?? false,
                    );
                  }).toList(),
                  icons: icons,
                ),
                const SizedBox(height: 8),
              ],
              // Contagem de votos
              if (s.eligibleVoters.isNotEmpty) ...[
                Text(
                  'Admin pode votar por qualquer jogador ainda não votado. '
                  '(${s.votes.length}/${s.participants.where((p) => !p.isGuest).length} votaram)',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 10),
                // 2 colunas: Quem vota | Votado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildVoterColumn(s, icons)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildVotedColumn(s, icons)),
                  ],
                ),
                const SizedBox(height: 10),
                // Detalhamento dos votos
                if (s.votes.isNotEmpty) ...[
                  const Text(
                    'DETALHAMENTO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.slate400),
                  ),
                  const SizedBox(height: 6),
                  ...s.votes.map((v) {
                    final voter = s.participants
                        .where((p) => p.matchPlayerId == v.voterMatchPlayerId)
                        .firstOrNull;
                    final voted = s.participants
                        .where((p) => p.matchPlayerId == v.votedMatchPlayerId)
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        Expanded(
                          child: PlayerNameWithIcon(
                            name: voter?.playerName ?? '?',
                            isGoalkeeper: voter?.isGoalkeeper ?? false,
                            icons: icons,
                            iconSize: 12,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.slate500),
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 12, color: AppColors.slate300),
                        const SizedBox(width: 4),
                        Expanded(
                          child: PlayerNameWithIcon(
                            name: voted?.playerName ?? '?',
                            isGoalkeeper: voted?.isGoalkeeper ?? false,
                            icons: icons,
                            iconSize: 12,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                // Botão votar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MVP atual: ${s.computedMvps.isNotEmpty ? s.computedMvps.map((m) => m.playerName).join(' & ') : "—"}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.slate500),
                    ),
                    FilledButton(
                      onPressed: (_votedMpId == null ||
                              _voterMpId == null ||
                              s.mutating)
                          ? null
                          : _vote,
                      child: const Text('Votar'),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Todos os jogadores já votaram.',
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
              ],
              // As parciais continuam disponíveis para o administrador
              // mesmo após todos votarem.
              if (s.voteCounts.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'PARCIAIS DO MVP',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.slate400),
                ),
                const SizedBox(height: 6),
                ...s.voteCounts.map((vc) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.slate200),
                        color: AppColors.slate50,
                      ),
                      child: Row(children: [
                        Expanded(
                          child: PlayerNameWithIcon(
                            name: vc.playerName,
                            isGoalkeeper: s.participants
                                    .where((p) =>
                                        p.matchPlayerId == vc.matchPlayerId)
                                    .firstOrNull
                                    ?.isGoalkeeper ??
                                false,
                            icons: icons,
                            iconSize: 13,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.slate200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${vc.count}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ]),
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 2. Placar ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'Placar',
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _scoreACtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.teamAColor?.name ?? 'Time A',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('×', style: TextStyle(fontSize: 20)),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _scoreBCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.teamBColor?.name ?? 'Time B',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              if (s.teamAGoals != null && s.teamBGoals != null)
                Text(
                  'Atual: ${s.teamAGoals} × ${s.teamBGoals}',
                  style:
                      const TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: s.mutating ? null : _saveScore,
                  child: const Text('Salvar Placar'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 3. Gols ───────────────────────────────────────────────────────
        _SectionCard(
          title: 'Gols da Partida',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Goal form
              () {
                final teamA = s.participants.where((p) => p.team == 1).toList();
                final teamB = s.participants.where((p) => p.team == 2).toList();
                final allParticipants = s.participants.isNotEmpty
                    ? s.participants
                    : [...s.teamAPlayers, ...s.teamBPlayers];
                return InlineGoalTracker(
                  minute: _goalMinute,
                  scorerMpId: _scorerMpId,
                  assistMpId: _assistMpId,
                  isOwnGoal: _isOwnGoal,
                  isEditing: _editingGoalId != null,
                  teamAPlayers: teamA.isNotEmpty ? teamA : allParticipants,
                  teamBPlayers: teamB,
                  teamAName: s.teamAColor?.name ?? 'Time A',
                  teamBName: s.teamBColor?.name ?? 'Time B',
                  teamAColor: s.teamAColor?.color,
                  teamBColor: s.teamBColor?.color,
                  mutating: s.mutating,
                  icons: icons,
                  onMinuteChanged: (v) => setState(() => _goalMinute = v),
                  onScorerChanged: (id) => setState(() {
                    _scorerMpId = id;
                    _assistMpId = null;
                  }),
                  onAssistChanged: (id) => setState(() => _assistMpId = id),
                  onOwnGoalChanged: (v) => setState(() => _isOwnGoal = v),
                  onSave: () => _saveGoal(s.participants.isNotEmpty
                      ? s.participants
                      : [...s.teamAPlayers, ...s.teamBPlayers]),
                  onCancel: _resetGoalForm,
                );
              }(),
              const SizedBox(height: 8),
              if (s.goals.isEmpty)
                const Text('Nenhum gol registrado.',
                    style: TextStyle(color: AppColors.slate400))
              else
                ...s.goals.map((g) {
                  final allParticipants = s.participants.isNotEmpty
                      ? s.participants
                      : [...s.teamAPlayers, ...s.teamBPlayers];
                  return GoalEntryRow(
                    goal: g,
                    teamAName: s.teamAColor?.name ?? 'Time A',
                    teamBName: s.teamBColor?.name ?? 'Time B',
                    teamAColor: s.teamAColor?.color,
                    teamBColor: s.teamBColor?.color,
                    participants: allParticipants,
                    icons: icons,
                    isAdmin: true,
                    onEdit: () => _editGoal(g, allParticipants),
                    onRemove: () => ref
                        .read(matchNotifierProvider.notifier)
                        .removeGoal(g.goalId),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildVoterColumn(MatchState s, GroupIcons icons) {
    final nonGuestCount = s.participants.where((p) => !p.isGuest).length;
    final alreadyVotedCount = nonGuestCount - s.eligibleVoters.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('QUEM VOTA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.slate500)),
          if (alreadyVotedCount > 0) ...[
            const SizedBox(width: 4),
            Text('($alreadyVotedCount já votou)',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.slate400)),
          ],
        ]),
        const SizedBox(height: 6),
        ...s.eligibleVoters.map((p) {
          final isSelected = _voterMpId == p.matchPlayerId;
          return GestureDetector(
            onTap: () => setState(() {
              _voterMpId = isSelected ? null : p.matchPlayerId;
              _votedMpId = null;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        isSelected ? AppColors.emerald500 : AppColors.slate200),
                color: isSelected ? AppColors.emerald50 : AppColors.slate50,
              ),
              child: PlayerNameWithIcon(
                name: p.playerName,
                isGoalkeeper: p.isGoalkeeper,
                icons: icons,
                iconSize: 13,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.emerald700 : AppColors.slate800,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVotedColumn(MatchState s, GroupIcons icons) {
    final candidates =
        s.participants.where((p) => p.matchPlayerId != _voterMpId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('VOTADO',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.slate500)),
        const SizedBox(height: 6),
        ...candidates.map((p) {
          final isSelected = _votedMpId == p.matchPlayerId;
          return GestureDetector(
            onTap: () => setState(
                () => _votedMpId = isSelected ? null : p.matchPlayerId),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        isSelected ? AppColors.emerald500 : AppColors.slate200),
                color: isSelected ? AppColors.emerald50 : AppColors.slate50,
              ),
              child: PlayerNameWithIcon(
                name: p.playerName,
                isGoalkeeper: p.isGoalkeeper,
                icons: icons,
                iconSize: 13,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.emerald700 : AppColors.slate800,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Card de MVP resultado ─────────────────────────────────────────────────────

class _MvpResultCard extends StatelessWidget {
  final List<({String name, bool isGoalkeeper})> mvpPlayers;
  final GroupIcons icons;
  const _MvpResultCard({required this.mvpPlayers, required this.icons});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amber50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amber200),
        ),
        child: Row(children: [
          renderGroupIcon(icons.mvp, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MVP',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber500,
                      letterSpacing: 0.6)),
              ...mvpPlayers.map(
                (player) => PlayerNameWithIcon(
                  name: player.name,
                  isGoalkeeper: player.isGoalkeeper,
                  icons: icons,
                  iconSize: 15,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Card de seção ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const Divider(height: 16),
              child,
            ],
          ),
        ),
      );
}
