import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/conquistas/domain/entities/conquista_models.dart';
import 'package:patotas_app/features/conquistas/presentation/widgets/conquistas_section.dart';

void main() {
  group('topConquistas', () {
    test('mantem somente o maior nivel de uma progressao cumulativa', () {
      final highlights = topConquistas(
        _player(eventos: [
          _event('evento-hat-trick', 'Hat-trick', 'Ataque', 'Lendária'),
          _event('evento-poker', 'Poker', 'Ataque', 'Épica'),
          _event(
            'evento-cinco-estrelas',
            'Cinco estrelas',
            'Ataque',
            'Rara',
          ),
          _event('evento-garcom-gala', 'Garçom de gala', 'Criação', 'Rara'),
          _event('evento-super-invicto', 'Super invicto', 'Vitórias', 'Rara'),
          _event('evento-fortaleza', 'Fortaleza', 'Defesa', 'Rara'),
          _event('evento-capitao', 'Capitão', 'Liderança', 'Comum'),
        ]),
        5,
      );

      expect(
          highlights.map((item) => item.id), contains('evento-cinco-estrelas'));
      expect(highlights.map((item) => item.id),
          isNot(contains('evento-hat-trick')));
      expect(
          highlights.map((item) => item.id), isNot(contains('evento-poker')));
      expect(highlights.map((item) => item.categoria).toSet().length, 5);
    });

    test('prioriza dificuldade antes da raridade dentro da progressao', () {
      final highlights = topConquistas(
        _player(eventos: [
          _event('evento-hat-trick', 'Hat-trick', 'Ataque', 'Lendária'),
          _event(
            'evento-cinco-estrelas',
            'Cinco estrelas',
            'Ataque',
            'Comum',
          ),
        ]),
        5,
      );

      expect(highlights, hasLength(1));
      expect(highlights.single.id, 'evento-cinco-estrelas');
    });
  });
}

Conquista _event(String id, String name, String category, String rarity) =>
    Conquista(
      id: id,
      nome: name,
      descricao: '',
      categoria: category,
      icone: '',
      raridade: rarity,
      pctPatota: 0,
      desbloqueada: true,
      count: 1,
    );

PlayerConquistas _player({required List<Conquista> eventos}) =>
    PlayerConquistas(
      playerId: 'player',
      userId: 'user',
      playerName: 'Jogador',
      isGoalkeeper: false,
      marcos: const [],
      eventos: eventos,
      titulos: const [],
      temporada: const [],
    );
