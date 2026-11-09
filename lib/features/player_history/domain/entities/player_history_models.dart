import 'package:equatable/equatable.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../history/domain/entities/history_match.dart'
    show HistoryPodiumTeam;

// ── Match history item (per-player view) ──────────────────────────────────────

class MatchHistoryItem extends Equatable {
  final String matchId;
  final String date;
  final String? place;
  final String result; // "win" | "loss" | "draw" | "none"
  final int teamAScore;
  final int teamBScore;
  final String? teamAColor;
  final String? teamBColor;
  final int goals;
  final int assists;
  final bool isMvp;
  final bool isOwnGoal;
  final int team; // 1 = team A, 2 = team B
  final String? teamAColorName;
  final String? teamBColorName;
  final String? kind;
  final String? championshipId;
  final String? championshipName;
  final String? playerResult;

  /// Pódio do campeonato consolidado (até 3º), mostrado no lugar do placar.
  final List<HistoryPodiumTeam> podium;

  /// Campeonato: gols/assistências/MVP do item são os de fato; estes dizem
  /// se entram nos totais (regras de contagem do campeonato). Nulo = conta.
  final bool? goalsCountInStats;
  final bool? mvpCountsInStats;

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
    this.teamAColorName,
    this.teamBColorName,
    this.kind,
    this.championshipId,
    this.championshipName,
    this.playerResult,
    this.podium = const [],
    this.goalsCountInStats,
    this.mvpCountsInStats,
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
    final playerResult = j['playerResult'] as String?;

    return MatchHistoryItem(
      matchId: (j['matchId'] ?? '').toString(),
      date: (j['playedAt'] ?? j['date'] ?? '').toString(),
      place: (j['placeName'] ?? j['place']) as String?,
      result: _resultFromApi(playerResult) ??
          _resultOf(teamA: teamA, teamB: teamB, team: team),
      teamAScore: teamA,
      teamBScore: teamB,
      teamAColor: (j['teamAColorHex'] ?? j['teamAColor']) as String?,
      teamBColor: (j['teamBColorHex'] ?? j['teamBColor']) as String?,
      teamAColorName: j['teamAColorName'] as String?,
      teamBColorName: j['teamBColorName'] as String?,
      goals: asInt(j['playerGoals'] ?? j['goals']),
      assists: asInt(j['playerAssists'] ?? j['assists']),
      isMvp: (j['isPlayerMvp'] ?? j['isMvp']) as bool? ?? false,
      isOwnGoal:
          asInt(j['playerOwnGoals']) > 0 || (j['isOwnGoal'] as bool? ?? false),
      team: team,
      kind: j['kind'] as String?,
      championshipId: j['championshipId']?.toString(),
      championshipName: j['championshipName'] as String?,
      playerResult: playerResult,
      podium: (j['podium'] as List?)
              ?.whereType<Map>()
              .map((item) => HistoryPodiumTeam(
                    position: (item['position'] as num?)?.toInt() ?? 0,
                    teamName: (item['teamName'] as String?) ?? 'Time',
                    colorHex: item['colorHex'] as String?,
                  ))
              .where((item) => item.position > 0)
              .toList(growable: false) ??
          const [],
      goalsCountInStats: j['goalsCountInStats'] as bool?,
      mvpCountsInStats: j['mvpCountsInStats'] as bool?,
    );
  }

  static String? _resultFromApi(String? value) =>
      switch (value?.toUpperCase()) {
        'W' => 'win',
        'D' => 'draw',
        'L' => 'loss',
        'N' => 'none',
        _ => null,
      };

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
  bool get isDraw => result.toLowerCase() == 'draw';
  bool get isPresence => result.toLowerCase() == 'none';
  bool get isConsolidatedChampionship => kind == 'championship';
  bool get isChampionshipGame => kind == 'championshipGame';
  bool get isChampionshipItem =>
      isConsolidatedChampionship || isChampionshipGame;

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
        teamAColorName,
        teamBColorName,
        kind,
        championshipId,
        championshipName,
        playerResult,
        podium,
        goalsCountInStats,
        mvpCountsInStats,
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

  /// Data da primeira partida disputada. `null` quando não há histórico.
  final DateTime? firstPlayedAt;

  const PlayerHistorySummary({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalGoals,
    required this.totalAssists,
    required this.totalMvps,
    this.firstPlayedAt,
  });

  /// Fallback usado enquanto os períodos da patota ainda estão carregando.
  /// A contagem correta, inclusive para duas temporadas no mesmo ano, é feita
  /// por `SeasonsOverview.seasonOrdinalFor` no dashboard.
  int get seasonNumber {
    final first = firstPlayedAt?.year;
    if (first == null) return 1;
    final diff = DateTime.now().year - first;
    return diff < 0 ? 1 : diff + 1;
  }

  factory PlayerHistorySummary.from(List<MatchHistoryItem> items) {
    int wins = 0, losses = 0, draws = 0, goals = 0, assists = 0, mvps = 0;
    DateTime? firstPlayedAt;

    for (final m in items) {
      if (m.isWin) {
        wins++;
      } else if (m.isLoss) {
        losses++;
      } else if (m.isDraw) {
        draws++;
      }
      // Regra do campeonato: o item mostra o que aconteceu, mas só soma se a
      // regra deixar (mesma conta do site).
      if (m.goalsCountInStats != false) {
        goals += m.goals;
        assists += m.assists;
      }
      if (m.isMvp && m.mvpCountsInStats != false) mvps++;

      final playedAt = AppDateUtils.parse(m.date);
      if (playedAt != null &&
          (firstPlayedAt == null || playedAt.isBefore(firstPlayedAt))) {
        firstPlayedAt = playedAt;
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
      firstPlayedAt: firstPlayedAt,
    );
  }
}
