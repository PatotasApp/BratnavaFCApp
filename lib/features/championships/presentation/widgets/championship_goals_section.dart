import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../history/domain/entities/match_details.dart';
import '../../../history/presentation/widgets/match_goals_panel.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';
import '../providers/championship_provider.dart';

/// Gols do campeonato separados por jogo, com o mesmo painel da partida: abas
/// por time, horário de cada gol e, para o admin, registrar/editar/excluir
/// (inclusive com o campeonato finalizado — a API recalcula placar e
/// classificação).
class ChampionshipGoalsSection extends StatefulWidget {
  const ChampionshipGoalsSection({
    super.key,
    required this.details,
    required this.isAdmin,
    required this.notifier,
    required this.icons,
  });

  final ChampionshipDetails details;
  final bool isAdmin;
  final ChampionshipDetailsNotifier notifier;
  final GroupIcons icons;

  @override
  State<ChampionshipGoalsSection> createState() =>
      _ChampionshipGoalsSectionState();
}

class _ChampionshipGoalsSectionState extends State<ChampionshipGoalsSection> {
  String? _gameId;
  int _teamTab = 0;

  List<ChampionshipGame> get _games => widget.details.games
      .where((game) => game.status != ChampionshipGameStatus.inProgress)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  ChampionshipTeam? _team(String id) =>
      widget.details.teams.where((team) => team.id == id).firstOrNull;

  ChampionshipPlayer? _player(String? id) => id == null
      ? null
      : widget.details.players.where((p) => p.playerId == id).firstOrNull;

  /// Jogadores do jogo no formato da partida (time 1 = A, 2 = B).
  List<MatchPlayer> _players(ChampionshipGame game) => [
        for (final p in widget.details.players)
          if (!p.didNotPlay &&
              (p.teamId == game.teamAId || p.teamId == game.teamBId))
            MatchPlayer(
              matchPlayerId: p.playerId,
              playerId: p.playerId,
              playerName: p.name,
              isGoalkeeper: p.isGoalkeeper,
              team: p.teamId == game.teamAId ? 1 : 2,
            ),
      ];

  List<GoalWithTeam> _goals(ChampionshipGame game) {
    final indexed = game.goals.indexed.toList()
      ..sort((x, y) {
        final byTime = (x.$2.timeSeconds ?? 1 << 30)
            .compareTo(y.$2.timeSeconds ?? 1 << 30);
        return byTime != 0 ? byTime : x.$1.compareTo(y.$1);
      });
    return [
      for (final (_, goal) in indexed)
        GoalWithTeam(
          goal: MatchGoal(
            goalId: goal.id,
            scorerPlayerId: goal.scorerPlayerId,
            scorerName: _player(goal.scorerPlayerId)?.name,
            assistPlayerId: goal.assistPlayerId,
            assistName: _player(goal.assistPlayerId)?.name,
            time: formatGoalTime(goal.timeSeconds),
            isOwnGoal: goal.isOwnGoal,
          ),
          team: _side(game, goal),
        ),
    ];
  }

  String _side(ChampionshipGame game, ChampionshipGoal goal) {
    final teamId = _player(goal.scorerPlayerId)?.teamId;
    final scorerSide = teamId == game.teamAId
        ? 'A'
        : teamId == game.teamBId
            ? 'B'
            : '?';
    if (!goal.isOwnGoal || scorerSide == '?') return scorerSide;
    return scorerSide == 'A' ? 'B' : 'A';
  }

  Future<void> _openForm(ChampionshipGame game, {MatchGoal? editing}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => GoalFormSheet(
          players: _players(game),
          icons: widget.icons,
          editing: editing,
          onSave: (scorerId, assistId, time, isOwnGoal) async {
            final seconds = parseGoalTime(time);
            final ok = editing == null
                ? await widget.notifier.addGoal(
                    gameId: game.id,
                    scorerPlayerId: scorerId,
                    assistPlayerId:
                        assistId == null || assistId.isEmpty ? null : assistId,
                    isOwnGoal: isOwnGoal,
                    timeSeconds: seconds,
                  )
                : await widget.notifier.updateGoal(
                    gameId: game.id,
                    goalId: editing.goalId,
                    scorerPlayerId: scorerId,
                    assistPlayerId:
                        assistId == null || assistId.isEmpty ? null : assistId,
                    isOwnGoal: isOwnGoal,
                    timeSeconds: seconds,
                  );
            if (!ok) throw Exception('Falha ao salvar o gol.');
          },
        ),
      );

  Future<void> _delete(ChampionshipGame game, MatchGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir gol?'),
        content: Text('Excluir o gol de ${goal.scorerName ?? 'jogador'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.notifier.deleteGoal(game.id, goal.goalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    if (games.isEmpty) return const SizedBox.shrink();
    final game = games.where((g) => g.id == _gameId).firstOrNull ?? games.first;
    final teamA = _team(game.teamAId);
    final teamB = _team(game.teamBId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final players = _players(game);

    return PrototypeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                renderGroupIcon(widget.icons.goal, size: 18),
                const SizedBox(width: 8),
                Text('Gols', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          if (games.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: PrototypeSegmented(
                items: [for (final g in games) 'Jogo ${g.order}'],
                value: 'Jogo ${game.order}',
                onChanged: (label) => setState(() {
                  _gameId = games.firstWhere((g) => 'Jogo ${g.order}' == label).id;
                  _teamTab = 0;
                }),
                semanticLabel: 'Jogo do campeonato',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Jogo ${game.order} · ${teamA?.name ?? 'Time A'} '
              '${game.teamAGoals} × ${game.teamBGoals} ${teamB?.name ?? 'Time B'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          MatchGoalsSection(
            goals: _goals(game),
            tab: _teamTab,
            onTab: (tab) => setState(() => _teamTab = tab),
            aColor: _color(teamA?.colorHex),
            bColor: _color(teamB?.colorHex),
            aName: teamA?.name ?? 'Time A',
            bName: teamB?.name ?? 'Time B',
            isDark: isDark,
            icons: widget.icons,
            goalkeeperByName: {for (final p in players) p.playerName: p.isGoalkeeper},
            isAdmin: widget.isAdmin,
            onAddGoal: widget.isAdmin ? () => _openForm(game) : null,
            onEditGoal: widget.isAdmin
                ? (goal) => _openForm(game, editing: goal)
                : null,
            onDeleteGoal:
                widget.isAdmin ? (goal) => _delete(game, goal) : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _color(String? hex) {
    final normalized = hex?.replaceFirst('#', '');
    final value =
        normalized == null ? null : int.tryParse('FF$normalized', radix: 16);
    return value == null ? AppColors.slate400 : Color(value);
  }
}

/// Horário igual ao da partida: o valor gravado é minutos*60+segundos de "HH:MM".
String? formatGoalTime(int? seconds) {
  if (seconds == null || seconds < 0) return null;
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

int? parseGoalTime(String value) {
  final match = RegExp(r'^(\d{1,3}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final seconds = int.parse(match.group(2)!);
  if (seconds > 59) return null;
  return int.parse(match.group(1)!) * 60 + seconds;
}
