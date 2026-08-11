import '../../../../core/utils/date_utils.dart';

// ── Goal ─────────────────────────────────────────────────────────────────────

class MatchGoal {
  final String goalId;
  final String? scorerMatchPlayerId;
  final String? scorerPlayerId;
  final String? scorerName;
  final String? assistMatchPlayerId;
  final String? assistPlayerId;
  final String? assistName;
  final String? time;
  final bool isOwnGoal;

  const MatchGoal({
    required this.goalId,
    this.scorerMatchPlayerId,
    this.scorerPlayerId,
    this.scorerName,
    this.assistMatchPlayerId,
    this.assistPlayerId,
    this.assistName,
    this.time,
    this.isOwnGoal = false,
  });

  factory MatchGoal.fromJson(Map<String, dynamic> j) => MatchGoal(
        goalId: (j['goalId'] ?? '') as String,
        scorerMatchPlayerId: j['scorerMatchPlayerId'] as String?,
        scorerPlayerId: j['scorerPlayerId'] as String?,
        scorerName: j['scorerName'] as String?,
        assistMatchPlayerId: j['assistMatchPlayerId'] as String?,
        assistPlayerId: j['assistPlayerId'] as String?,
        assistName: j['assistName'] as String?,
        time: j['time'] as String?,
        isOwnGoal: (j['isOwnGoal'] as bool?) ?? false,
      );
}

// ── Player (in match) ────────────────────────────────────────────────────────

class MatchPlayer {
  final String matchPlayerId;
  final String? playerId;
  final String? userId;
  final String playerName;
  final String? photoUrl;
  final bool isGoalkeeper;
  final bool isMvp;
  final bool didNotPlay;
  final String? absenceType;
  final String? absenceDescription;
  final int team; // 1 = A, 2 = B

  const MatchPlayer({
    required this.matchPlayerId,
    this.playerId,
    this.userId,
    required this.playerName,
    this.photoUrl,
    this.isGoalkeeper = false,
    this.isMvp = false,
    this.didNotPlay = false,
    this.absenceType,
    this.absenceDescription,
    this.team = 0,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> j, {int team = 0}) =>
      MatchPlayer(
        matchPlayerId: (j['matchPlayerId'] ?? '') as String,
        playerId: j['playerId'] as String?,
        userId: (j['userId'] ?? j['UserId'])?.toString(),
        playerName: (j['playerName'] ?? '') as String,
        photoUrl: (j['photoUrl'] ?? j['PhotoUrl']) as String?,
        isGoalkeeper: (j['isGoalkeeper'] as bool?) ?? false,
        isMvp: (j['isMvp'] as bool?) ?? false,
        didNotPlay: (j['didNotPlay'] as bool?) ?? false,
        absenceType: j['absenceType'] as String?,
        absenceDescription: j['absenceDescription'] as String?,
        team: team,
      );
}

// ── Team color ───────────────────────────────────────────────────────────────

class TeamColor {
  final String? hexValue;
  final String? name;

  const TeamColor({this.hexValue, this.name});

  factory TeamColor.fromJson(Map<String, dynamic> j) => TeamColor(
        hexValue: _normalizeHex(j['hexValue'] as String?),
        name: j['name'] as String?,
      );

  static String? _normalizeHex(String? v) {
    if (v == null || v.isEmpty) return null;
    return v.startsWith('#') ? v : '#$v';
  }
}

// ── MVP ───────────────────────────────────────────────────────────────────────

class MvpVoteResult {
  final String playerName;
  final int votes;

  const MvpVoteResult({required this.playerName, required this.votes});

  factory MvpVoteResult.fromJson(Map<String, dynamic> j) => MvpVoteResult(
        playerName: (j['votedForName'] ?? j['playerName'] ?? j['name'] ?? '')
            .toString(),
        votes: (j['count'] as num? ??
                j['votes'] as num? ??
                j['voteCount'] as num? ??
                0)
            .toInt(),
      );
}

class MvpInfo {
  final String? playerName;
  final int? team;
  final List<MvpVoteResult> results;

  const MvpInfo({this.playerName, this.team, this.results = const []});

  factory MvpInfo.fromJson(Map<String, dynamic> j) => MvpInfo(
        playerName: j['playerName'] as String?,
        team: j['team'] as int?,
        results: (j['results'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(MvpVoteResult.fromJson)
                .toList() ??
            [],
      );
}

// ── Full match details ────────────────────────────────────────────────────────

class MatchDetails {
  final String matchId;
  final String? groupId;
  final int? teamAGoals;
  final int? teamBGoals;
  final TeamColor? teamAColor;
  final TeamColor? teamBColor;
  final List<MatchPlayer> teamAPlayers;
  final List<MatchPlayer> teamBPlayers;
  final List<MatchGoal> goals;
  final MvpInfo? computedMvp;
  final List<MvpVoteResult> voteCounts;
  final String? statusName;
  final String? placeName;
  final DateTime? playedAt;

  const MatchDetails({
    required this.matchId,
    this.groupId,
    this.teamAGoals,
    this.teamBGoals,
    this.teamAColor,
    this.teamBColor,
    this.teamAPlayers = const [],
    this.teamBPlayers = const [],
    this.goals = const [],
    this.computedMvp,
    this.voteCounts = const [],
    this.statusName,
    this.placeName,
    this.playedAt,
  });

  factory MatchDetails.fromJson(Map<String, dynamic> j) {
    TeamColor? parseColor(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) return TeamColor.fromJson(raw);
      return null;
    }

    List<MatchPlayer> parsePlayers(dynamic raw, int team) {
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((p) => MatchPlayer.fromJson(p, team: team))
          .toList()
        ..sort((a, b) {
          if (a.isGoalkeeper != b.isGoalkeeper) {
            return a.isGoalkeeper ? -1 : 1;
          }
          return a.playerName.compareTo(b.playerName);
        });
    }

    List<MatchGoal> parseGoals(dynamic raw) {
      if (raw is! List) return [];
      final goals = raw
          .whereType<Map<String, dynamic>>()
          .map(MatchGoal.fromJson)
          .toList();
      goals.sort((a, b) {
        final ta = _parseClock(a.time);
        final tb = _parseClock(b.time);
        return ta.compareTo(tb);
      });
      return goals;
    }

    return MatchDetails(
      matchId: (j['id'] ?? j['matchId'] ?? '') as String,
      groupId: j['groupId'] as String?,
      teamAGoals: j['teamAGoals'] as int?,
      teamBGoals: j['teamBGoals'] as int?,
      teamAColor: parseColor(j['teamAColor']),
      teamBColor: parseColor(j['teamBColor']),
      teamAPlayers: parsePlayers(j['teamAPlayers'], 1),
      teamBPlayers: parsePlayers(j['teamBPlayers'], 2),
      goals: parseGoals(j['goals']),
      computedMvp: j['computedMvp'] != null
          ? MvpInfo.fromJson(j['computedMvp'] as Map<String, dynamic>)
          : null,
      voteCounts: ((j['voteCounts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MvpVoteResult.fromJson)
              .toList() ??
          [])
        ..sort((a, b) => b.votes.compareTo(a.votes)),
      statusName: (j['statusName'] ?? j['status']) as String?,
      placeName: j['placeName'] as String?,
      playedAt: AppDateUtils.parse(j['playedAt'] as String?),
    );
  }
}

// clock → comparable minutes
int _parseClock(String? t) {
  if (t == null || t.isEmpty) return 9999;
  final parts = t.split(':');
  if (parts.length < 2) return 9999;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}
