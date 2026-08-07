import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_utils.dart';

// ── Match history item (per-player view) ──────────────────────────────────────

class MatchHistoryItem extends Equatable {
  final String matchId;
  final String date;
  final String? place;
  final String result; // "win" | "loss" | "draw"
  final int teamAScore;
  final int teamBScore;
  final String? teamAColor;
  final String? teamBColor;
  final int goals;
  final int assists;
  final bool isMvp;
  final bool isOwnGoal;
  final int team; // 1 = team A, 2 = team B

  const MatchHistoryItem({
    required this.matchId,
    required this.date,
    this.place,
    required this.result,
    required this.teamAScore,
    required this.teamBScore,
    this.teamAColor,
    this.teamBColor,
    required this.goals,
    required this.assists,
    required this.isMvp,
    required this.isOwnGoal,
    required this.team,
  });

  /// Nomes do payload de `/player-history`, conferidos contra o site.
  ///
  /// Este mapeamento estava todo errado: lia `goals`, `assists`, `isMvp`,
  /// `date`, `place`, `teamAScore`… nenhum desses campos existe na resposta.
  /// Como cada leitura caía no valor padrão, o histórico vinha inteiro
  /// zerado — gols, assistências e MVP sempre 0 no dashboard.
  ///
  /// Os nomes antigos ficam como alternativa: se o backend um dia normalizar,
  /// os dois formatos funcionam.
  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

    final teamA = asInt(j['teamAGoals'] ?? j['teamAScore']);
    final teamB = asInt(j['teamBGoals'] ?? j['teamBScore']);
    final team = asInt(j['playerTeam'] ?? j['team']);

    return MatchHistoryItem(
      matchId: (j['matchId'] ?? '').toString(),
      date: (j['playedAt'] ?? j['date'] ?? '').toString(),
      place: (j['placeName'] ?? j['place']) as String?,
      result: _resultOf(teamA: teamA, teamB: teamB, team: team),
      teamAScore: teamA,
      teamBScore: teamB,
      teamAColor: (j['teamAColorHex'] ?? j['teamAColor']) as String?,
      teamBColor: (j['teamBColorHex'] ?? j['teamBColor']) as String?,
      goals: asInt(j['playerGoals'] ?? j['goals']),
      assists: asInt(j['playerAssists'] ?? j['assists']),
      isMvp: (j['isPlayerMvp'] ?? j['isMvp']) as bool? ?? false,
      isOwnGoal:
          asInt(j['playerOwnGoals']) > 0 || (j['isOwnGoal'] as bool? ?? false),
      team: team,
    );
  }

  /// O payload não traz o resultado pronto: sai do placar e do time do
  /// jogador, como o `getResult` do site. Antes o campo `result` era lido
  /// direto do JSON, vinha nulo e caía em "draw" — todas as partidas
  /// contavam como empate.
  static String _resultOf({
    required int teamA,
    required int teamB,
    required int team,
  }) {
    if (teamA == teamB) return 'draw';
    final aWon = teamA > teamB;
    final playerWon = (team == 1 && aWon) || (team == 2 && !aWon);
    return playerWon ? 'win' : 'loss';
  }

  bool get isWin => result.toLowerCase() == 'win';
  bool get isLoss => result.toLowerCase() == 'loss';
  bool get isDraw => !isWin && !isLoss;

  @override
  List<Object?> get props => [
        matchId,
        date,
        place,
        result,
        teamAScore,
        teamBScore,
        teamAColor,
        teamBColor,
        goals,
        assists,
        isMvp,
        isOwnGoal,
        team,
      ];
}

// ── Stats summary computed from a list of items ───────────────────────────────

class PlayerHistorySummary {
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final int totalGoals;
  final int totalAssists;
  final int totalMvps;

  /// Ano da primeira partida disputada. `null` quando não há histórico.
  final int? firstSeasonYear;

  const PlayerHistorySummary({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalGoals,
    required this.totalAssists,
    required this.totalMvps,
    this.firstSeasonYear,
  });

  /// Em qual temporada o jogador está, contando a partir da primeira partida.
  ///
  /// O protótipo mostra "3ª temporada" no card do jogador. Como não existe data
  /// de entrada na patota, a referência é a primeira partida disputada — que na
  /// prática é quando a pessoa começou a jogar. Sem histórico, é a 1ª.
  int get seasonNumber {
    final first = firstSeasonYear;
    if (first == null) return 1;
    final diff = DateTime.now().year - first;
    return diff < 0 ? 1 : diff + 1;
  }

  factory PlayerHistorySummary.from(List<MatchHistoryItem> items) {
    int wins = 0, losses = 0, draws = 0, goals = 0, assists = 0, mvps = 0;
    int? firstYear;

    for (final m in items) {
      if (m.isWin)
        wins++;
      else if (m.isLoss)
        losses++;
      else
        draws++;
      goals += m.goals;
      assists += m.assists;
      if (m.isMvp) mvps++;

      final year = AppDateUtils.parse(m.date)?.year;
      if (year != null && (firstYear == null || year < firstYear)) {
        firstYear = year;
      }
    }

    return PlayerHistorySummary(
      totalMatches: items.length,
      wins: wins,
      losses: losses,
      draws: draws,
      totalGoals: goals,
      totalAssists: assists,
      totalMvps: mvps,
      firstSeasonYear: firstYear,
    );
  }
}
