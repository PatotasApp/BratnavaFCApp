import 'championship_enums.dart';

class WinnerStaysRules {
  const WinnerStaysRules({
    required this.consecutiveWinsLimit,
    required this.tieRule,
    this.limitRule = WinnerStaysLimitRule.winnerLeaves,
  });

  final int consecutiveWinsLimit;
  final WinnerStaysTieRule tieRule;
  final WinnerStaysLimitRule limitRule;

  factory WinnerStaysRules.fromJson(Map<String, dynamic> json) =>
      WinnerStaysRules(
        consecutiveWinsLimit: json['consecutiveWinsLimit'] as int,
        tieRule: enumByValue(WinnerStaysTieRule.values, json['tieRule'] as int),
        limitRule: json['limitRule'] == null
            ? WinnerStaysLimitRule.winnerLeaves
            : enumByValue(
                WinnerStaysLimitRule.values,
                json['limitRule'] as int,
              ),
      );

  Map<String, dynamic> toJson() => {
        'consecutiveWinsLimit': consecutiveWinsLimit,
        'tieRule': tieRule.value,
        'limitRule': limitRule.value,
      };
}

class ChampionshipGameEndRules {
  const ChampionshipGameEndRules({
    this.timeLimitMinutes,
    this.goalLimit,
  });

  final int? timeLimitMinutes;
  final int? goalLimit;

  factory ChampionshipGameEndRules.fromJson(Map<String, dynamic> json) =>
      ChampionshipGameEndRules(
        timeLimitMinutes: json['timeLimitMinutes'] as int?,
        goalLimit: json['goalLimit'] as int?,
      );

  /// 0 vira null: sem limite (a API recusa 0).
  Map<String, dynamic> toJson() => {
        'timeLimitMinutes': timeLimitMinutes == 0 ? null : timeLimitMinutes,
        'goalLimit': goalLimit == 0 ? null : goalLimit,
      };
}

class ChampionshipStandingsRules {
  const ChampionshipStandingsRules({
    required this.mode,
    required this.winPoints,
    required this.drawPoints,
    required this.tiebreakers,
  });

  final ChampionshipStandingMode mode;
  final int winPoints;
  final int drawPoints;
  final List<ChampionshipTiebreakerCriteria> tiebreakers;

  factory ChampionshipStandingsRules.fromJson(Map<String, dynamic> json) =>
      ChampionshipStandingsRules(
        mode: enumByValue(
          ChampionshipStandingMode.values,
          json['mode'] as int,
        ),
        winPoints: json['winPoints'] as int,
        drawPoints: json['drawPoints'] as int,
        tiebreakers: (json['tiebreakers'] as List<dynamic>)
            .map((value) => enumByValue(
                  ChampionshipTiebreakerCriteria.values,
                  value as int,
                ))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'winPoints': winPoints,
        'drawPoints': drawPoints,
        'tiebreakers': tiebreakers.map((item) => item.value).toList(),
      };
}

class ChampionshipRules {
  const ChampionshipRules({
    required this.historyMode,
    required this.resultMode,
    required this.placementResults,
    required this.mvpMode,
    required this.mvpCountsInGeneralStats,
    required this.goalsCountInGeneralStats,
    required this.includeInTeamDraw,
    required this.minGamesForPlacementResult,
    required this.format,
    required this.roundRobinTurns,
    required this.winnerStays,
    required this.gameEnd,
    required this.standings,
  });

  final ChampionshipHistoryMode historyMode;
  final ChampionshipResultMode resultMode;
  final List<PlacementResult> placementResults;
  final ChampionshipMvpMode mvpMode;
  final bool mvpCountsInGeneralStats;
  final bool goalsCountInGeneralStats;
  final bool includeInTeamDraw;
  final int minGamesForPlacementResult;
  final ChampionshipFormat format;

