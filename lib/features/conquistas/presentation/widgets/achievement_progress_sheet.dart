import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/achievement_progress.dart';
import '../../domain/entities/conquista_models.dart';

Future<void> showAchievementProgressSheet(
  BuildContext context, {
  required Conquista selected,
  required PlayerConquistas player,
}) {
  final track = buildAchievementProgress(selected: selected, player: player);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.transparent,
    builder: (_) => _AchievementProgressSheet(track: track),
  );
}

class _AchievementProgressSheet extends StatelessWidget {
  final AchievementProgressTrack track;

  const _AchievementProgressSheet({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.appTextSecondary,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appSeparator),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _ProgressLegend(),
                const SizedBox(height: 14),
                for (var index = 0; index < track.steps.length; index++) ...[
                  _ProgressStepTile(
                    step: track.steps[index],
                    number: index + 1,
                  ),
                  if (index < track.steps.length - 1) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(
          icon: Icons.check_rounded,
          label: 'Concluída',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 14),
        _LegendItem(
          icon: Icons.location_on_outlined,
          label: 'Atual',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 14),
        _LegendItem(
          icon: Icons.lock_outline_rounded,
          label: 'Próxima',
          color: context.appTextDisabled,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LegendItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStepTile extends StatelessWidget {
  final AchievementProgressStep step;
  final int number;

  const _ProgressStepTile({
    required this.step,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isCurrent = step.status == AchievementStepStatus.current;
    final isCompleted = step.status == AchievementStepStatus.completed;
    final color = isCurrent || isCompleted ? primary : context.appTextDisabled;
    final statusLabel = switch (step.status) {
      AchievementStepStatus.completed => 'Concluída',
      AchievementStepStatus.current =>
        step.unlocked ? 'Você está aqui' : 'Primeira etapa',
      AchievementStepStatus.upcoming => 'Próxima etapa',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isCurrent
            ? primary.withValues(alpha: .09)
            : context.appSurfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? primary : context.appBorder,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: isCompleted
                ? Icon(Icons.check_rounded, size: 18, color: color)
                : isCurrent
                    ? Icon(Icons.location_on_outlined, size: 17, color: color)
                    : Text(
                        '$number',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        step.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  isCompleted
                      ? 'Etapa conquistada.'
                      : isCurrent && step.unlocked
                          ? 'Conquista atual.'
                          : 'Para conquistar: ${step.requirement}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                        fontSize: 11,
                        height: 1.35,
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
