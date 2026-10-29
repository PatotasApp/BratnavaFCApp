import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/championships/presentation/widgets/championship_podium_box.dart';
import 'package:patotas_app/features/dashboard/domain/entities/recent_match.dart';
import 'package:patotas_app/features/history/domain/entities/history_match.dart';

void main() {
  testWidgets('pódio mostra 1º a 3º no lugar do placar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ChampionshipPodiumBox(podium: [
            const HistoryPodiumTeam(
                position: 1, teamName: 'Preto', colorHex: '#000000'),
            const HistoryPodiumTeam(
                position: 2, teamName: 'Azul', colorHex: '1565C0'),
            const HistoryPodiumTeam(position: 3, teamName: 'Verde'),
            const HistoryPodiumTeam(position: 4, teamName: 'Laranja'),
          ]),
        ),
      ),
    ));

    expect(find.text('1º'), findsOneWidget);
    expect(find.text('2º'), findsOneWidget);
    expect(find.text('3º'), findsOneWidget);
    expect(find.text('4º'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('sem pódio, usa o campeão; sem campeão, fica vazio', () {
    expect(
      podiumOrChampion(podium: const [], championTeamName: 'Preto')
          .map((t) => '${t.position}º ${t.teamName}'),
      ['1º Preto'],
    );
    expect(podiumOrChampion(podium: const []), isEmpty);
  });

  test('últimas partidas leem o pódio do item consolidado', () {
    final item = RecentMatch.fromJson(const {
      'matchId': 'c1',
      'playedAt': '2026-11-05T04:11:00Z',
      'kind': 'championship',
      'playerResult': 'W',
      'podium': [
        {'position': 1, 'teamName': 'Preto', 'colorHex': '000000'},
        {'position': 2, 'teamName': 'Azul', 'colorHex': '1565C0'},
      ],
    });

    expect(item.isConsolidatedChampionship, isTrue);
    expect(item.podium.map((t) => t.teamName), ['Preto', 'Azul']);
  });
}
