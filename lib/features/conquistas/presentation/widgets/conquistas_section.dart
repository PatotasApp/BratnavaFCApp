import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conquista_models.dart';

List<Conquista> topConquistas(PlayerConquistas player, [int limit = 3]) {
  final items = <Conquista>[
    ...player.titulos,
    ...player.eventos.where((item) => (item.count ?? 0) > 0),
    ...player.marcos.where((item) => item.desbloqueada),
  ];
  int rank(String rarity) => switch (rarity.toLowerCase()) {
        'lendaria' || 'lendária' => 4,
        'epica' || 'épica' => 3,
        'rara' => 2,
        _ => 1,
      };
  items.sort((a, b) => rank(b.raridade).compareTo(rank(a.raridade)));
  return items.take(limit).toList();
}

Color conquistaRarityColor(BuildContext context, String rarity) {
  return switch (rarity.toLowerCase()) {
    'lendaria' || 'lendária' => context.appWarning,
    'epica' || 'épica' => Theme.of(context).colorScheme.secondary,
    'rara' => context.appInfo,
    _ => context.appTextSecondary,
  };
}

class ConquistaBadge extends StatelessWidget {
  final Conquista conquista;
  final bool compact;
  const ConquistaBadge({
    super.key,
    required this.conquista,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = conquistaRarityColor(context, conquista.raridade);
    return Tooltip(
      message: '${conquista.nome}\n${conquista.descricao}',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(conquista.icone,
                style: TextStyle(fontSize: compact ? 12 : 14)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${conquista.nome}${(conquista.count ?? 0) > 1 ? ' ×${conquista.count}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConquistasSection extends StatelessWidget {
  final PlayerConquistas player;
  final int? season;
  final bool showHeading;

  const ConquistasSection({
    super.key,
    required this.player,
    this.season,
    this.showHeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final unlockedEvents =
        player.eventos.where((item) => (item.count ?? 0) > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'CONQUISTAS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.appTextSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 10),
        ],
        if (player.temporada.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.leaderboard_rounded,
            title: 'Temporada ${season ?? DateTime.now().year}',
            subtitle: 'Sua posição atual na patota',
            child: Column(
              children: player.temporada
                  .map((item) => _StandingRow(standing: item))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (player.titulos.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.emoji_events_rounded,
            title: 'Títulos',
            subtitle: 'Pódios conquistados em temporadas encerradas',
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: player.titulos
                  .map((item) => ConquistaBadge(conquista: item))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (player.marcos.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.flag_rounded,
            title: 'Marcos',
            subtitle: 'Metas permanentes da sua trajetória',
            child: Column(
              children: player.marcos
                  .map((item) => _MarcoTile(conquista: item))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (unlockedEvents.isNotEmpty)
          _SectionCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Feitos',
            subtitle: 'Façanhas realizadas durante as partidas',
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: unlockedEvents
                  .map((item) => ConquistaBadge(conquista: item))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  )),
                      Text(subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: context.appTextSecondary,
                                  )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _MarcoTile extends StatelessWidget {
  final Conquista conquista;
  const _MarcoTile({required this.conquista});

  @override
  Widget build(BuildContext context) {
    final value = conquista.valor ?? 0;
    final target = conquista.meta;
    final progress = target == null || target <= 0
        ? (conquista.desbloqueada ? 1.0 : 0.0)
        : (value / target).clamp(0.0, 1.0);
    final color = conquista.desbloqueada
        ? conquistaRarityColor(context, conquista.raridade)
        : context.appTextDisabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(conquista.icone, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conquista.desbloqueada
                            ? conquista.nome
                            : (conquista.proximoNome ?? conquista.nome),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                      ),
                    ),
                    if (target != null)
                      Text('$value/$target',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: context.appTextSecondary,
                                  )),
                  ],
                ),
                const SizedBox(height: 3),
                Text(conquista.descricao,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        )),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: color,
                    backgroundColor: context.appSurfaceSubtle,
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

class _StandingRow extends StatelessWidget {
  final SeasonStanding standing;
  const _StandingRow({required this.standing});

  @override
  Widget build(BuildContext context) {
    final color = conquistaRarityColor(context, standing.raridade);
    final top = (standing.percentil * 100).clamp(1, 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(standing.icone, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(standing.nome,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                Text('Top $top% · ${standing.posicao}º de ${standing.total}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.appTextSecondary,
                        )),
              ],
            ),
          ),
          Text('${standing.valor}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  )),
        ],
      ),
    );
  }
}
