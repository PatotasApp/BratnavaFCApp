import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/presentation/widgets/championship_team_field.dart';
import 'package:patotas_app/shared/presentation/widgets/group_icon_renderer.dart';

void main() {
  const players = [
    FieldPlayerInfo(id: 'p1', name: 'Marcos Antônio', isGoalkeeper: false),
    FieldPlayerInfo(id: 'p2', name: 'Pedro Roweder', isGoalkeeper: true),
    FieldPlayerInfo(id: 'p3', name: 'Andrei Salvador', isGoalkeeper: false),
    FieldPlayerInfo(
        id: 'p4', name: 'Bartolomeu Cristóvão', isGoalkeeper: false),
  ];

  test('goleiro no gol e a linha nas posições do site por quantidade', () {
    final positions = fieldPositions(players);
    expect(positions[1], const Offset(.50, .86));
    expect(positions[0], const Offset(.50, .30));
    expect(positions[2], const Offset(.22, .54));
    expect(positions[3], const Offset(.78, .54));
  });

  test('iniciais e primeiro nome', () {
    expect(fieldInitials('Marcos Antônio'), 'MA');
    expect(fieldInitials('Zé'), 'ZÉ');
    expect(fieldFirstName('Pedro Roweder'), 'Pedro');
  });

  // O tema é montado dentro do teste: o google_fonts precisa do binding.
  for (final (label, theme) in [
    ('claro', () => AppTheme.light),
    ('escuro', () => AppTheme.dark),
  ]) {
    testWidgets('campo no tema $label, em largura de celular, com os nomes',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: theme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ChampionshipTeamField(
              teamName: 'Azul',
              teamColorHex: '#2563EB',
              players: players,
              icons: GroupIcons.defaults,
            ),
          ),
        ),
      ));

      expect(find.bySemanticsLabel(RegExp('^Campo do Azul')), findsOneWidget);
      expect(find.text('Azul'), findsOneWidget);
      // Nome sempre embaixo do círculo (primeiro nome).
      for (final name in ['Marcos', 'Pedro', 'Andrei', 'Bartolomeu']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('MA'), findsOneWidget);
      // Goleiro com o ícone de goleiro, sem iniciais.
      expect(find.text('PR'), findsNothing);
      expect(find.text(GroupIcons.defaults.goalkeeper), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
