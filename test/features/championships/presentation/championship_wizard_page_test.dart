import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/presentation/pages/championship_wizard_page.dart';
import 'package:patotas_app/features/championships/presentation/providers/championship_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('digitar nos números do formato não tira o foco do campo',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        championshipDataSourceProvider
            .overrideWithValue(ChampionshipMockDataSource()),
        championshipGroupIdProvider.overrideWithValue('g'),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ChampionshipWizardPage()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar').first);
    await tester.pumpAndSettle();
    expect(find.text('Comece por um preset'), findsNothing);
    expect(find.text('Em branco se o jogo não acaba por gols.'), findsOneWidget);

    final gols = find.widgetWithText(TextFormField, 'Gols');
    await tester.tap(gols);
    await tester.pump();
    await tester.enterText(gols, '3');
    await tester.pump();
    await tester.enterText(gols, '34');
    await tester.pump();

    final field = tester.widget<EditableText>(
      find.descendant(of: gols, matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.controller.text, '34');
  });
}
