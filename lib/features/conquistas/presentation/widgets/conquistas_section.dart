import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/achievement_catalog.dart';
import '../../domain/achievement_progress.dart';
import '../../domain/entities/conquista_models.dart';
import 'achievement_progress_sheet.dart';

List<Conquista> topConquistas(PlayerConquistas player, [int limit = 3]) {
  final unlocked = <Conquista>[
    ...player.titulos,
    ...player.eventos.where((item) => (item.count ?? 0) > 0),
    ...player.marcos.where((item) => item.desbloqueada),
  ];
  final items = _removeDominatedProgressions(unlocked);
  items.sort(_compareAchievementDifficulty);

  final selected = <Conquista>[];
  final usedCategories = <String>{};

  // Primeiro garante variedade, mantendo somente a conquista mais forte de
  // cada categoria entre os destaques.
  for (final item in items) {
    final category = _achievementCategoryKey(item);
    if (!usedCategories.add(category)) continue;
    selected.add(item);
    if (selected.length == limit) return selected;
  }

  // Se não houver categorias suficientes, completa os espaços com as
  // próximas melhores conquistas, sem esconder conteúdo relevante.
  for (final item in items) {
    if (selected.contains(item)) continue;
    selected.add(item);
    if (selected.length == limit) break;
  }
  return selected;
}

List<Conquista> _removeDominatedProgressions(List<Conquista> items) {
  final independent = <Conquista>[];
  final strongestByProgression = <String, Conquista>{};

  for (final item in items) {
    final progression = _achievementProgressionKey(item);
    if (progression == null) {
      independent.add(item);
      continue;
    }

    final current = strongestByProgression[progression];
    if (current == null || _achievementTier(item) > _achievementTier(current)) {
      strongestByProgression[progression] = item;
    }
  }

  return [...independent, ...strongestByProgression.values];
}

String? _achievementProgressionKey(Conquista achievement) =>
    switch (achievement.id) {
      'evento-hat-trick' ||
      'evento-poker' ||
      'evento-cinco-estrelas' =>
        'gols-na-partida',
      'evento-embalado' ||
      'evento-invicto' ||
      'evento-super-invicto' =>
        'sequencia-invicta',
      'evento-muralha' || 'evento-fortaleza' => 'sequencia-sem-sofrer-gols',
      _ => null,
    };

int _compareAchievementDifficulty(Conquista a, Conquista b) {
  final sameCategory = _achievementCategoryKey(a) == _achievementCategoryKey(b);
  final aTier = _achievementTier(a);
  final bTier = _achievementTier(b);

  // Dentro da mesma categoria, a progressão lógica prevalece sobre qualquer
  // raridade dinâmica calculada para a patota.
  if (sameCategory && aTier != bTier) return bTier.compareTo(aTier);

  final rarity = _rarityRank(b.raridade).compareTo(_rarityRank(a.raridade));
  if (rarity != 0) return rarity;
  if (aTier != bTier) return bTier.compareTo(aTier);

  final level = (b.nivel ?? 0).compareTo(a.nivel ?? 0);
  if (level != 0) return level;

  final aPosition = a.posicao ?? 99;
  final bPosition = b.posicao ?? 99;
  if (aPosition != bPosition) return aPosition.compareTo(bPosition);
  return (b.ano ?? 0).compareTo(a.ano ?? 0);
}

int _rarityRank(String rarity) => switch (rarity.toLowerCase()) {
      'lendaria' || 'lendária' => 4,
      'epica' || 'épica' => 3,
      'rara' => 2,
      _ => 1,
    };

int _achievementTier(Conquista achievement) => switch (achievement.id) {
      'evento-cinco-estrelas' => 1000,
      'evento-poker' => 900,
      'evento-hat-trick' => 800,
      'evento-super-invicto' => 950,
      'evento-invicto' => 850,
      'evento-embalado' => 800,
      'evento-garcom-gala' => 900,
      'evento-completo' => 700,
      'evento-fortaleza' => 900,
      'evento-muralha' => 700,
      _ when achievement.id.startsWith('marco-') =>
        500 + ((achievement.nivel ?? 0) * 10),
      _ when achievement.id.startsWith('titulo-') =>
        700 + (4 - (achievement.posicao ?? 3)) * 50,
      _ => 500,
    };

String _achievementCategoryKey(Conquista achievement) {
  final category = achievement.categoria.trim().toLowerCase();
  return category.isEmpty ? achievement.id : category;
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
  final PlayerConquistas player;
  final bool compact;
  const ConquistaBadge({
    super.key,
    required this.conquista,
    required this.player,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = conquistaRarityColor(context, conquista.raridade);
    return Tooltip(
      message: 'Ver evolução de ${conquista.categoria}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAchievementProgressSheet(
          context,
          selected: conquista,
          player: player,
        ),
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
      ),
    );
  }
}

