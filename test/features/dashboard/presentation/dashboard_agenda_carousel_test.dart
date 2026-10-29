import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/dashboard/presentation/pages/dashboard_page.dart';

void main() {
  test('partidas e campeonatos ficam em ordem de data, o mais próximo primeiro',
      () {
    final order = agendaByDate<String>([
      (at: DateTime(2026, 11, 3, 20), card: 'pelada de terça'),
      (at: DateTime(2026, 11, 1, 9), card: 'campeonato de domingo'),
      (at: DateTime(2026, 11, 2, 20), card: 'pelada de segunda'),
    ]);
    expect(order,
        ['campeonato de domingo', 'pelada de segunda', 'pelada de terça']);
  });

  testWidgets('carrossel mostra um card por vez, com setas, deslize e posição',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: DashboardAgendaCarousel(children: [
          SizedBox(height: 120, child: Text('Campeonato')),
          SizedBox(height: 80, child: Text('Pelada 1')),
          SizedBox(height: 80, child: Text('Pelada 2')),
        ]),
      ),
    ));

    expect(find.text('Campeonato'), findsOneWidget);
    expect(find.text('Pelada 1'), findsNothing);
    expect(find.text('1 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Pelada 1'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);

    await tester.fling(find.text('Pelada 1'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Pelada 2'), findsOneWidget);
    expect(find.text('3 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Pelada 1'), findsOneWidget);
  });
}
