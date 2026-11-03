import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:patotas_app/features/auth/presentation/providers/account_store.dart';
import 'package:patotas_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:patotas_app/features/shell/domain/shell_navigation_policy.dart';
import 'package:patotas_app/features/team_builder/domain/entities/team_builder_models.dart';
import 'package:patotas_app/features/team_builder/domain/team_builder_format.dart';
import 'package:patotas_app/features/team_builder/presentation/pages/team_builder_page.dart';
import 'package:patotas_app/features/team_builder/presentation/widgets/team_builder_pitch.dart';
import 'package:patotas_app/features/team_builder/presentation/widgets/team_builder_share_card.dart';
import 'package:patotas_app/features/team_builder/presentation/widgets/team_builder_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const caio = TeamBuilderPlayer(
    id: 'p1',
    name: 'Caio Silva',
    shortName: 'Caio',
    isGoalkeeper: false,
    games: 30);
const pagel =
    TeamBuilderPlayer(id: 'p2', name: 'Pagel', isGoalkeeper: false, games: 28);
const luis =
    TeamBuilderPlayer(id: 'p3', name: 'Luis', isGoalkeeper: true, games: 35);
const marlon =
    TeamBuilderPlayer(id: 'p4', name: 'Marlon', isGoalkeeper: true, games: 10);

final statsJson = <String, dynamic>{
  'data': {
    'neverPlayedTogether': false,
    'totalMatches': 9,
    'wins': 5,
    'draws': 2,
    'losses': 2,
    'goalsScored': 98,
    'goalsConceded': 81,
    'goalDifference': 17,
    'goalsPerMatch': 10.89,
    'pointsPct': 63,
    'averageIndividualPointsPct': 54,
    'oppositeTeamsMatches': 12,
    'biggestWin': {
      'matchId': 'm1',
      'playedAt': '2026-04-15T23:00:00+00:00',
      'goalsFor': 15,
      'goalsAgainst': 8,
      'result': 1
    },
    'worstLoss': null,
    'lastMatch': {
      'matchId': 'm9',
      'playedAt': '2026-10-20T23:00:00+00:00',
      'goalsFor': 11,
      'goalsAgainst': 13,
      'result': -1,
      'isChampionship': true
    },
    'currentStreak': {'result': -1, 'count': 2},
    'nemesis': {
      'playerId': 'x',
      'name': 'Matheus Souza',
      'shortName': 'Matheus',
      'wins': 1,
      'draws': 0,
      'losses': 3
    },
    'favoriteVictim': null,
    'curiosities': ['Juntos fazem **63%** de aproveitamento.'],
    'assistPairs': [
      {
        'assisterId': 'p2',
        'assisterName': 'Pagel',
        'assisterShortName': 'Pagel',
        'scorerId': 'p1',
        'scorerName': 'Caio Silva',
        'scorerShortName': 'Caio',
        'count': 3
      },
    ],
    'playerBreakdown': [
      {
        'id': 'p1',
        'name': 'Caio Silva',
        'shortName': 'Caio',
        'isGoalkeeper': false,
        'goals': 14,
        'assists': 4,
        'mvps': 2,
        'overallGames': 38,
        'overallPointsPct': 54
      },
      {
        'id': 'p2',
        'name': 'Pagel',
        'shortName': 'Pagel',
        'isGoalkeeper': false,
        'goals': 6,
        'assists': 9,
        'mvps': 1,
        'overallGames': 40,
        'overallPointsPct': 49
      },
      {
        'id': 'p3',
        'name': 'Luis',
        'shortName': 'Luis',
        'isGoalkeeper': true,
        'goals': 0,
        'assists': 1,
        'mvps': 0,
        'overallGames': 41,
        'overallPointsPct': 58
      },
    ],
    'matches': [],
  },
};

Widget _app(Widget child, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? AppTheme.dark, home: Scaffold(body: child));