class ConquistasSection extends StatelessWidget {
  final PlayerConquistas player;
  final bool showHeading;

  const ConquistasSection({
    super.key,
    required this.player,
    this.showHeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final catalog = buildAchievementCatalog(player);
    final feats = catalog
        .where((item) => item.kind == AchievementCatalogKind.feat)
        .toList();
    final milestones = catalog
        .where((item) => item.kind == AchievementCatalogKind.milestone)
        .toList();
    final titles = catalog
        .where((item) => item.kind == AchievementCatalogKind.title)
        .toList();
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
        if (feats.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Feitos',
            subtitle: 'Todos os desafios disponíveis',
            child: _CatalogTrackList(tracks: feats),
          ),
          const SizedBox(height: 12),
        ],
        if (milestones.isNotEmpty) ...[
          _SectionCard(
            icon: Icons.flag_rounded,
            title: 'Marcos',
            subtitle: 'Todos os níveis da sua trajetória',
            child: _CatalogTrackList(tracks: milestones),
          ),
          const SizedBox(height: 12),
        ],
        if (titles.isNotEmpty)
          _SectionCard(
            icon: Icons.emoji_events_rounded,
            title: 'Títulos',
            subtitle: 'Todos os pódios que podem ser conquistados',
            child: _CatalogTrackList(tracks: titles),
          ),
      ],
    );
  }
}

class _CatalogTrackList extends StatelessWidget {
  final List<AchievementCatalogTrack> tracks;

  const _CatalogTrackList({required this.tracks});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < tracks.length; index++) ...[
            _CatalogTrackCard(track: tracks[index]),
            if (index < tracks.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
}

class _CatalogTrackCard extends StatefulWidget {
  final AchievementCatalogTrack track;

  const _CatalogTrackCard({required this.track});

  @override
  State<_CatalogTrackCard> createState() => _CatalogTrackCardState();
}

class _CatalogTrackCardState extends State<_CatalogTrackCard> {
  late int _selectedIndex = _initialIndex;

  AchievementCatalogTrack get track => widget.track;

  int get _currentIndex => track.stages.indexWhere(
        (stage) => stage.status == AchievementStepStatus.current,
      );

  int get _initialIndex => _currentIndex >= 0 ? _currentIndex : 0;

  @override
  void didUpdateWidget(covariant _CatalogTrackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != track.id ||
        oldWidget.track.stages.length != track.stages.length) {
      _selectedIndex = _initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex;
    final current = currentIndex >= 0 ? track.stages[currentIndex] : null;
    final next = currentIndex >= 0 && currentIndex < track.stages.length - 1
        ? track.stages[currentIndex + 1]
        : null;
    final selected =
        track.stages[_selectedIndex.clamp(0, track.stages.length - 1)];
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.appSurfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current == null
                      ? context.appSurface
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(track.icon, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      current == null
                          ? 'Ainda não conquistado'
                          : next == null
                              ? 'Seu nível: ${current.name} · máximo'
                              : 'Seu nível: ${current.name} · próximo: ${next.name}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: current == null
                                ? context.appTextSecondary
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var index = 0; index < track.stages.length; index++)
                _CatalogStageBadge(
                  stage: track.stages[index],
                  selected: index == _selectedIndex,
                  onTap: () => setState(() => _selectedIndex = index),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.name,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    Text(
                      _stageStatusLabel(selected.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                selected.status == AchievementStepStatus.current
                                    ? Theme.of(context).colorScheme.primary
                                    : context.appTextSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  selected.requirement,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                        height: 1.3,
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

String _stageStatusLabel(AchievementStepStatus status) => switch (status) {
      AchievementStepStatus.current => 'NÍVEL ATUAL',
      AchievementStepStatus.completed => 'CONQUISTADO',
      AchievementStepStatus.upcoming => 'A CONQUISTAR',
    };

class _CatalogStageBadge extends StatelessWidget {
  final AchievementProgressStep stage;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogStageBadge({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = stage.status == AchievementStepStatus.current;
    final wasCompleted = stage.status == AchievementStepStatus.completed;
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color:
                isCurrent ? primary.withValues(alpha: .11) : context.appSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? primary
                  : selected
                      ? context.appTextSecondary
                      : context.appBorder,
              width: isCurrent || selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCurrent
                    ? Icons.radio_button_checked_rounded
                    : wasCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.lock_outline_rounded,
                size: 14,
                color: isCurrent ? primary : context.appTextDisabled,
              ),
              const SizedBox(width: 5),
              Text(
                stage.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isCurrent
                          ? context.appTextPrimary
                          : context.appTextDisabled,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
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
