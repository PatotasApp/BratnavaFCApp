import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/presentation/widgets/match_add_guest_sheet.dart';
import 'package:patotas_app/shared/presentation/widgets/group_icon_renderer.dart';

void main() {
  Widget subject({required AddMatchGuestCallback onSubmit}) {
    return MaterialApp(
      home: Scaffold(
        body: MatchAddGuestSheet(
          icons: GroupIcons.defaults,
          onSubmit: onSubmit,
        ),
      ),
    );
  }

  testWidgets('exige o nome do convidado', (tester) async {
    await tester.pumpWidget(subject(onSubmit: (_, __, ___) async => true));

    await tester.tap(find.byKey(const Key('submit-match-guest-button')));
    await tester.pump();

    expect(find.text('Informe o nome do convidado.'), findsOneWidget);
  });

  testWidgets('envia nome, função e nível escolhidos', (tester) async {
    String? name;
    bool? isGoalkeeper;
    int? rating;
    await tester.pumpWidget(subject(
      onSubmit: (submittedName, submittedGoalkeeper, submittedRating) async {
        name = submittedName;
        isGoalkeeper = submittedGoalkeeper;
        rating = submittedRating;
        return false;
      },
    ));

    await tester.enterText(
      find.byKey(const Key('match-guest-name-field')),
      '  Bruno Carvalho  ',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.byTooltip('4 estrelas'));
    await tester.tap(find.byKey(const Key('submit-match-guest-button')));
    await tester.pump();

    expect(name, 'Bruno Carvalho');
    expect(isGoalkeeper, isTrue);
    expect(rating, 4);
    expect(
        find.text('Não foi possível adicionar o convidado.'), findsOneWidget);
  });
}
