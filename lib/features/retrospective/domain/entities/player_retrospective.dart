// Espelho de PlayerRetrospectiveDto (API: docs/retrospectiva/RETROSPECTIVA.md).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
Map<String, dynamic>? _m(dynamic v) => v is Map<String, dynamic> ? v : null;
List<Map<String, dynamic>> _l(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
DateTime _dt(dynamic v) =>
    DateTime.tryParse(_s(v))?.toUtc() ?? DateTime.utc(1970);

class RetroPlayerOption {
  final String playerId;
  final String name;
  final String shortName;
  final int games;

  const RetroPlayerOption(
      {required this.playerId,
      required this.name,
      required this.shortName,
      required this.games});

  factory RetroPlayerOption.fromJson(Map<String, dynamic> j) =>
      RetroPlayerOption(
        playerId: _s(j['playerId']),
        name: _s(j['name']),
        shortName: _s(j['shortName']),
        games: _i(j['games']),
      );
}

class RetroPeriod {
  final int? year;
  final String label;
  final bool isPartial;

  const RetroPeriod({this.year, required this.label, required this.isPartial});

  factory RetroPeriod.fromJson(Map<String, dynamic> j) => RetroPeriod(
      year: _in(j['year']),
      label: _s(j['label']),
      isPartial: j['isPartial'] == true);
}

class RetroNight {
  final int count;
  final DateTime playedAt;

  const RetroNight(this.count, this.playedAt);

  static RetroNight? fromJson(Map<String, dynamic>? j) =>
      j == null ? null : RetroNight(_i(j['count']), _dt(j['playedAt']));
}

class RetroCountRef {
  final String name;
  final int count;

  const RetroCountRef(this.name, this.count);

  static RetroCountRef? fromJson(Map<String, dynamic>? j) =>
      j == null ? null : RetroCountRef(_s(j['name']), _i(j['count']));
}

/// Retrospecto (V-E-D) com alguém: parceiro ou rival.
class RetroRecord {
  final String playerId;
  final String name;
  final int games;
  final int wins;
  final int draws;
  final int losses;
  final int aproveitamento;

  const RetroRecord({
    required this.playerId,
    required this.name,
    this.games = 0,
    required this.wins,
    required this.draws,
    required this.losses,
    this.aproveitamento = 0,
  });

  static RetroRecord? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : RetroRecord(
          playerId: _s(j['playerId']),
          name: _s(j['name']),
          games: _i(j['games']),
          wins: _i(j['wins']),
          draws: _i(j['draws']),
          losses: _i(j['losses']),
          aproveitamento: _i(j['aproveitamento']),
        );
}

class RetroBestMonth {
  final int year;
  final int month;
  final int wins;
  final int draws;
  final int losses;

  const RetroBestMonth(
      this.year, this.month, this.wins, this.draws, this.losses);

  static RetroBestMonth? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : RetroBestMonth(_i(j['year']), _i(j['month']), _i(j['wins']),
          _i(j['draws']), _i(j['losses']));
}

class RetroMonth {
  final int year;
  final int month;
  final int goals;
  final int assists;

  const RetroMonth(this.year, this.month, this.goals, this.assists);
}

class RetroMilestone {
  final String kind;
  final int number;
  final DateTime playedAt;

  const RetroMilestone(this.kind, this.number, this.playedAt);
}

class PlayerRetrospective {
  final String groupName;
  final RetroPeriod period;
  final List<int> availableYears;
  final List<RetroPlayerOption> players;
  final RetroPlayerOption player;
  final bool isGoalkeeper;
  final int totalGames;
  final int minGamesForRates;
  final int ratedPlayers;

  final int games;
  final int presencePercent;
  final int? presenceRank;
  final int longestPresenceStreak;

  final int wins;
  final int draws;
  final int losses;
  final int aproveitamento;
  final int? resultsRank;
  final int longestWinStreak;
  final int longestUnbeatenStreak;
  final RetroBestMonth? bestMonth;

  final int goals;
  final int? goalsRank;
  final RetroNight? bestGoalNight;
  final int assists;
  final int? assistsRank;
  final RetroNight? bestAssistNight;
  final RetroCountRef? mostAssistedTo;
  final RetroCountRef? mostAssistedBy;
  final List<RetroMonth> months;

  final int openers;
  final int winningGoals;
  final int? decisivePerGameRank;

  final RetroRecord? bestPartner;
  final RetroRecord? frequentPartner;
  final RetroRecord? fregues;
  final RetroRecord? carrasco;

  final List<RetroMilestone> milestones;
  final int mvps;
  final int mvpVotes;
  final int? mvpRank;
  final int ownGoals;

  final String profileKey;
  final double goalsPerGame;
  final int? goalsPerGameRank;
  final double assistsPerGame;
  final int? assistsPerGameRank;
  final int goalkeeperGames;

  const PlayerRetrospective({
    required this.groupName,
    required this.period,
    this.availableYears = const [],
    this.players = const [],
    required this.player,
    this.isGoalkeeper = false,
    required this.totalGames,
    this.minGamesForRates = 3,
    this.ratedPlayers = 0,
    required this.games,
    this.presencePercent = 0,
    this.presenceRank,
    this.longestPresenceStreak = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.aproveitamento = 0,
    this.resultsRank,
    this.longestWinStreak = 0,
    this.longestUnbeatenStreak = 0,
    this.bestMonth,
    this.goals = 0,
    this.goalsRank,
    this.bestGoalNight,
    this.assists = 0,
    this.assistsRank,
    this.bestAssistNight,
    this.mostAssistedTo,
    this.mostAssistedBy,
    this.months = const [],
    this.openers = 0,
    this.winningGoals = 0,
    this.decisivePerGameRank,
    this.bestPartner,
    this.frequentPartner,
    this.fregues,
    this.carrasco,
    this.milestones = const [],
    this.mvps = 0,
    this.mvpVotes = 0,
    this.mvpRank,
    this.ownGoals = 0,
    this.profileKey = 'fiel',
    this.goalsPerGame = 0,
    this.goalsPerGameRank,
    this.assistsPerGame = 0,
    this.assistsPerGameRank,
    this.goalkeeperGames = 0,
  });

  int get results => wins + draws + losses;

  factory PlayerRetrospective.fromJson(Map<String, dynamic> j) {
    final presence = _m(j['presence']) ?? const {};
    final res = _m(j['results']) ?? const {};
    final g = _m(j['goals']) ?? const {};
    final a = _m(j['assists']) ?? const {};
    final dec = _m(j['decisive']) ?? const {};
    final mvp = _m(j['mvp']) ?? const {};
    final prof = _m(j['profile']) ?? const {};
    return PlayerRetrospective(
      groupName: _s(j['groupName']),
      period: RetroPeriod.fromJson(_m(j['period']) ?? const {}),
      availableYears:
          (j['availableYears'] as List? ?? const []).map(_i).toList(),
      players: _l(j['players']).map(RetroPlayerOption.fromJson).toList(),
      player: RetroPlayerOption.fromJson(_m(j['player']) ?? const {}),
      isGoalkeeper: j['isGoalkeeper'] == true,
      totalGames: _i(j['totalGames']),
      minGamesForRates: _i(j['minGamesForRates']),
      ratedPlayers: _i(j['ratedPlayers']),
      games: _i(presence['games']),
      presencePercent: _i(presence['percent']),
      presenceRank: _in(presence['rank']),
      longestPresenceStreak: _i(presence['longestStreak']),
      wins: _i(res['wins']),
      draws: _i(res['draws']),
      losses: _i(res['losses']),
      aproveitamento: _i(res['aproveitamento']),
      resultsRank: _in(res['rank']),
      longestWinStreak: _i(res['longestWinStreak']),
      longestUnbeatenStreak: _i(res['longestUnbeatenStreak']),
      bestMonth: RetroBestMonth.fromJson(_m(res['bestMonth'])),
      goals: _i(g['total']),
      goalsRank: _in(g['rank']),
      bestGoalNight: RetroNight.fromJson(_m(g['bestNight'])),
      assists: _i(a['total']),
      assistsRank: _in(a['rank']),
      bestAssistNight: RetroNight.fromJson(_m(a['bestNight'])),
      mostAssistedTo: RetroCountRef.fromJson(_m(a['mostAssistedTo'])),
      mostAssistedBy: RetroCountRef.fromJson(_m(a['mostAssistedBy'])),
      months: _l(j['months'])
          .map((m) => RetroMonth(
              _i(m['year']), _i(m['month']), _i(m['goals']), _i(m['assists'])))
          .toList(),
      openers: _i(dec['openers']),
      winningGoals: _i(dec['winningGoals']),
      decisivePerGameRank: _in(dec['perGameRank']),
      bestPartner: RetroRecord.fromJson(_m(j['bestPartner'])),
      frequentPartner: RetroRecord.fromJson(_m(j['frequentPartner'])),
      fregues: RetroRecord.fromJson(_m(j['fregues'])),
      carrasco: RetroRecord.fromJson(_m(j['carrasco'])),
      milestones: _l(j['milestones'])
          .map((m) => RetroMilestone(
              _s(m['kind']), _i(m['number']), _dt(m['playedAt'])))
          .toList(),
      mvps: _i(mvp['mvps']),
      mvpVotes: _i(mvp['votes']),
      mvpRank: _in(mvp['rank']),
      ownGoals: _i(j['ownGoals']),
      profileKey: _s(prof['key']).isEmpty ? 'fiel' : _s(prof['key']),
      goalsPerGame: _d(prof['goalsPerGame']),
      goalsPerGameRank: _in(prof['goalsPerGameRank']),
      assistsPerGame: _d(prof['assistsPerGame']),
      assistsPerGameRank: _in(prof['assistsPerGameRank']),
      goalkeeperGames: _i(prof['goalkeeperGames']),
    );
  }
}
