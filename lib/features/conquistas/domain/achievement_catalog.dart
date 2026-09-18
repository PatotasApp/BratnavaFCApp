import 'achievement_progress.dart';
import 'entities/conquista_models.dart';

enum AchievementCatalogKind { feat, milestone, title }

class AchievementCatalogTrack {
  final String id;
  final AchievementCatalogKind kind;
  final String title;
  final String subtitle;
  final String icon;
  final List<AchievementProgressStep> stages;
  final String guidance;

  const AchievementCatalogTrack({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stages,
    required this.guidance,
  });
}

List<AchievementCatalogTrack> buildAchievementCatalog(
  PlayerConquistas player,
) =>
    [
      ..._buildFeatTracks(player),
      ..._buildMilestoneTracks(player),
      ..._buildTitleTracks(player),
    ];

List<AchievementCatalogTrack> _buildFeatTracks(PlayerConquistas player) {
  final categories = <String, List<Conquista>>{};
  for (final event in player.eventos) {
    categories.putIfAbsent(event.categoria, () => []).add(event);
  }

  return categories.entries.map((entry) {
    final items = entry.value;
    final currentIndex = items.lastIndexWhere((item) => item.desbloqueada);
    final selected = items[currentIndex >= 0 ? currentIndex : 0];
    final track = buildAchievementProgress(selected: selected, player: player);
    return AchievementCatalogTrack(
      id: 'feito-${entry.key}',
      kind: AchievementCatalogKind.feat,
      title: _categoryLabel(entry.key),
      subtitle: 'Feitos especiais em partidas',
      icon: selected.icone,
      stages: track.steps,
      guidance: _guidance(track.steps, noun: 'feito'),
    );
  }).toList();
}

List<AchievementCatalogTrack> _buildMilestoneTracks(
  PlayerConquistas player,
) =>
    player.marcos.map((milestone) {
      final progress = buildAchievementProgress(
        selected: milestone,
        player: player,
      );
      return AchievementCatalogTrack(
        id: milestone.id,
        kind: AchievementCatalogKind.milestone,
        title: _categoryLabel(milestone.categoria),
        subtitle: 'Evolução permanente da trajetória',
        icon: milestone.icone,
        stages: progress.steps,
        guidance: _guidance(progress.steps, noun: 'marco'),
      );
    }).toList();

List<AchievementCatalogTrack> _buildTitleTracks(PlayerConquistas player) {
  final definitions = <({String category, String name, String icon})>[
    (category: 'Gols', name: 'Artilheiro', icon: '⚽'),
    (
      category: 'Assistencias',
      name: 'Rei das Assistências',
      icon: '🅰️',
    ),
    (category: 'MVPs', name: 'Rei dos MVPs', icon: '🏅'),
    (category: 'Presenca', name: 'Mais Presente', icon: '🎽'),
    (
      category: 'Aproveitamento',
      name: 'Melhor Aproveitamento',
      icon: '📈',
    ),
  ];

  return definitions.map((definition) {
    final earned = player.titulos
        .where(
          (title) => _sameCategory(title.categoria, definition.category),
        )
        .toList();
    final positions = earned.map((title) => title.posicao ?? 99).toList();
    final bestPosition = positions.isEmpty
        ? null
        : positions.reduce((current, next) => current < next ? current : next);
    final currentIndex =
        switch (bestPosition) { 3 => 0, 2 => 1, 1 => 2, _ => -1 };
    final stages = <AchievementProgressStep>[
      for (var index = 0; index < 3; index++)
        AchievementProgressStep(
          name: switch (index) {
            0 => '3º lugar',
            1 => '2º lugar',
            _ => '1º lugar',
          },
          requirement: switch (index) {
            0 => 'Termine uma temporada em terceiro lugar nesta categoria.',
            1 => 'Termine uma temporada em segundo lugar nesta categoria.',
            _ => 'Termine uma temporada em primeiro lugar nesta categoria.',
          },
          status: index == currentIndex
              ? AchievementStepStatus.current
              : index < currentIndex
                  ? AchievementStepStatus.completed
                  : AchievementStepStatus.upcoming,
          unlocked: index <= currentIndex,
        ),
    ];

    return AchievementCatalogTrack(
      id: 'titulo-${definition.category}',
      kind: AchievementCatalogKind.title,
      title: definition.name,
      subtitle: 'Melhor pódio em temporadas encerradas',
      icon: definition.icon,
      stages: stages,
      guidance: _guidance(stages, noun: 'título'),
    );
  }).toList();
}

String _guidance(
  List<AchievementProgressStep> stages, {
  required String noun,
}) {
  final currentIndex = stages.indexWhere(
    (stage) => stage.status == AchievementStepStatus.current,
  );
  if (currentIndex < 0) {
    return stages.isEmpty
        ? 'Ainda não há etapas disponíveis.'
        : 'Para conquistar o primeiro $noun: ${stages.first.requirement}';
  }
  final current = stages[currentIndex];
  if (currentIndex == stages.length - 1) {
    return 'Por que está neste nível: ${current.requirement}\n'
        'Maior nível alcançado nesta categoria.';
  }
  final next = stages[currentIndex + 1];
  return 'Por que está neste nível: ${current.requirement}\n'
      'Próximo: ${next.name} — ${next.requirement}';
}

String _categoryLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'criacao' => 'Criação',
    'vitorias' => 'Vitórias',
    'assistencias' => 'Assistências',
    'presenca' => 'Presença',
    'zoeira' => 'Zoeira',
    final normalized when normalized.isNotEmpty =>
      '${normalized[0].toUpperCase()}${normalized.substring(1)}',
    _ => 'Conquista',
  };
}

bool _sameCategory(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();
