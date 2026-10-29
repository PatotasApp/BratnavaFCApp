import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/presentation/widgets/championship_swap_teams.dart';
import 'package:patotas_app/shared/presentation/widgets/group_icon_renderer.dart';

void main() {
  group('swapInOption', () {
    final teams = [
      (playerIds: ['a1', 'a2', 'a3'], goalkeeperPlayerId: 'a1'),
      (playerIds: ['b1', 'b2', 'b3'], goalkeeperPlayerId: 'b1'),
    ];

    test('troca os dois e mantém o tamanho dos times', () {
      final result = swapInOption(teams, 'a2', 'b3');
      expect(result[0].playerIds, ['a1', 'b3', 'a3']);
      expect(result[1].playerIds, ['b1', 'b2', 'a2']);
      expect(result[0].goalkeeperPlayerId, 'a1');
      expect(result[1].goalkeeperPlayerId, 'b1');
    });

    test('goleiro vai junto e vira o único goleiro do novo time', () {
      final result = swapInOption(teams, 'a1', 'b2');
      expect(result[1].goalkeeperPlayerId, 'a1');
      expect(result[0].goalkeeperPlayerId, isNull);
    });

    test('dois goleiros trocam de lugar', () {
      final result = swapInOption(teams, 'a1', 'b1');
      expect(result[0].goalkeeperPlayerId, 'b1');
      expect(result[1].goalkeeperPlayerId, 'a1');
    });

    test('do mesmo time não muda nada', () {
      expect(swapInOption(teams, 'a1', 'a2'), same(teams));
    });
  });

  testWidgets(
      'seleção mostra a faixa, esmaece o próprio time e marca os outros com ⇄',
      (tester) async {
    final swaps = <(String, String)>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SwappableTeams(
            teams: [
              SwapTeam(
                  id: 'A',
                  name: 'Azul',
                  colorHex: '#0000FF',
                  playerIds: const ['a1', 'a2'],
                  isGoalkeeper: (id) => id == 'a1'),
              SwapTeam(
                  id: 'B',
                  name: 'Verde',
                  colorHex: '#00FF00',
                  playerIds: const ['b1', 'b2'],
                  isGoalkeeper: (id) => id == 'b1'),
            ],
            playerName: (id) => const {
              'a1': 'Ana Lima',
              'a2': 'Bia Souza',
              'b1': 'Caio Reis',
              'b2': 'Davi Melo',
            }[id]!,
            icons: GroupIcons.defaults,
            enabled: true,
            onSwap: (first, second) async {
              swaps.add((first, second));
              return true;
            },
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('field-pin-a2')));
    await tester.pumpAndSettle();
    expect(
        find.text('Toque num jogador de outro time para trocar com Bia Souza'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('swap-target-b1')), findsOneWidget);
    expect(find.byKey(const ValueKey('swap-target-a1')), findsNothing);

    // Mesmo time: só muda a seleção.
    await tester.tap(find.byKey(const ValueKey('field-pin-a1')));
    await tester.pumpAndSettle();
    expect(swaps, isEmpty);
    expect(
        find.text('Toque num jogador de outro time para trocar com Ana Lima'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('field-pin-b2')));
    await tester.pumpAndSettle();
    expect(swaps, [('a1', 'b2')]);
    expect(find.text('Ana Lima ⇄ Davi Melo'), findsOneWidget);
    expect(find.byKey(const ValueKey('swap-banner')), findsNothing);

    // Cancelar desfaz a seleção.
    await tester.tap(find.byKey(const ValueKey('field-pin-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swap-banner')), findsNothing);
    expect(find.byKey(const ValueKey('swap-target-a1')), findsNothing);
  });
}
