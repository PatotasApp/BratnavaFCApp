import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/conquistas/domain/entities/conquista_models.dart';
import 'package:patotas_app/features/conquistas/presentation/widgets/conquistas_section.dart';

void main() {
  testWidgets('mostra o catálogo completo sem overflow em tela estreita', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final milestone = _achievement(
      id: 'marco-gols',
      name: 'Finalizador',
      category: 'Gols',
      unlocked: true,
      stages: List.generate(
        8,
        (index) => ConquistaEtapa(
          nome: 'Nível ${index + 1}',
          descricao: 'Complete o nível ${index + 1}.',
          meta: index + 1,
          desbloqueada: index < 3,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConquistasSection(
              player: _player(
                marcos: [milestone],
                eventos: [
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
                    unlocked: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feitos'), findsOneWidget);
    expect(find.text('Marcos'), findsOneWidget);
    expect(find.text('Títulos'), findsOneWidget);
    expect(find.textContaining('Seu nível: Hat-trick'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Poker'));
    await tester.pumpAndSettle();

    expect(find.text('Complete Poker.'), findsOneWidget);
    expect(find.text('A CONQUISTAR'), findsWidgets);
  });
}

Conquista _achievement({
  required String id,
  required String name,
  required String category,
  required bool unlocked,
  List<ConquistaEtapa> stages = const [],
}) =>
    Conquista(
      id: id,
      nome: name,
      descricao: 'Complete $name.',
      categoria: category,
      icone: '🏅',
      raridade: 'Comum',
      pctPatota: 0,
      desbloqueada: unlocked,
      count: unlocked ? 1 : 0,
      etapas: stages,
    );

PlayerConquistas _player({
  required List<Conquista> marcos,
  required List<Conquista> eventos,
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
