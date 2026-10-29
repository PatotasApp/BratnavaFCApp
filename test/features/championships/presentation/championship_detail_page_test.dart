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

  Future<void> pump(WidgetTester tester, String id,
      {ChampionshipMockDataSource? dataSource}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        championshipDataSourceProvider
            .overrideWithValue(dataSource ?? ChampionshipMockDataSource()),
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

    expect(
        find.textContaining('Conta como uma única partida ·'), findsOneWidget);
    expect(find.text('MVP do campeonato'), findsNothing);
    await unmount(tester);
  });

  testWidgets('botões da administração cabem no card', (tester) async {
    await pump(tester, 'championship-0');

    final button = find.widgetWithText(OutlinedButton, 'Cancelar campeonato');
    final card =
        find.ancestor(of: button, matching: find.byType(PrototypeCard));
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

  testWidgets('sorteio em abas como a partida, sem modal, e depois Times',
      (tester) async {
    final dataSource = ChampionshipMockDataSource();
    await dataSource.stepBack('g', 'championship-2'); // Times → Sorteio
    await pump(tester, 'championship-2', dataSource: dataSource);

    expect(find.text('Sorteio'), findsOneWidget);
    expect(find.text('Goleiros'), findsOneWidget);
    for (final label in [
      'Manual',
      'Aleatório',
      'Algoritmo',
      'Por vitórias',
      'Por perfil'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('draw-team-count')), findsOneWidget);

    await tester.tap(find.text('Sortear times'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Opção 1 de 1'), findsOneWidget);

    // Troca 2 jogadores de times diferentes antes de usar a opção.
    final firstTeam =
        find.byKey(const ValueKey('field-pin-championship-2-player-1'));
    final otherTeam =
        find.byKey(const ValueKey('field-pin-championship-2-player-4'));
    await tester.tap(firstTeam);
    await tester.pumpAndSettle();
    await tester.tap(otherTeam);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('option-adjusted')), findsOneWidget);
    expect(find.textContaining('Diferença de força'), findsNothing);

    await tester.tap(find.text('Usar esta opção'));
    await tester.pumpAndSettle();
    expect(find.text('Times'), findsWidgets);
    expect(find.text('Iniciar campeonato'), findsOneWidget);
    expect(find.text('Voltar para o sorteio'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('jogo em andamento: só o confronto, botões grandes e cronômetro',
      (tester) async {
    await pump(tester, 'championship-3');

    expect(find.text('Presenças'), findsNothing);
    expect(find.text('Jogo'), findsOneWidget);
    expect(find.text('Classificação'), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-gol-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-gol-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn-jogada')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('btn-gol-a'))).height,
        greaterThanOrEqualTo(90));
    expect(find.byTooltip('Registrar gol'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clock-play')));
    await tester.pump();
    expect(find.byKey(const ValueKey('clock-pause')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clock-pause')));
    await tester.pump();
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clock-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Zerar o cronômetro?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Zerar'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar'), findsOneWidget);

    // Botão de gol soma no placar, como na partida.
    await tester.tap(find.byKey(const ValueKey('btn-gol-a')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('3  ×  1'), findsOneWidget);

    await tester.tap(find.text('Classificação'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('btn-gol-a')), findsNothing);
    // Depois do início os times ficam só leitura, em abas com o campo.
    expect(find.text('Sortear cores'), findsNothing);
    expect(find.byTooltip('Editar nome e cor'), findsNothing);
    expect(find.textContaining('Toque num jogador'), findsNothing);
    expect(find.byKey(const ValueKey('team-tab-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-field-championship-3-team-1')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('team-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-field-championship-3-team-2')),
        findsOneWidget);
    await unmount(tester);
  });

  testWidgets('finalizado: times em abas na ordem da colocação',
      (tester) async {
    await pump(tester, 'championship-5');

    expect(find.text('Presenças'), findsNothing);
    expect(find.text('1º Azul'), findsOneWidget);
    expect(find.text('2º Verde'), findsOneWidget);
    expect(find.text('1º lugar · Azul'), findsOneWidget);
    await tester.tap(find.text('2º Verde'));
    await tester.pumpAndSettle();
    expect(find.text('2º lugar · Verde'), findsOneWidget);
    await unmount(tester);
  });
}
