import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';

class MatchPlayerRoleToggle extends StatelessWidget {
  const MatchPlayerRoleToggle({
    super.key,
    required this.playerName,
    required this.isGoalkeeper,
    required this.icons,
    required this.busy,
    required this.onPressed,
  });

  final String playerName;
  final bool isGoalkeeper;
  final GroupIcons icons;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = isGoalkeeper ? 'Goleiro' : 'Linha';
    final nextRole = isGoalkeeper ? 'jogador de linha' : 'goleiro';
    final inactive = isDark ? AppColors.slate500 : AppColors.slate400;
    final track = isDark ? AppColors.slate700 : AppColors.slate200;
    final border = isDark ? AppColors.slate600 : AppColors.slate300;
    final background = isDark
        ? AppColors.slate800.withValues(alpha: 0.55)
        : AppColors.slate100.withValues(alpha: 0.8);
    final actionDescription = '$role. Toque para mudar para $nextRole';

    return Tooltip(
      message: actionDescription,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: '$playerName: $actionDescription',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('match-player-role-toggle'),
            onTap: busy ? null : onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                      key: const Key('role-goalkeeper-icon'),
                      opacity: isGoalkeeper ? 1 : 0.42,
                      child: renderGroupIcon(
                        icons.goalkeeper,
                        size: 15,
                        color: isGoalkeeper ? AppColors.emerald500 : inactive,
                      )),
                  const SizedBox(width: 4),
                  AnimatedContainer(
                    key: const Key('match-player-role-switch'),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    width: 30,
                    height: 16,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: border),
                    ),
                    child: busy
                        ? const Center(
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: AppColors.emerald500,
                              ),
                            ),
                          )
                        : AnimatedAlign(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            alignment: isGoalkeeper
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              key: const Key('match-player-role-thumb'),
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.emerald500,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Opacity(
                    key: const Key('role-field-player-icon'),
                    opacity: isGoalkeeper ? 0.42 : 1,
                    child: renderGroupIcon(
                      icons.player,
                      size: 15,
                      color: isGoalkeeper ? inactive : AppColors.emerald500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
