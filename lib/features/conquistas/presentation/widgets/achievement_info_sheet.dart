import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

Future<void> showAchievementInfoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.transparent,
    builder: (_) => const _AchievementInfoSheet(),
  );
}

class AchievementInfoButton extends StatelessWidget {
  const AchievementInfoButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Entenda as conquistas',
        visualDensity: VisualDensity.compact,
        onPressed: () => showAchievementInfoSheet(context),
        icon: const Icon(Icons.info_outline_rounded, size: 20),
      );
}

class _AchievementInfoSheet extends StatelessWidget {
  const _AchievementInfoSheet();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sobre as conquistas',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Elas resumem sua trajetória em cada patota.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.appTextSecondary,
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
              const SizedBox(height: 18),
              const _InfoItem(
                icon: Icons.auto_awesome_rounded,
                title: 'Feitos',
                description:
                    'Façanhas especiais em partidas, como marcar muitos gols em um jogo.',
              ),
              const SizedBox(height: 10),
              const _InfoItem(
                icon: Icons.flag_rounded,
                title: 'Marcos',
                description:
                    'Metas acumuladas ao longo da trajetória, como jogos, gols e assistências.',
              ),
              const SizedBox(height: 10),
              const _InfoItem(
                icon: Icons.emoji_events_rounded,
                title: 'Títulos',
                description:
                    'Pódios conquistados nas classificações de temporadas encerradas.',
              ),
            ],
          ),
        ),
      );
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appTextSecondary,
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
