import 'entities/conquista_models.dart';

enum AchievementStepStatus { completed, current, upcoming }

class AchievementProgressStep {
  final String name;
  final String requirement;
  final AchievementStepStatus status;
  final bool unlocked;

  const AchievementProgressStep({
    required this.name,
    required this.requirement,
    required this.status,
    required this.unlocked,
  });
}

class AchievementProgressTrack {
  final String title;
  final String subtitle;
  final List<AchievementProgressStep> steps;

  const AchievementProgressTrack({
    required this.title,
    required this.subtitle,
    required this.steps,
  });
}

AchievementProgressTrack buildAchievementProgress({
  required Conquista selected,
  required PlayerConquistas player,
}) {
  final category = _categoryLabel(selected.categoria);

  if (selected.id.startsWith('marco-')) {
    final stages = selected.etapas.isNotEmpty
        ? selected.etapas
        : _fallbackMilestoneStages(selected);
    final currentIndex = _currentMilestoneIndex(stages);
    return AchievementProgressTrack(
      title: 'Trilha de $category',
      subtitle: 'Sua evolução permanente nesta categoria',
      steps: [
        for (var index = 0; index < stages.length; index++)
          AchievementProgressStep(
            name: stages[index].nome,
            requirement: stages[index].descricao,
            status: index == currentIndex
                ? AchievementStepStatus.current
                : index < currentIndex
                    ? AchievementStepStatus.completed
                    : AchievementStepStatus.upcoming,
            unlocked: stages[index].desbloqueada,
          ),
      ],
    );
  }

  if (selected.id.startsWith('evento-')) {
    final achievements = player.eventos
        .where((item) => _sameCategory(item.categoria, selected.categoria))
        .toList();
    final items = achievements.isEmpty ? <Conquista>[selected] : achievements;
    return AchievementProgressTrack(
      title: 'Conquistas de $category',
      subtitle: 'Feitos especiais realizados durante as partidas',
      steps: items
          .map(
            (item) => AchievementProgressStep(
              name: item.nome,
              requirement: _asInstruction(item.descricao),
              status: item.id == selected.id && item.desbloqueada
                  ? AchievementStepStatus.current
                  : item.desbloqueada
                      ? AchievementStepStatus.completed
                      : AchievementStepStatus.upcoming,
              unlocked: item.desbloqueada,
            ),
          )
          .toList(),
    );
  }

  if (selected.id.startsWith('titulo-')) {
    final titles = player.titulos
        .where((item) => _sameCategory(item.categoria, selected.categoria))
        .toList()
      ..sort((a, b) => (a.ano ?? 0).compareTo(b.ano ?? 0));
    final items = titles.isEmpty ? <Conquista>[selected] : titles;
    return AchievementProgressTrack(
      title: 'Títulos de $category',
      subtitle: 'Pódios conquistados em temporadas encerradas',
      steps: [
        ...items.map(
          (item) => AchievementProgressStep(
            name: item.nome,
            requirement: item.descricao,
            status: item.id == selected.id
                ? AchievementStepStatus.current
                : AchievementStepStatus.completed,
            unlocked: true,
          ),
        ),
        const AchievementProgressStep(
          name: 'Próximo pódio',
          requirement:
              'Termine uma temporada entre os três primeiros desta categoria.',
          status: AchievementStepStatus.upcoming,
          unlocked: false,
        ),
      ],
    );
  }

  return AchievementProgressTrack(
    title: category.isEmpty ? selected.nome : 'Conquistas de $category',
    subtitle: 'Sua evolução nesta categoria',
    steps: [
      AchievementProgressStep(
        name: selected.nome,
        requirement: _asInstruction(selected.descricao),
        status: AchievementStepStatus.current,
        unlocked: selected.desbloqueada,
      ),
    ],
  );
}

int _currentMilestoneIndex(List<ConquistaEtapa> stages) {
  return stages.lastIndexWhere((stage) => stage.desbloqueada);
}

List<ConquistaEtapa> _fallbackMilestoneStages(Conquista selected) {
  final value = selected.valor ?? 0;
  final definitions = switch (selected.id) {
    'marco-presenca' => const [
        (1, 'Estreante', 'Participe de uma partida.'),
        (10, 'Da Casa', 'Participe de 10 partidas.'),
        (25, 'Assíduo', 'Participe de 25 partidas.'),
        (100, 'Centurião', 'Participe de 100 partidas.'),
        (200, 'Bicentenário', 'Participe de 200 partidas.'),
        (500, 'Lenda Viva', 'Participe de 500 partidas.'),
        (1000, 'Imortal', 'Participe de 1.000 partidas.'),
      ],
    'marco-gols' => const [
        (1, 'Primeiro Gol', 'Marque seu primeiro gol.'),
        (5, 'Pé Quente', 'Marque 5 gols.'),
        (10, 'Finalizador', 'Marque 10 gols.'),
        (25, 'Matador', 'Marque 25 gols.'),
        (50, 'Goleador', 'Marque 50 gols.'),
        (100, 'Artilheiro Nato', 'Marque 100 gols.'),
        (250, 'Lenda do Gol', 'Marque 250 gols.'),
        (500, 'Máquina de Gols', 'Marque 500 gols.'),
      ],
    'marco-assist' => const [
        (1, 'Primeira Assistência', 'Dê sua primeira assistência.'),
        (5, 'Bom de Passe', 'Dê 5 assistências.'),
        (10, 'Criador', 'Dê 10 assistências.'),
        (25, 'Garçom', 'Dê 25 assistências.'),
        (50, 'Maestro', 'Dê 50 assistências.'),
        (100, 'Cérebro', 'Dê 100 assistências.'),
        (250, 'Rei das Assistências', 'Dê 250 assistências.'),
      ],
    'marco-mvp' => const [
        (1, 'Craque da Partida', 'Seja eleito MVP pela primeira vez.'),
        (5, 'Decisivo', 'Seja eleito MVP 5 vezes.'),
        (15, 'Fora de Série', 'Seja eleito MVP 15 vezes.'),
        (30, 'Referência', 'Seja eleito MVP 30 vezes.'),
        (50, 'Ídolo', 'Seja eleito MVP 50 vezes.'),
      ],
    _ => <(int, String, String)>[
        (
          selected.meta ?? 1,
          selected.proximoNome ?? selected.nome,
          _asInstruction(selected.descricao),
        ),
      ],
  };

  return definitions
      .map(
        (stage) => ConquistaEtapa(
          nome: stage.$2,
          descricao: stage.$3,
          meta: stage.$1,
          desbloqueada: value >= stage.$1,
        ),
      )
      .toList();
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
    _ => '',
  };
}

bool _sameCategory(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

String _asInstruction(String description) {
  final value = description.trim();
  if (value.isEmpty) return 'Complete o desafio desta conquista.';
  final replacements = <String, String>{
    'Marcou ': 'Marque ',
    'Deu ': 'Dê ',
    'Completou ': 'Complete ',
    'Terminou ': 'Termine ',
  };
  for (final entry in replacements.entries) {
    if (value.startsWith(entry.key)) {
      final instruction = '${entry.value}${value.substring(entry.key.length)}';
      return instruction.endsWith('.') ? instruction : '$instruction.';
    }
  }
  return value.endsWith('.') ? value : '$value.';
}
