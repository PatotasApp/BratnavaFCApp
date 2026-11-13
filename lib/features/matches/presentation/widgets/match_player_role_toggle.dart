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
    final foreground = isDark ? AppColors.slate200 : AppColors.slate700;
    final border = isDark ? AppColors.slate600 : AppColors.slate300;
    final background = isDark
        ? AppColors.slate800.withValues(alpha: 0.75)
        : AppColors.slate100;
    final actionDescription = '$role — toque para mudar para $nextRole';

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    renderGroupIcon(
                      isGoalkeeper ? icons.goalkeeper : icons.player,
                      size: 14,
                      color: foreground,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.swap_horiz_rounded, size: 14, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
