import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/presentation/widgets/match_player_role_toggle.dart';
import 'package:patotas_app/shared/presentation/widgets/group_icon_renderer.dart';

void main() {
  Widget subject({
    required bool isGoalkeeper,
    bool busy = false,
    VoidCallback? onPressed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MatchPlayerRoleToggle(
            playerName: 'Artur',
            isGoalkeeper: isGoalkeeper,
            icons: GroupIcons.defaults,
            busy: busy,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('mostra um seletor compacto entre goleiro e jogador',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(subject(isGoalkeeper: false));

    expect(find.byKey(const Key('role-goalkeeper-icon')), findsOneWidget);
    expect(find.byKey(const Key('match-player-role-switch')), findsOneWidget);
    expect(find.byKey(const Key('role-field-player-icon')), findsOneWidget);
    expect(find.text('Linha'), findsNothing);
    expect(find.text('Goleiro'), findsNothing);
    final size = tester.getSize(
      find.byKey(const Key('match-player-role-toggle')),
    );
    expect(size.width, lessThan(90));
    expect(size.height, lessThan(30));
    expect(
      find.bySemanticsLabel(RegExp('Artur: Linha.*mudar para goleiro')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('aciona a troca quando o botão é tocado', (tester) async {
    var taps = 0;
    await tester.pumpWidget(subject(
      isGoalkeeper: true,
      onPressed: () => taps++,
    ));

    await tester.tap(find.byKey(const Key('match-player-role-toggle')));

    expect(taps, 1);
  });

  testWidgets('bloqueia novos toques enquanto salva', (tester) async {
    var taps = 0;
    await tester.pumpWidget(subject(
      isGoalkeeper: false,
      busy: true,
      onPressed: () => taps++,
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('match-player-role-toggle')));

    expect(taps, 0);
  });
}
