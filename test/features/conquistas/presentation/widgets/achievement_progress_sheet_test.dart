import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/conquistas/domain/entities/conquista_models.dart';
import 'package:patotas_app/features/conquistas/presentation/widgets/achievement_progress_sheet.dart';

void main() {
  testWidgets('mostra passado, etapa atual e próximas conquistas sem overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const selected = Conquista(
      id: 'marco-gols',
      nome: 'Finalizador',
      descricao: 'Gols',
      categoria: 'Gols',
      icone: '⚽',
      raridade: 'Rara',
      pctPatota: 0,
      desbloqueada: true,
      valor: 12,
    );
    const player = PlayerConquistas(
      playerId: 'player',
      userId: 'user',
      playerName: 'Jogador',
      isGoalkeeper: false,
      marcos: [selected],
      eventos: [],
      titulos: [],
      temporada: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAchievementProgressSheet(
                  context,
                  selected: selected,
                  player: player,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Trilha de Gols'), findsOneWidget);
    expect(find.text('Conquista atual.'), findsOneWidget);
    expect(find.textContaining('Para conquistar:'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
