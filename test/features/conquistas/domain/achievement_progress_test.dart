import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/conquistas/domain/achievement_progress.dart';
import 'package:patotas_app/features/conquistas/domain/entities/conquista_models.dart';

void main() {
  group('buildAchievementProgress', () {
    test('monta toda a trilha do marco sem expor o valor atual', () {
      final selected = _achievement(
        id: 'marco-gols',
        name: 'Finalizador',
        category: 'Gols',
        unlocked: true,
        value: 12,
      );
      final track = buildAchievementProgress(
        selected: selected,
        player: _player(marcos: [selected]),
      );

      expect(track.steps.map((step) => step.name), contains('Primeiro Gol'));
      expect(track.steps.map((step) => step.name), contains('Máquina de Gols'));
      expect(
        track.steps.singleWhere((step) => step.name == 'Finalizador').status,
        AchievementStepStatus.current,
      );
      expect(track.steps.map((step) => step.requirement).join(' '),
          isNot(contains('12')));
    });

    test('agrupa todos os feitos da mesma categoria', () {
      final hatTrick = _achievement(
        id: 'evento-hat-trick',
        name: 'Hat-trick',
        category: 'Ataque',
        unlocked: true,
        description: 'Marcou 3 gols em uma partida',
      );
      final poker = _achievement(
        id: 'evento-poker',
        name: 'Poker',
        category: 'Ataque',
        unlocked: false,
        description: 'Marcou 4 gols em uma partida',
      );
      final unrelated = _achievement(
        id: 'evento-invicto',
        name: 'Invicto',
        category: 'Vitórias',
        unlocked: false,
      );

      final track = buildAchievementProgress(
        selected: hatTrick,
        player: _player(eventos: [hatTrick, poker, unrelated]),
      );

      expect(track.steps.map((step) => step.name), ['Hat-trick', 'Poker']);
      expect(track.steps.last.status, AchievementStepStatus.upcoming);
      expect(track.steps.last.requirement, 'Marque 4 gols em uma partida.');
    });
  });
}

Conquista _achievement({
  required String id,
  required String name,
  required String category,
  required bool unlocked,
  String description = '',
  int? value,
}) =>
    Conquista(
      id: id,
      nome: name,
      descricao: description,
      categoria: category,
      icone: '',
      raridade: 'Comum',
      pctPatota: 0,
      desbloqueada: unlocked,
      valor: value,
    );

PlayerConquistas _player({
  List<Conquista> marcos = const [],
  List<Conquista> eventos = const [],
}) =>
    PlayerConquistas(
      playerId: 'player',
      userId: 'user',
      playerName: 'Jogador',
      isGoalkeeper: false,
      marcos: marcos,
      eventos: eventos,
      titulos: const [],
      temporada: const [],
    );
