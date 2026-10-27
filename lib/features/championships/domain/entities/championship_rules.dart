import 'championship_enums.dart';

class WinnerStaysRules {
  const WinnerStaysRules({
    required this.consecutiveWinsLimit,
    required this.tieRule,
  });

  final int consecutiveWinsLimit;
  final WinnerStaysTieRule tieRule;

  factory WinnerStaysRules.fromJson(Map<String, dynamic> json) =>
      WinnerStaysRules(
        consecutiveWinsLimit: json['consecutiveWinsLimit'] as int,
        tieRule: enumByValue(WinnerStaysTieRule.values, json['tieRule'] as int),
      );

  Map<String, dynamic> toJson() => {
        'consecutiveWinsLimit': consecutiveWinsLimit,
        'tieRule': tieRule.value,
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

  Map<String, dynamic> toJson() => {
        'timeLimitMinutes': timeLimitMinutes,
        'goalLimit': goalLimit,
      };
}

class ChampionshipEndRules {
  const ChampionshipEndRules({
    required this.mode,
    this.totalTimeMinutes,
    this.numberOfGames,
  });

  final ChampionshipEndMode mode;
  final int? totalTimeMinutes;
  final int? numberOfGames;

  factory ChampionshipEndRules.fromJson(Map<String, dynamic> json) =>
      ChampionshipEndRules(
        mode: enumByValue(ChampionshipEndMode.values, json['mode'] as int),
        totalTimeMinutes: json['totalTimeMinutes'] as int?,
        numberOfGames: json['numberOfGames'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'totalTimeMinutes': totalTimeMinutes,
        'numberOfGames': numberOfGames,
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
    required this.championshipEnd,
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
  final int roundRobinTurns;
  final WinnerStaysRules? winnerStays;
  final ChampionshipGameEndRules gameEnd;
  final ChampionshipEndRules championshipEnd;
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
        championshipEnd: ChampionshipEndRules(
          mode: ChampionshipEndMode.totalTime,
          totalTimeMinutes: 120,
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
        placementResults: (json['placementResults'] as List<dynamic>)
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
        championshipEnd: ChampionshipEndRules.fromJson(
          json['championshipEnd'] as Map<String, dynamic>,
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
        'championshipEnd': championshipEnd.toJson(),
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
    ChampionshipEndRules? championshipEnd,
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
        championshipEnd: championshipEnd ?? this.championshipEnd,
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
    if (gameEnd.timeLimitMinutes == null && gameEnd.goalLimit == null) {
      errors.add('Informe tempo ou limite de gols para cada jogo.');
    }
    if ((gameEnd.timeLimitMinutes ?? 1) <= 0 || (gameEnd.goalLimit ?? 1) <= 0) {
      errors.add('Tempo e limite de gols devem ser maiores que zero.');
    }
    if (championshipEnd.mode == ChampionshipEndMode.totalTime &&
        (championshipEnd.totalTimeMinutes ?? 0) <= 0) {
      errors.add('Informe o tempo total do campeonato.');
    }
    if (championshipEnd.mode == ChampionshipEndMode.numberOfGames &&
        (championshipEnd.numberOfGames ?? 0) <= 0) {
      errors.add('Informe o número de jogos do campeonato.');
    }
    if (!standings.tiebreakers
        .contains(ChampionshipTiebreakerCriteria.points)) {
      errors.add('Os desempates precisam incluir pontos.');
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
