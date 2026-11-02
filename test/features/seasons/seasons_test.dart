import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patotas_app/core/push/notification_router.dart';
import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/features/seasons/domain/season_models.dart';
import 'package:patotas_app/features/seasons/presentation/pages/season_summary_page.dart';
import 'package:patotas_app/features/seasons/presentation/providers/seasons_provider.dart';
import 'package:patotas_app/features/seasons/presentation/widgets/season_picker.dart';

Season _season(String id, {int year = 2026, int number = 1, String? name, String? display,
        required String start, String? end, bool pre = false, bool current = false}) =>
    Season(
      id: id,
      year: year,
      number: number,
      name: name,
      displayName: display ?? '$year/$number',
      startsAt: DateTime.parse(start),
      endsAt: end == null ? null : DateTime.parse(end),
      isPreSeason: pre,
      isOpen: end == null,
      isCurrent: current,
      matches: 0,
      championships: 0,
    );

final _overview = SeasonsOverview(
  seasons: [
    _season('a', year: 2025, display: '2025', start: '2025-01-01T03:00:00Z', end: '2026-01-01T03:00:00Z'),
    _season('b', start: '2026-01-01T03:00:00Z', end: '2026-11-22T02:59:00Z'),
    _season('c', number: 2, name: 'Pré-temporada', display: 'Pré-temporada', pre: true,
        start: '2026-11-22T02:59:00Z', current: true),
  ],
  currentSeasonId: 'c',
  manualMode: true,
  canUndoClose: true,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('seleção de temporada', () {
    test('parâmetros da API e filtro pela data do jogo', () {
      expect(const CurrentSeason().params(_overview), {'seasonId': 'c'});
      expect(const YearPick(2026, includePreSeason: false).params(_overview),
          {'year': '2026', 'includePreSeason': 'false'});
      expect(const AllSeasons().params(_overview), isEmpty);

      final evento = DateTime.parse('2026-11-21T23:00:00Z'); // 20h do dia 21: ainda 2026/1
      final depois = DateTime.parse('2026-12-05T23:00:00Z');
      expect(const SeasonPick('b').contains(_overview, evento), isTrue);
      expect(const CurrentSeason().contains(_overview, evento), isFalse);
      expect(const YearPick(2026, includePreSeason: false).contains(_overview, depois), isFalse);
      expect(const YearPick(2026, includePreSeason: true).contains(_overview, depois), isTrue);
      expect(const CurrentSeason().label(_overview), 'Pré-temporada');
    });

    test('a chave volta para a mesma escolha', () {
      for (final s in const <SeasonSelection>[
        CurrentSeason(),
        SeasonPick('b'),
        YearPick(2026, includePreSeason: true),
        AllSeasons(),
      ]) {
        expect(SeasonSelection.parse(s.key).key, s.key);
      }
    });

    test('notificação de temporada encerrada abre a retrospectiva', () {
      expect(notificationRoute('season_closed', {'seasonId': 'b'}), '/app/seasons/b');
      expect(notificationRoute('season_closed', {}), '/app/conquistas');
    });
  });

  testWidgets('seletor escolhe o ano com pré-temporada', (tester) async {
    SeasonSelection? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SeasonPicker(
          overview: _overview,
          value: const CurrentSeason(),
          onChanged: (s) => chosen = s,
        ),
      ),
    ));
    expect(find.text('Temporada atual (Pré-temporada)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('season-picker')));
    await tester.pumpAndSettle();
    expect(find.text('   Ano 2026 inteiro (sem pré-temporada)'), findsOneWidget);
    await tester.tap(find.text('   Ano 2026 com pré-temporada').last);
    await tester.pumpAndSettle();
    expect(chosen?.key, 'year:2026:1');
  });

  testWidgets('retrospectiva: pódio e classificação real com empate', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final summary = SeasonSummary(
      season: _season('b', start: '2026-01-01T03:00:00Z', end: '2026-11-22T02:59:00Z'),
      matches: 38,
      championships: 1,
      goals: 120,
      players: 15,
      titlesSealed: true,
      rankings: const [
        SeasonRanking(category: 'Gols', name: 'Gols', icon: '⚽', minGames: 3, rows: [
          SeasonRankingRow(position: 1, playerId: 'p1', playerName: 'Ana', value: 20, games: 30, isGuest: false),
          SeasonRankingRow(position: 2, playerId: 'p2', playerName: 'Bia', value: 15, games: 28, isGuest: false),
          SeasonRankingRow(position: 2, playerId: 'p3', playerName: 'Caio', value: 15, games: 25, isGuest: false),
          SeasonRankingRow(position: 4, playerId: 'p4', playerName: 'Dani', value: 9, games: 20, isGuest: true),
        ]),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        seasonsGroupIdProvider.overrideWithValue('g'),
        seasonSummaryProvider((groupId: 'g', seasonId: 'b')).overrideWith((ref) async => summary),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const SeasonSummaryPage(seasonId: 'b')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Temporada 2026/1'), findsOneWidget);
    expect(find.text('🥈'), findsNWidgets(2));
    expect(find.text('4º'), findsNothing);
    await tester.tap(find.text('Classificação completa (4)'));
    await tester.pumpAndSettle();
    expect(find.text('4º'), findsOneWidget);
    expect(find.text('Dani · convidado'), findsOneWidget);
  });
}
