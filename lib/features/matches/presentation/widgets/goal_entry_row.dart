import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/match_models.dart';

/// Linha de gol exibida na lista de Steps 4 e 6.
class GoalEntryRow extends StatelessWidget {
  final MatchGoal goal;
  final String teamAName;
  final String teamBName;
  final Color? teamAColor;
  final Color? teamBColor;
  final List<MatchPlayerInfo> participants;
  final GroupIcons icons;
  final bool isAdmin;
  final bool loading;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;

  const GoalEntryRow({
    super.key,
    required this.goal,
    required this.teamAName,
    required this.teamBName,
    this.teamAColor,
    this.teamBColor,
    this.participants = const [],
    this.icons = GroupIcons.defaults,
    this.isAdmin = false,
    this.loading = false,
    this.onRemove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scorer = _findScorer();
    final assister = _findAssist();
    final scorerTeam =
        scorer?.team == 1 || scorer?.team == 2 ? scorer!.team : null;
    final playerTeam = goal.isOwnGoal && scorerTeam != null
        ? (scorerTeam == 1 ? 2 : 1)
        : (scorerTeam ?? goal.team);
    final isTeamA = playerTeam == 1;
    final color = isTeamA
        ? (teamAColor ?? AppColors.blue500)
        : (teamBColor ?? AppColors.rose500);
    final teamName = isTeamA ? teamAName : teamBName;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Indicador de time
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // Ícone + tempo
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                renderGroupIcon(
                  goal.isOwnGoal ? icons.ownGoal : icons.goal,
                  size: 18,
                  color: goal.isOwnGoal ? AppColors.rose500 : color,
                ),
                if (goal.time != null)
                  Text(
                    goal.time!,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.slate500),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // Detalhes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          goal.scorerName ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      if (scorer != null) ...[
                        const SizedBox(width: 4),
                        renderGroupIcon(
                          scorer.isGoalkeeper ? icons.goalkeeper : icons.player,
                          size: 12,
                          color: AppColors.slate400,
                        ),
                      ],
                      if (goal.isOwnGoal) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '(gol contra)',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.rose500),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        teamName,
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500),
                      ),
                      if (goal.assistName != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.slate400)),
                        renderGroupIcon(
                          icons.assist,
                          size: 11,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            goal.assistName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.slate500),
                          ),
                        ),
                        if (assister != null) ...[
                          const SizedBox(width: 3),
                          renderGroupIcon(
                            assister.isGoalkeeper
                                ? icons.goalkeeper
                                : icons.player,
                            size: 10,
                            color: AppColors.slate400,
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Botões editar/remover (admin)
            if (isAdmin)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.slate400),
                          onPressed: onEdit,
                          tooltip: 'Editar gol',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                  if (!loading)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.rose400),
                      onPressed: onRemove,
                      tooltip: 'Remover gol',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  MatchPlayerInfo? _findScorer() {
    for (final player in participants) {
      if (goal.scorerMatchPlayerId != null &&
          player.matchPlayerId == goal.scorerMatchPlayerId) {
        return player;
      }
      if (goal.scorerPlayerId != null &&
          player.playerId == goal.scorerPlayerId) {
        return player;
      }
    }
    return null;
  }

  MatchPlayerInfo? _findAssist() {
    for (final player in participants) {
      if (goal.assistMatchPlayerId != null &&
          player.matchPlayerId == goal.assistMatchPlayerId) {
        return player;
      }
      if (goal.assistPlayerId != null &&
          player.playerId == goal.assistPlayerId) {
        return player;
      }
    }
    return null;
  }
}
