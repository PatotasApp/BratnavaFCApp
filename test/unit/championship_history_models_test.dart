import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/dashboard/domain/entities/recent_match.dart';
import 'package:patotas_app/features/history/domain/entities/history_match.dart';
import 'package:patotas_app/features/player_history/domain/entities/player_history_models.dart';

void main() {
  group('Histórico geral com campeonatos', () {
    test('lê o item consolidado e nunca o trata como placar', () {
      final item = HistoryMatch.fromJson(const {
        'id': 'resumo-1',
        'playedAt': '2026-10-25T18:00:00Z',
        'teamAGoals': 0,
        'teamBGoals': 0,
        'kind': 'championship',
        'championshipId': 'campeonato-1',
        'championshipName': 'Copa de Domingo',
        'championTeamName': 'Time Azul',
        'championTeamColorHex': '1565C0',
        'ruleBadges': ['Todos contra todos', 'Pontos por jogo'],
      });

      expect(item.isConsolidatedChampionship, isTrue);
      expect(item.hasScore, isFalse);
      expect(item.championshipId, 'campeonato-1');
      expect(item.championTeamName, 'Time Azul');
      expect(item.championTeamColorHex, '#1565C0');
      expect(item.ruleBadges, ['Todos contra todos', 'Pontos por jogo']);
    });

    test('lê o pódio (1º a 3º) com nome e cor de cada time', () {
      final item = HistoryMatch.fromJson(const {
        'id': 'resumo-2',
        'kind': 'championship',
        'podium': [
          {'position': 1, 'teamName': 'Preto', 'colorHex': '000000'},
          {'position': 2, 'teamName': 'Azul', 'colorHex': '#1565C0'},
          {'position': 3, 'teamName': 'Verde', 'colorHex': null},
        ],
      });

      expect(item.podium.map((t) => t.position), [1, 2, 3]);
      expect(item.podium.map((t) => t.teamName), ['Preto', 'Azul', 'Verde']);
      expect(item.podium.map((t) => t.colorHex), ['#000000', '#1565C0', null]);
      expect(HistoryMatch.fromJson(const {'id': 'x'}).podium, isEmpty);
    });

    test('lê jogo de campeonato preservando placar e identificação', () {
      final item = HistoryMatch.fromJson(const {
        'matchId': 'jogo-1',
        'playedAt': '2026-10-25T18:30:00Z',
        'teamAGoals': 3,
        'teamBGoals': 1,
        'kind': 'championshipGame',
        'championshipId': 'campeonato-1',
        'championshipName': 'Copa de Domingo',
      });

      expect(item.isChampionshipGame, isTrue);
      expect(item.hasScore, isTrue);
      expect(item.teamAGoals, 3);
      expect(item.teamBGoals, 1);
    });
  });

  group('Histórico do jogador com campeonatos', () {
    test('N conta presença, mas não entra em vitórias, empates ou derrotas',
        () {
      final item = MatchHistoryItem.fromJson(const {
        'matchId': 'resumo-jogador-1',
        'playedAt': '2026-10-25T18:00:00Z',
        'teamAGoals': 0,
        'teamBGoals': 0,
        'playerTeam': 1,
        'playerResult': 'N',
        'teamAColorHex': '#1565C0',
        'teamAColorName': 'Azul',
        'kind': 'championship',
        'championshipId': 'campeonato-1',
        'championshipName': 'Copa de Domingo',
      });
      final summary = PlayerHistorySummary.from([item]);

      expect(item.result, 'none');
      expect(item.isPresence, isTrue);
      expect(item.isDraw, isFalse);
      expect(summary.totalMatches, 1);
      expect(summary.wins, 0);
      expect(summary.draws, 0);
      expect(summary.losses, 0);
    });

    test('playerResult prevalece sobre o placar do jogo de campeonato', () {
      final item = MatchHistoryItem.fromJson(const {
        'matchId': 'jogo-jogador-1',
        'playedAt': '2026-10-25T18:30:00Z',
        'teamAGoals': 0,
        'teamBGoals': 4,
        'playerTeam': 1,
        'playerResult': 'W',
        'kind': 'championshipGame',
        'championshipId': 'campeonato-1',
        'championshipName': 'Copa de Domingo',
      });

      expect(item.isChampionshipGame, isTrue);
      expect(item.isWin, isTrue);
      expect(item.isLoss, isFalse);
    });
  });

  group('Partidas recentes com campeonatos', () {
    test('lê N como presença no consolidado', () {
      final item = RecentMatch.fromJson(const {
        'matchId': 'resumo-recente-1',
        'playedAt': '2026-10-25T18:00:00Z',
        'teamAGoals': 0,
        'teamBGoals': 0,
        'playerTeam': 1,
        'playerResult': 'N',
        'teamAColorHex': '#1565C0',
        'teamAColorName': 'Azul',
        'kind': 'championship',
        'championshipId': 'campeonato-1',
        'championshipName': 'Copa de Domingo',
      });

      expect(item.outcome, MatchOutcome.presence);
      expect(item.isConsolidatedChampionship, isTrue);
      expect(item.championshipId, 'campeonato-1');
      expect(item.myTeamColor?.name, 'Azul');
    });
  });

  test('item comum sem kind mantém o comportamento baseado no placar', () {
    final general = HistoryMatch.fromJson(const {
      'id': 'partida-comum',
      'playedAt': '2026-10-25T18:00:00Z',
      'teamAGoals': 2,
      'teamBGoals': 1,
    });
    final player = MatchHistoryItem.fromJson(const {
      'matchId': 'partida-comum',
      'playedAt': '2026-10-25T18:00:00Z',
      'teamAGoals': 2,
      'teamBGoals': 1,
      'playerTeam': 2,
    });
    final recent = RecentMatch.fromJson(const {
      'matchId': 'partida-comum',
      'playedAt': '2026-10-25T18:00:00Z',
      'teamAGoals': 2,
      'teamBGoals': 1,
      'playerTeam': 2,
    });

    expect(general.isChampionshipItem, isFalse);
    expect(general.hasScore, isTrue);
    expect(player.isLoss, isTrue);
    expect(recent.outcome, MatchOutcome.loss);
  });
}
