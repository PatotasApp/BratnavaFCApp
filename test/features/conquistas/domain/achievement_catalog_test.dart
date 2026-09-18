import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/conquistas/domain/achievement_catalog.dart';
import 'package:patotas_app/features/conquistas/domain/achievement_progress.dart';
import 'package:patotas_app/features/conquistas/domain/entities/conquista_models.dart';

void main() {
  group('buildAchievementCatalog', () {
    test('exibe todos os feitos e destaca somente o maior nível alcançado', () {
      final catalog = buildAchievementCatalog(
        _player(eventos: [
          _achievement(
            id: 'evento-hat-trick',
            name: 'Hat-trick',
            category: 'Ataque',
            unlocked: true,
          ),
          _achievement(
            id: 'evento-poker',
            name: 'Poker',
            category: 'Ataque',
            unlocked: true,
          ),
          _achievement(
            id: 'evento-cinco-estrelas',
            name: 'Cinco estrelas',
            category: 'Ataque',
            unlocked: false,
          ),
        ]),
      );

      final attack = catalog.singleWhere((item) => item.id == 'feito-Ataque');
      expect(attack.stages, hasLength(3));
      expect(
        attack.stages
            .singleWhere(
              (stage) => stage.status == AchievementStepStatus.current,
            )
            .name,
        'Poker',
      );
      expect(attack.guidance, contains('Cinco estrelas'));
    });

    test('exibe toda a trilha do marco e explica o próximo nível', () {
      final milestone = _achievement(
        id: 'marco-gols',
        name: 'Finalizador',
        category: 'Gols',
        unlocked: true,
        stages: const [
          ConquistaEtapa(
            nome: 'Primeiro gol',
            descricao: 'Marque um gol.',
            meta: 1,
            desbloqueada: true,
          ),
          ConquistaEtapa(
            nome: 'Finalizador',
            descricao: 'Marque 10 gols.',
            meta: 10,
            desbloqueada: true,
          ),
          ConquistaEtapa(
            nome: 'Matador',
            descricao: 'Marque 25 gols.',
            meta: 25,
            desbloqueada: false,
          ),
        ],
      );
      final catalog = buildAchievementCatalog(_player(marcos: [milestone]));
      final goals = catalog.singleWhere((item) => item.id == 'marco-gols');

      expect(goals.stages, hasLength(3));
      expect(goals.guidance, contains('Marque 10 gols.'));
      expect(goals.guidance, contains('Próximo: Matador — Marque 25 gols.'));
    });

    test('mostra todos os tipos de título e o melhor pódio do jogador', () {
      final catalog = buildAchievementCatalog(
        _player(titulos: [
          _achievement(
            id: 'titulo-gols-2025',
            name: 'Artilheiro da Temporada 2025',
            category: 'Gols',
            unlocked: true,
            position: 2,
          ),
        ]),
      );
      final titles = catalog
          .where((item) => item.kind == AchievementCatalogKind.title)
          .toList();
      final scorer = titles.singleWhere((item) => item.title == 'Artilheiro');

      expect(titles, hasLength(5));
      expect(
        scorer.stages
            .singleWhere(
              (stage) => stage.status == AchievementStepStatus.current,
            )
            .name,
        '2º lugar',
      );
      expect(scorer.guidance, contains('1º lugar'));
    });
  });
}

Conquista _achievement({
  required String id,
  required String name,
  required String category,
  required bool unlocked,
  List<ConquistaEtapa> stages = const [],
  int? position,
}) =>
    Conquista(
      id: id,
      nome: name,
      descricao: '$name descrição',
      categoria: category,
      icone: '🏅',
      raridade: 'Comum',
      pctPatota: 0,
      desbloqueada: unlocked,
      count: unlocked ? 1 : 0,
      posicao: position,
      etapas: stages,
    );

PlayerConquistas _player({
  List<Conquista> eventos = const [],
  List<Conquista> marcos = const [],
  List<Conquista> titulos = const [],
}) =>
    PlayerConquistas(
      playerId: 'player',
      userId: 'user',
      playerName: 'Jogador',
      isGoalkeeper: false,
      marcos: marcos,
      eventos: eventos,
      titulos: titulos,
      temporada: const [],
    );