void main() {
  group('modelos', () {
    test('lê os dados novos da API (juntos, média deles, adversários)', () {
      final s = TeamBuilderStats.fromJson(statsJson);
      expect(s.neverPlayedTogether, isFalse);
      expect(s.pointsPct, 63);
      expect(s.averageIndividualPointsPct, 54);
      expect(s.oppositeTeamsMatches, 12);
      expect(s.goalsPerMatch, closeTo(10.89, .001));
      expect(s.biggestWin!.goalsFor, 15);
      expect(s.worstLoss, isNull);
      expect(s.lastMatch!.isChampionship, isTrue);
      expect(s.currentStreak!.count, 2);
      expect(s.nemesis!.shortName, 'Matheus');
      expect(s.assistPairs.single.scorerName, 'Caio',
          reason: 'usa o nome curto');
      expect(s.breakdownOf('p2')!.overallPointsPct, 49);
    });

    test('filtro vira query da API', () {
      expect(
          const TeamBuilderPeriod.season(2026)
              .toFilter(includeChampionship: true)
              .toJson(),
          {'season': 2026, 'includeChampionship': true});
      expect(
          TeamBuilderPeriod.since(DateTime(2026, 8, 6))
              .toFilter(includeChampionship: false)
              .toJson(),
          {'from': '2026-08-06', 'includeChampionship': false});
      expect(
          const TeamBuilderPeriod.last(10)
              .toFilter(includeChampionship: true)
              .toJson(),
          {'lastMatches': 10, 'includeChampionship': true});
      expect(
          TeamBuilderPeriod.since(DateTime(2026, 8, 16)).label, 'Desde 16/08');
    });
  });

  group('formatação', () {
    test('sequência, nomes, veredito e destaques', () {
      expect(
          streakText(const Streak(result: 1, count: 3)), '3 vitórias seguidas');
      expect(streakText(const Streak(result: 0, count: 1)), '1 empate seguido');
      expect(streakText(const Streak(result: -1, count: 2)),
          '2 derrotas seguidas');
      expect(joinNames(['Caio', 'Pagel', 'Mozart']), 'Caio, Pagel e Mozart');
      expect(verdictOf(63), 'Boa química');
      expect(oneDecimal(10.89), '10,9');
      expect(boldParts('a **b** c').map((p) => (p.text, p.bold)),
          [('a ', false), ('b', true), (' c', false)]);
      expect(initialsOf('Pedro Roweder'), 'PR');
    });

    test('no máximo 5 e um goleiro só', () {
      expect(canAddPlayer([luis], marlon), isFalse);
      expect(canAddPlayer([luis], caio), isTrue);
      expect(canAddPlayer([caio], caio), isFalse);
      final five = List.generate(5,
          (i) => TeamBuilderPlayer(id: '$i', name: 'J$i', isGoalkeeper: false));
      expect(canAddPlayer(five, luis), isFalse);
    });

    test('goleiro embaixo e uma vaga livre de cada', () {
      final slots = pitchSlots([caio, luis], withEmpty: true);
      expect(slots.firstWhere((s) => s.player == luis).y, .82);
      expect(slots.where((s) => s.player == null), hasLength(1),
          reason: 'goleiro já escolhido: só a vaga de linha');
      expect(pitchSlots([caio], withEmpty: true).where((s) => s.player == null),
          hasLength(2));
      expect(
          pitchSlots([caio, pagel], withEmpty: false)
              .every((s) => s.player != null),
          isTrue);
    });
  });

  testWidgets(
      'campo dentro de Column em scroll mantém a proporção (não achata)',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 600),
        TeamBuilderPitch(
            players: const [caio, pagel, luis],
            onEmptyTap: () {},
            sub: (_) => '54%'),
        const SizedBox(height: 600),
      ]),
    )));

    final size = tester.getSize(find.byType(TeamBuilderPitch));
    expect(size.width, 390);
    expect(size.height, closeTo(390 * 5 / 4, .5));
    expect(find.text('Caio'), findsOneWidget);
    expect(find.text('adicionar'), findsOneWidget);
    expect(find.text('goleiro'), findsNothing);
  });

  testWidgets('imagem de compartilhar 9:16 com os números e a marca',
      (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final stats = TeamBuilderStats.fromJson(statsJson);

    await tester.pumpWidget(_app(Center(
      child: TeamBuilderShareCard(
          stats: stats,
          players: const [caio, pagel, luis],
          groupName: 'Bratnava FC',
          period: 'Temporada 2026'),
    )));

    expect(tester.getSize(find.byType(TeamBuilderShareCard)),
        const Size(360, 640));
    expect(find.text('Caio, Pagel e Luis'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget);
    expect(find.text('10,9'), findsOneWidget);
    expect(
        find.text('5V 2E 2D · juntos 63% · média deles 54%'), findsOneWidget);
    expect(find.text('patotasapp.com.br'), findsOneWidget);
    expect(find.text('14G 4A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista de escolha: um goleiro só e marca quem entra',
      (tester) async {
    final selected = <TeamBuilderPlayer>[luis];
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showTeamBuilderPicker(
          context,
          players: const [caio, luis, marlon, pagel],
          selected: () => selected,
          onToggle: (p) => selected.any((s) => s.id == p.id)
              ? selected.removeWhere((s) => s.id == p.id)
              : selected.add(p),
        ),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Goleiro · 10 jogos no período'), findsOneWidget);
    await tester.tap(find.text('Marlon'));
    await tester.pump();
    expect(selected.map((p) => p.id), ['p3'],
        reason: 'segundo goleiro fica bloqueado');

    await tester.tap(find.text('Caio Silva'));
    await tester.pump();
    expect(selected.map((p) => p.id), ['p3', 'p1']);
    expect(find.text('2/5'), findsOneWidget);
  });

  group('só admin da patota', () {
    test('menu esconde Monte seu Time de quem não é admin', () {
      expect(
          isShellMenuItemVisible(
              path: '/app/team-builder', isAdmin: false, canSeeStats: true),
          isFalse);
      expect(
          isShellMenuItemVisible(
              path: '/app/team-builder', isAdmin: true, canSeeStats: false),
          isTrue);
    });

    testWidgets('a rota aberta direto não mostra nada para quem não é admin',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = AccountStore(await SharedPreferences.getInstance());
      await store.setAccount(const Account(
        userId: 'u',
        name: 'Usuário',
        email: 'u@teste.com',
        roles: [],
        activeGroupId: 'g',
        activeGroupIsAdmin: false,
      ));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          accountStoreProvider.overrideWith((ref) => store),
          myPlayersProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const TeamBuilderPage()),
      ));
      await tester.pump();

      expect(find.text('Monte seu Time é só para administradores da patota.'),
          findsOneWidget);
      expect(find.text('Escolher jogadores'), findsNothing);
      expect(find.text('Compartilhar com os dados'), findsNothing);
    });
  });
}
