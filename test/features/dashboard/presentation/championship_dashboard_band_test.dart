import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/championships/data/datasources/championship_mock_datasource.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_enums.dart';
import 'package:patotas_app/features/championships/domain/entities/championship_models.dart';
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
      overrides: [
        championshipDataSourceProvider.overrideWithValue(dataSource),
        championshipIsAdminProvider.overrideWithValue(false),
      ],
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

    expect(find.text('9 confirmados · presença aberta'), findsOneWidget);
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

    // "Ver escalação" abre um campo por time (só leitura), com os nomes.
    await tester.tap(find.text('Ver escalação'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-field-championship-2-team-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-field-championship-2-team-3')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('em andamento: ao vivo com placar e jogo atual', (tester) async {
    await pump(tester, ChampionshipStatus.inProgress);

    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('2 × 1'), findsOneWidget);
    expect(find.text('Jogo 1 ao vivo: Azul 2 × 1 Verde'), findsOneWidget);
  });

  testWidgets('pós-jogo: votação do MVP', (tester) async {
    await pump(tester, ChampionshipStatus.postGame);

    expect(find.text('PÓS-JOGO'), findsOneWidget);
    expect(find.text('Jogos encerrados · votação do MVP'), findsOneWidget);
    expect(find.text('Votar no MVP'), findsOneWidget);
  });

  group('jogos sem partida em andamento usam o next-game', () {
    Future<void> pumpBetweenGames(
      WidgetTester tester,
      Future<NextGameSuggestion?> Function() next, {
      bool admin = false,
    }) async {
      final source = _NextGameDataSource(next);
      await source.endGame('g', 'championship-3', 'championship-3-game-1');
      final details = await source.fetchById('g', 'championship-3');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          championshipDataSourceProvider.overrideWithValue(source),
          championshipIsAdminProvider.overrideWithValue(admin),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChampionshipDashboardBand(
                details: details,
                groupId: 'g',
                playerId: 'championship-3-player-1',
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('com sugestão: mostra o próximo confronto', (tester) async {
      await pumpBetweenGames(
        tester,
        () async => const NextGameSuggestion(
          teamAId: 'championship-3-team-1',
          teamBId: 'championship-3-team-3',
          reason: '',
          waitingTeamIds: [],
        ),
      );
      await tester.pump();
      expect(find.text('Próximo: Azul × Laranja'), findsOneWidget);
      expect(find.textContaining('em breve'), findsNothing);
    });

    testWidgets('sem sugestão: todos os jogos jogados', (tester) async {
      await pumpBetweenGames(tester, () async => null, admin: true);
      await tester.pump();
      expect(
        find.text('Todos os jogos foram jogados · aguardando encerramento · '
            'encerre o campeonato'),
        findsOneWidget,
      );
    });

    testWidgets('carregando: só a quantidade de jogos', (tester) async {
      final pending = Completer<NextGameSuggestion?>();
      await pumpBetweenGames(tester, () => pending.future);
      await tester.pump();
      expect(find.text('1 jogos'), findsOneWidget);
      pending.complete(null);
      await tester.pump();
      await tester.pump();
      expect(
          find.textContaining('Todos os jogos foram jogados'), findsOneWidget);
    });
  });
}

class _NextGameDataSource extends ChampionshipMockDataSource {
  _NextGameDataSource(this._next);
  final Future<NextGameSuggestion?> Function() _next;

  @override
  Future<NextGameSuggestion?> fetchNextGame(String groupId, String id) =>
      _next();
}
