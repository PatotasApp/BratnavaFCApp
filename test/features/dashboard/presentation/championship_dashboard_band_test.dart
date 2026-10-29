import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/presentation/providers/championship_provider.dart';
import 'package:patotas_app/features/dashboard/presentation/pages/dashboard_page.dart';

/// O card do campeonato no dashboard muda por etapa, como o da partida.
/// Usa os campeonatos do mock: um em cada status (`championship-<valor>`).
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final dataSource = ChampionshipMockDataSource();

  Future<void> pump(WidgetTester tester, ChampionshipStatus status) async {
    final details =
        await dataSource.fetchById('g', 'championship-${status.value}');
    await tester.pumpWidget(ProviderScope(
      overrides: [championshipDataSourceProvider.overrideWithValue(dataSource)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChampionshipDashboardBand(
              details: details,
              groupId: 'g',
              // 1º jogador do mock: time Azul nas etapas com times.
              playerId: 'championship-${status.value}-player-1',
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('criado: avisa que a presença ainda não abriu', (tester) async {
    await pump(tester, ChampionshipStatus.created);

    expect(find.text('Presença ainda não aberta'), findsOneWidget);
    expect(find.text('Confirmar presença'), findsNothing);
    expect(find.text('Ver escalação'), findsNothing);
  });

  testWidgets('presença: contagem e botões de confirmar', (tester) async {
    await pump(tester, ChampionshipStatus.acceptation);

    expect(find.text('Confirmação de presença aberta'), findsOneWidget);
    expect(find.text('Presença confirmada'), findsOneWidget);
    expect(find.text('Não vou'), findsOneWidget);
    expect(find.text('9'), findsOneWidget); // 9 confirmados no mock
  });

  testWidgets('times: resumo, seu time e escalação', (tester) async {
    await pump(tester, ChampionshipStatus.teamDraw);

    expect(find.text('3 times definidos · aguardando início'), findsOneWidget);
    expect(find.text('Seu time: Azul'), findsOneWidget);
    expect(find.text('Ver escalação'), findsOneWidget);
    expect(find.text('Confirmar presença'), findsNothing);
  });

  testWidgets('em andamento: ao vivo com placar e jogo atual', (tester) async {
    await pump(tester, ChampionshipStatus.inProgress);

    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('2 × 1'), findsOneWidget);
    expect(find.text('Jogo 1: Azul × Verde'), findsOneWidget);
  });

  testWidgets('pós-jogo: votação do MVP', (tester) async {
    await pump(tester, ChampionshipStatus.postGame);

    expect(find.text('PÓS-JOGO'), findsOneWidget);
    expect(find.text('Jogos encerrados · votação do MVP'), findsOneWidget);
    expect(find.text('Votar no MVP'), findsOneWidget);
  });
}
