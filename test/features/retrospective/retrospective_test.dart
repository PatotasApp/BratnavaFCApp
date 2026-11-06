import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/retrospective/domain/entities/player_retrospective.dart';
import 'package:patotas_app/features/retrospective/domain/retrospective_stories.dart';
import 'package:patotas_app/features/retrospective/presentation/pages/retrospective_stories_page.dart';
import 'package:patotas_app/features/retrospective/presentation/widgets/retro_story_card.dart';
import 'package:patotas_app/features/shell/domain/shell_navigation_policy.dart';

Map<String, dynamic> sampleJson() => {
      'groupId': 'g1',
      'groupName': 'Bratnava FC',
      'period': {'year': 2026, 'label': '2026', 'isPartial': true},
      'availableYears': [2026, 2025],
      'players': [
        {
          'playerId': 'p-caio',
          'name': 'Caio Souza',
          'shortName': 'Caio',
          'games': 39
        },
      ],
      'player': {
        'playerId': 'p-caio',
        'name': 'Caio Souza',
        'shortName': 'Caio',
        'games': 39
      },
      'isGoalkeeper': false,
      'totalGames': 46,
      'minGamesForRates': 10,
      'ratedPlayers': 14,
      'presence': {'games': 39, 'percent': 85, 'rank': 6, 'longestStreak': 13},
      'results': {
        'wins': 25,
        'draws': 3,
        'losses': 11,
        'aproveitamento': 67,
        'rank': 1,
        'longestWinStreak': 7,
        'longestUnbeatenStreak': 9,
        'bestMonth': {
          'year': 2026,
          'month': 1,
          'wins': 4,
          'draws': 0,
          'losses': 0,
          'aproveitamento': 100
        },
      },
      'goals': {
        'total': 65,
        'rank': 6,
        'bestNight': {'count': 5, 'playedAt': '2026-10-20T23:00:00Z'}
      },
      'assists': {
        'total': 52,
        'rank': 2,
        'bestNight': {'count': 5, 'playedAt': '2026-05-13T23:00:00Z'},
        'mostAssistedTo': {'playerId': 'p-artur', 'name': 'Artur', 'count': 8},
        'mostAssistedBy': {
          'playerId': 'p-marlon',
          'name': 'Marlon',
          'count': 9
        },
      },
      'months': [
        for (var m = 2; m <= 10; m++)
          {'year': 2026, 'month': m, 'goals': m, 'assists': 10 - m},
      ],
      'decisive': {'openers': 5, 'winningGoals': 4, 'perGameRank': 3},
      'bestPartner': {
        'playerId': 'p-andrei',
        'name': 'Andrei Salvador',
        'games': 9,
        'wins': 8,
        'draws': 0,
        'losses': 1,
        'aproveitamento': 89
      },
      'frequentPartner': {
        'playerId': 'p-luis',
        'name': 'Luis',
        'games': 21,
        'wins': 12,
        'draws': 3,
        'losses': 6,
        'aproveitamento': 62
      },
      'fregues': {
        'playerId': 'p-luska',
        'name': 'Luska',
        'wins': 17,
        'draws': 3,
        'losses': 6
      },
      'carrasco': null,
      'milestones': [
        {
          'kind': 'first_assist',
          'number': 1,
          'playedAt': '2026-02-10T23:00:00Z'
        },
        {
          'kind': 'goal_century',
          'number': 500,
          'playedAt': '2026-07-14T23:00:00Z'
        },
        {
          'kind': 'last_goal',
          'number': 789,
          'playedAt': '2026-10-20T23:00:00Z'
        },
      ],
      'mvp': {'mvps': 4, 'votes': 19, 'rank': 5},
      'ownGoals': 1,
      'profile': {
        'key': 'pequente',
        'rank': 1,
        'goalsPerGame': 1.67,
        'goalsPerGameRank': 6,
        'assistsPerGame': 1.33,
        'assistsPerGameRank': 2,
        'goalkeeperGames': 0,
      },
    };

