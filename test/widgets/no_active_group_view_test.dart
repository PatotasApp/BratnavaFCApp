import 'package:patotas_app/shared/presentation/widgets/no_active_group_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the standard active-group empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoActiveGroupView(
            message: 'Selecione uma patota para ver as partidas.',
          ),
        ),
      ),
    );

    expect(find.text('Nenhuma patota ativa'), findsOneWidget);
    expect(
      find.text('Selecione uma patota para ver as partidas.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a compact viewport without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NoActiveGroupView()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
