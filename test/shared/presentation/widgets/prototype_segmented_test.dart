import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/shared/presentation/widgets/prototype_ui.dart';

void main() {
  testWidgets('exibe rótulo customizado e mantém o valor original no clique',
      (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrototypeSegmented(
            items: const ['Aceitos', 'Pendentes'],
            value: 'Aceitos',
            labelBuilder: (item) => '$item · ${item == 'Aceitos' ? 7 : 2}',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Aceitos · 7'), findsOneWidget);
    expect(find.text('Pendentes · 2'), findsOneWidget);

    await tester.tap(find.text('Pendentes · 2'));

    expect(selected, 'Pendentes');
  });
}