  /// Mínimo de times do formato (igual à API): fica quem ganha precisa de 3.
  int get minimumTeams => format == ChampionshipFormat.winnerStays ? 3 : 2;
  final int roundRobinTurns;
  final WinnerStaysRules? winnerStays;
  final ChampionshipGameEndRules gameEnd;
  final ChampionshipStandingsRules standings;

  factory ChampionshipRules.defaults() => const ChampionshipRules(
        historyMode: ChampionshipHistoryMode.consolidated,
        resultMode: ChampionshipResultMode.placement,
        placementResults: [
          PlacementResult.win,
          PlacementResult.draw,
          PlacementResult.loss,
        ],
        mvpMode: ChampionshipMvpMode.perChampionship,
        mvpCountsInGeneralStats: true,
        goalsCountInGeneralStats: false,
        includeInTeamDraw: false,
        minGamesForPlacementResult: 1,
        format: ChampionshipFormat.winnerStays,
        roundRobinTurns: 1,
        winnerStays: WinnerStaysRules(
          consecutiveWinsLimit: 0,
          tieRule: WinnerStaysTieRule.longestOnFieldLeaves,
        ),
        gameEnd: ChampionshipGameEndRules(
          timeLimitMinutes: 10,
          goalLimit: 2,
        ),
        standings: ChampionshipStandingsRules(
          mode: ChampionshipStandingMode.pointsPerGame,
          winPoints: 3,
          drawPoints: 1,
          tiebreakers: [
            ChampionshipTiebreakerCriteria.points,
            ChampionshipTiebreakerCriteria.goalDifference,
            ChampionshipTiebreakerCriteria.goalsFor,
            ChampionshipTiebreakerCriteria.headToHead,
            ChampionshipTiebreakerCriteria.externalDecision,
          ],
        ),
      );

  factory ChampionshipRules.fromJson(Map<String, dynamic> json) =>
      ChampionshipRules(
        historyMode: enumByValue(
          ChampionshipHistoryMode.values,
          json['historyMode'] as int,
        ),
        resultMode: enumByValue(
          ChampionshipResultMode.values,
          json['resultMode'] as int,
        ),
        placementResults: (json['placementResults'] as List<dynamic>? ?? [])
            .map((value) => enumByValue(
                  PlacementResult.values,
                  value as int,
                ))
            .toList(growable: false),
        mvpMode: enumByValue(
          ChampionshipMvpMode.values,
          json['mvpMode'] as int,
        ),
        mvpCountsInGeneralStats: json['mvpCountsInGeneralStats'] as bool,
        goalsCountInGeneralStats: json['goalsCountInGeneralStats'] as bool,
        includeInTeamDraw: json['includeInTeamDraw'] as bool,
        minGamesForPlacementResult: json['minGamesForPlacementResult'] as int,
        format: enumByValue(
          ChampionshipFormat.values,
          json['format'] as int,
        ),
        roundRobinTurns: json['roundRobinTurns'] as int,
        winnerStays: json['winnerStays'] == null
            ? null
            : WinnerStaysRules.fromJson(
                json['winnerStays'] as Map<String, dynamic>,
              ),
        gameEnd: ChampionshipGameEndRules.fromJson(
          json['gameEnd'] as Map<String, dynamic>,
        ),
        standings: ChampionshipStandingsRules.fromJson(
          json['standings'] as Map<String, dynamic>,
        ),
      );

  Map<String, dynamic> toJson() => {
        'historyMode': historyMode.value,
        'resultMode': resultMode.value,
        'placementResults': placementResults.map((item) => item.value).toList(),
        'mvpMode': mvpMode.value,
        'mvpCountsInGeneralStats': mvpCountsInGeneralStats,
        'goalsCountInGeneralStats': goalsCountInGeneralStats,
        'includeInTeamDraw': includeInTeamDraw,
        'minGamesForPlacementResult': minGamesForPlacementResult,
        'format': format.value,
        'roundRobinTurns': roundRobinTurns,
        'winnerStays': winnerStays?.toJson(),
        'gameEnd': gameEnd.toJson(),
        'standings': standings.toJson(),
      };

