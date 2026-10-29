import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/presentation/pages/championship_detail_page.dart';
import 'package:patotas_app/features/championships/presentation/providers/championship_provider.dart';
import 'package:patotas_app/shared/presentation/widgets/prototype_ui.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Future<void> pump(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        championshipDataSourceProvider
            .overrideWithValue(ChampionshipMockDataSource()),
        championshipGroupIdProvider.overrideWithValue('g'),
        championshipIsAdminProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ChampionshipDetailPage(championshipId: id)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // O polling da tela é um Timer: desmonta no fim para ele ser cancelado.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('presença: botões de confirmar/recusar na linha, sem menu',
      (tester) async {
    await pump(tester, 'championship-1');

    expect(find.byIcon(Icons.more_vert), findsNothing);
    // No mock todos já confirmaram: só aparece o botão de recusar.
    expect(find.byTooltip('Recusar Luis'), findsOneWidget);
    expect(find.byTooltip('Confirmar Luis'), findsNothing);

    await tester.tap(find.byTooltip('Recusar Luis'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Confirmar Luis'), findsOneWidget);
    expect(find.byTooltip('Recusar Luis'), findsNothing);
    await unmount(tester);
  });

  testWidgets('visão geral só com o resumo por extenso', (tester) async {
    await pump(tester, 'championship-0');

    expect(find.textContaining('Conta como 1 partida ·'), findsOneWidget);
    expect(find.text('MVP do campeonato'), findsNothing);
    await unmount(tester);
  });

  testWidgets('botões da administração cabem no card', (tester) async {
    await pump(tester, 'championship-0');

    final button = find.widgetWithText(OutlinedButton, 'Cancelar campeonato');
    final card = find.ancestor(of: button, matching: find.byType(PrototypeCard));
    final buttonRect = tester.getRect(button);
    final cardRect = tester.getRect(card.first);
    expect(buttonRect.left, greaterThanOrEqualTo(cardRect.left));
    expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('convidado novo pelo nome, como na partida', (tester) async {
    await pump(tester, 'championship-1');

    await tester.tap(find.text('Adicionar convidado'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome do convidado'), 'Zé da Pelada');
    await tester.tap(find.text('Goleiro'));
    await tester.tap(find.byTooltip('4 estrelas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Zé da Pelada'), findsOneWidget);
    await unmount(tester);
  });
}
