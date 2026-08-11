import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/user_profile_link.dart';
import '../../domain/entities/match_models.dart';

// ── Helpers de ausência (espelha absenceIcons.ts) ─────────────────────────────

IconData _absenceIcon(int type) {
  switch (type) {
    case 1:
      return Icons.flight_outlined;
    case 2:
      return Icons.local_hospital_outlined;
    case 3:
      return Icons.favorite_border;
    default:
      return Icons.more_horiz_outlined;
  }
}

String _absenceLabel(int type) {
  switch (type) {
    case 1:
      return 'Viagem';
    case 2:
      return 'Departamento Médico';
    case 3:
      return 'Pessoal';
    default:
      return 'Outros';
  }
}

/// Tile de jogador reutilizável em Aceitação e MatchMaking.
class PlayerListTile extends StatelessWidget {
  final MatchPlayerInfo player;
  final bool isCurrentUser;
  final bool isAdmin;
  final bool loading;

  /// Chamado quando admin quer remover / recusar o jogador (ícone ❌).
  final VoidCallback? onRemove;

  /// Chamado quando o próprio usuário quer aceitar (ícone ✅).
  final VoidCallback? onAccept;

  /// Cor de destaque do tile (null = padrão).
  final Color? highlightColor;

  const PlayerListTile({
    super.key,
    required this.player,
    this.isCurrentUser = false,
    this.isAdmin = false,
    this.loading = false,
    this.onRemove,
    this.onAccept,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: highlightColor ?? AppColors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: UserProfileLink(
          userId: player.userId,
          child: AvatarWidget(
              name: player.playerName, photoUrl: player.photoUrl, size: 36),
        ),
        title: UserProfileLink(
          userId: player.userId,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  player.playerName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (player.isGoalkeeper) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sports_soccer,
                    size: 14, color: AppColors.slate400),
              ],
              if (player.inviteResponse == InviteResponse.declined &&
                  player.absenceType != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: player.absenceDescription ??
                      _absenceLabel(player.absenceType!),
                  child: Icon(
                    _absenceIcon(player.absenceType!),
                    size: 14,
                    color: player.absenceType == 2
                        ? AppColors.rose500
                        : AppColors.slate400,
                  ),
                ),
              ],
              if (player.isGuest) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.amber200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Convidado',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.warningLight),
                  ),
                ),
              ],
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.blue200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Você',
                    style: TextStyle(fontSize: 10, color: AppColors.infoLight),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onAccept != null)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline,
                          color: AppColors.emerald500),
                      onPressed: onAccept,
                      tooltip: 'Aceitar',
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  if (onRemove != null && isAdmin)
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.rose500),
                      onPressed: onRemove,
                      tooltip: 'Remover',
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                ],
              ),
      ),
    );
  }
}