  ChampionshipRules copyWith({
    ChampionshipHistoryMode? historyMode,
    ChampionshipResultMode? resultMode,
    List<PlacementResult>? placementResults,
    ChampionshipMvpMode? mvpMode,
    bool? mvpCountsInGeneralStats,
    bool? goalsCountInGeneralStats,
    bool? includeInTeamDraw,
    int? minGamesForPlacementResult,
    ChampionshipFormat? format,
    int? roundRobinTurns,
    WinnerStaysRules? winnerStays,
    ChampionshipGameEndRules? gameEnd,
    ChampionshipStandingsRules? standings,
  }) =>
      ChampionshipRules(
        historyMode: historyMode ?? this.historyMode,
        resultMode: resultMode ?? this.resultMode,
        placementResults: placementResults ?? this.placementResults,
        mvpMode: mvpMode ?? this.mvpMode,
        mvpCountsInGeneralStats:
            mvpCountsInGeneralStats ?? this.mvpCountsInGeneralStats,
        goalsCountInGeneralStats:
            goalsCountInGeneralStats ?? this.goalsCountInGeneralStats,
        includeInTeamDraw: includeInTeamDraw ?? this.includeInTeamDraw,
        minGamesForPlacementResult:
            minGamesForPlacementResult ?? this.minGamesForPlacementResult,
        format: format ?? this.format,
        roundRobinTurns: roundRobinTurns ?? this.roundRobinTurns,
        winnerStays: winnerStays ?? this.winnerStays,
        gameEnd: gameEnd ?? this.gameEnd,
        standings: standings ?? this.standings,
      );

  List<String> validate() {
    final errors = <String>[];
    if (resultMode == ChampionshipResultMode.perGame &&
        historyMode != ChampionshipHistoryMode.separateGames) {
      errors.add('Resultado por jogo exige histórico em jogos separados.');
    }
    if (resultMode == ChampionshipResultMode.placement &&
        placementResults.isEmpty) {
      errors.add('Informe o resultado de ao menos uma colocação.');
    }
    if (minGamesForPlacementResult < 0) {
      errors.add('O mínimo de jogos não pode ser negativo.');
    }
    if (format == ChampionshipFormat.winnerStays && winnerStays == null) {
      errors.add('Configure as regras do fica quem ganha.');
    }
    if (winnerStays != null && winnerStays!.consecutiveWinsLimit < 0) {
      errors.add('O limite de vitórias não pode ser negativo.');
    }
    if ((format == ChampionshipFormat.roundRobin ||
            format == ChampionshipFormat.roundRobinWithFinal) &&
        roundRobinTurns != 1 &&
        roundRobinTurns != 2) {
      errors.add('O número de turnos deve ser 1 ou 2.');
    }
    // Vazio ou 0 = sem limite (vai null para a API, que recusa 0).
    final time = gameEnd.timeLimitMinutes;
    final goals = gameEnd.goalLimit;
    if ((time == null || time == 0) && (goals == null || goals == 0)) {
      errors.add('Informe o tempo, os gols ou os dois.');
    }
    if ((time ?? 0) < 0 || (goals ?? 0) < 0) {
      errors.add('Tempo e gols não podem ser negativos.');
    }
    if (standings.tiebreakers.isEmpty ||
        standings.tiebreakers.first != ChampionshipTiebreakerCriteria.points) {
      errors.add('Pontos tem de ser o 1º critério de desempate.');
    }
    if (standings.tiebreakers.toSet().length != standings.tiebreakers.length) {
      errors.add('Os critérios de desempate não podem se repetir.');
    }
    if (standings.winPoints < 0 || standings.drawPoints < 0) {
      errors.add('A pontuação não pode ser negativa.');
    }
    return errors;
  }
}
