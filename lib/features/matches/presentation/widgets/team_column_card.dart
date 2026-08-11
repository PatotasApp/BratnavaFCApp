import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/user_profile_link.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/match_models.dart';

/// Card de coluna de time exibido no MatchMaking (Step 3).
class TeamColumnCard extends StatelessWidget {
  final String teamLabel; // "TIME A" / "TIME B"
  final TeamColorInfo? color;
  final List<MatchPlayerInfo> players;
  final bool isAdmin;
  final bool loading;
  final GroupIcons icons;

  /// Chamado para mover o jogador para o outro time.
  final void Function(String playerId)? onMoveToOther;

  /// Chamado para trocar dois jogadores (passa o playerId selecionado para swap).
  final void Function(String playerId)? onSwapSelect;

  /// playerId atualmente selecionado para swap (null = nenhum).
  final String? swapCandidateId;

  const TeamColumnCard({
    super.key,
    required this.teamLabel,
    required this.players,
    this.color,
    this.isAdmin = false,
    this.loading = false,
    this.icons = GroupIcons.defaults,
    this.onMoveToOther,
    this.onSwapSelect,
    this.swapCandidateId,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = color?.color ?? AppColors.slate200;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho colorido
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: teamColor, width: 2)),
            ),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: teamColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    color?.name ?? teamLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${players.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),

          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (players.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Sem jogadores',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
            )
          else
            ...players.map((p) => _PlayerRow(
                  player: p,
                  isAdmin: isAdmin,
                  icons: icons,
                  isSwapCandidate: swapCandidateId == p.playerId,
                  onMoveToOther: onMoveToOther != null
                      ? () => onMoveToOther!(p.playerId)
                      : null,
                  onSwapSelect: onSwapSelect != null
                      ? () => onSwapSelect!(p.playerId)
                      : null,
                )),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final MatchPlayerInfo player;
  final bool isAdmin;
  final bool isSwapCandidate;
  final GroupIcons icons;
  final VoidCallback? onMoveToOther;
  final VoidCallback? onSwapSelect;

  const _PlayerRow({
    required this.player,
    required this.isAdmin,
    required this.isSwapCandidate,
    this.icons = GroupIcons.defaults,
    this.onMoveToOther,
    this.onSwapSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSwapCandidate ? AppColors.blue50 : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          UserProfileLink(
            userId: player.userId,
            child: AvatarWidget(
                name: player.playerName, photoUrl: player.photoUrl, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserProfileLink(
                  userId: player.userId,
                  child: PlayerNameWithIcon(
                    name: player.playerName,
                    isGoalkeeper: player.isGoalkeeper,
                    icons: icons,
                    iconSize: 13,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            // Botão mover para outro time
            if (onMoveToOther != null)
              IconButton(
                icon: const Icon(Icons.swap_horiz,
                    size: 18, color: AppColors.blue500),
                onPressed: onMoveToOther,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Mover para outro time',
              ),
          ],
        ],
      ),
    );
  }
}