void main() {
  final r = PlayerRetrospective.fromJson(sampleJson());

  group('modelo e regras', () {
    test('lê o DTO da API', () {
      expect(r.player.shortName, 'Caio');
      expect(r.games, 39);
      expect(r.results, 39);
      expect(r.bestMonth?.month, 1);
      expect(r.bestGoalNight?.count, 5);
      expect(r.mostAssistedBy?.name, 'Marlon');
      expect(r.months, hasLength(9));
      expect(r.carrasco, isNull);
      expect(r.milestones.map((m) => m.kind),
          ['first_assist', 'goal_century', 'last_goal']);
      expect(r.profileKey, 'pequente');
    });

    test('só mostra stories com dado', () {
      expect(storiesFor(r).map((s) => s.id), StoryId.values);
      final quiet = PlayerRetrospective.fromJson({
        ...sampleJson(),
        'goals': {'total': 0},
        'assists': {'total': 0},
        'decisive': {'openers': 0, 'winningGoals': 0},
        'bestPartner': null,
        'frequentPartner': null,
        'fregues': null,
        'milestones': [],
        'mvp': {'mvps': 0, 'votes': 0},
        'ownGoals': 0,
      });
      expect(storiesFor(quiet).map((s) => s.id), [
        StoryId.abertura,
        StoryId.presenca,
        StoryId.resultados,
        StoryId.perfil,
        StoryId.resumo
      ]);
      final none = PlayerRetrospective.fromJson({
        ...sampleJson(),
        'presence': {'games': 0}
      });
      expect(storiesFor(none), isEmpty);
    });

    test('perfil, posição na metade de cima e marcos', () {
      final pd = profileData(r);
      expect(pd.heroValue, '67%');
      expect(pd.rows, [
        ('Vitórias', '25 em 39 jogos'),
        ('No ranking', '1º da patota'),
        ('Mais vitórias seguidas', '7')
      ]);
      expect(topHalf(r, 7), '7º da patota');
      expect(topHalf(r, 8), isNull);
      expect(milestoneText('assist_century', 400, false).badge, '400ª');
      expect(milestoneText('last_goal', 789, true).text,
          'Fez o gol mais recente da temporada');
      expect(dayMonth(DateTime.utc(2026, 7, 15, 1)),
          '14/07'); // 22h de 14/07 em Brasília
      expect(fmtNum(1.67), '1,67');
      expect(storyFileName(r, storiesFor(r).last),
          'retrospectiva-2026-caio-resumo');
    });

    test('retrospectiva aparece no menu só para admin', () {
      expect(shellAdminOnlyMenuPaths, contains('/app/retrospectiva'));
      expect(
          isShellMenuItemVisible(
              path: '/app/retrospectiva', isAdmin: false, canSeeStats: true),
          isFalse);
      expect(
          isShellMenuItemVisible(
              path: '/app/retrospectiva', isAdmin: true, canSeeStats: false),
          isTrue);
    });
  });

  group('cartões', () {
    for (final story in storiesFor(r)) {
      testWidgets('${story.name}: cabe no 9:16 e leva a marca PatotasApp',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 360,
                      child: RetroStoryCard(r: r, story: story, still: true)))),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('patotasapp.com.br'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });
    }

    testWidgets('a imagem compartilhada sai em 1080×1920', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RetroShareSheet(r: r, story: storiesFor(r).last)),
      ));
      expect(find.text('Story do Instagram'), findsNothing);
      expect(find.text('Copiar imagem'), findsOneWidget);
      expect(find.text('Mais opções'), findsOneWidget);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .descendant(
                of: find.byType(RetroShareSheet),
                matching: find.byType(RepaintBoundary))
            .first,
      );
      expect(boundary.size, const Size(180, 320));
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: RetroShareSheet.pixelRatio);
      });
      expect((image.width, image.height), (1080, 1920));
      image.dispose();
    });

    testWidgets('stories: toque avança e volta, e passa sozinho em 6 s',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(MaterialApp(home: RetrospectiveStoriesPage(r: r)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(StoryId.abertura)), findsOneWidget);

      final card = tester.getRect(find.byType(RetroStoryCard));
      await tester.tapAt(Offset(card.right - 20, card.center.dy));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(StoryId.presenca)), findsOneWidget);

      await tester.tapAt(Offset(card.left + 20, card.center.dy));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(StoryId.abertura)), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey(StoryId.presenca)), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
