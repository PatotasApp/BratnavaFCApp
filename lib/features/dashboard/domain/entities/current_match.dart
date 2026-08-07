import 'package:equatable/equatable.dart';
import '../../../../core/utils/date_utils.dart';

class TeamColor extends Equatable {
  final String id;
  final String name;
  final String hexValue;

  const TeamColor({
    required this.id,
    required this.name,
    required this.hexValue,
  });

  factory TeamColor.fromJson(Map<String, dynamic> j) {
    String normalizeHex(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return '#94A3B8';
      return s.startsWith('#') ? s : '#$s';
    }

    return TeamColor(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      hexValue: normalizeHex(j['hexValue'] as String?),
    );
  }

  @override
  List<Object?> get props => [id, name, hexValue];
}

enum InviteResponse { pending, accepted, declined }

class MatchPlayer extends Equatable {
  final String matchPlayerId;
  final String playerId;
  final String playerName;
  final bool isGoalkeeper;
  final int team; // 0 = unassigned, 1 = teamA, 2 = teamB
  final InviteResponse inviteResponse;

  const MatchPlayer({
    required this.matchPlayerId,
    required this.playerId,
    required this.playerName,
    required this.isGoalkeeper,
    required this.team,
    required this.inviteResponse,
  });

  /// [teamOverride] forces the team value (used when player comes from a
  /// named array like teamAPlayers and does not carry a `team` field).
  factory MatchPlayer.fromJson(Map<String, dynamic> j, {int? teamOverride}) =>
      MatchPlayer(
        matchPlayerId: j['matchPlayerId'] as String? ?? '',
        playerId: j['playerId'] as String? ?? '',
        playerName: j['playerName'] as String? ?? '',
        isGoalkeeper: j['isGoalkeeper'] as bool? ?? false,
        team: teamOverride ?? (j['team'] as int? ?? 0),
        inviteResponse: _parseInvite(j['inviteResponse'] as int? ?? 1),
      );

  // 1=Pendente  2=Recusado  3=Confirmado  (igual ao site)
  static InviteResponse _parseInvite(int v) => switch (v) {
        3 => InviteResponse.accepted,
        2 => InviteResponse.declined,
        _ => InviteResponse.pending,
      };

  @override
  List<Object?> get props =>
      [matchPlayerId, playerId, playerName, isGoalkeeper, team, inviteResponse];
}

class CurrentMatch extends Equatable {
  final String matchId;
  final String groupId;
  final DateTime playedAt;
  final String placeName;
  final int status;
  final String statusName;

  /// Chave da etapa atual: create | accept | teams | playing | ended | post | done
  final String stepKey;
  final int teamAGoals;
  final int teamBGoals;
  final TeamColor? teamAColor;
  final TeamColor? teamBColor;
  final List<MatchPlayer> players;

  /// Id da votação/evento vinculado a esta partida (null = sem vínculo).
  final String? linkedPollId;

  const CurrentMatch({
    required this.matchId,
    required this.groupId,
    required this.playedAt,
    required this.placeName,
    required this.status,
    required this.statusName,
    this.stepKey = 'create',
    required this.teamAGoals,
    required this.teamBGoals,
    this.teamAColor,
    this.teamBColor,
    this.players = const [],
    this.linkedPollId,
  });

  factory CurrentMatch.fromJson(Map<String, dynamic> j) {
    // Parse a nested color object — tries multiple key names the API may use.
    TeamColor? parseColor(dynamic c) {
      if (c == null) return null;
      if (c is Map<String, dynamic>) return TeamColor.fromJson(c);
      return null;
    }

    // Parse a player list, stamping every player with [team] so counts work
    // even when the backend omits the `team` field inside each player object.
    List<MatchPlayer> parsePlayers(dynamic raw, int team) {
      if (raw == null || raw is! List) return [];
      return (raw)
          .whereType<Map<String, dynamic>>()
          .map((e) => MatchPlayer.fromJson(e, teamOverride: team))
          .toList();
    }

    // Support multiple field-name conventions for colors.
    final colorARaw = j['teamAColor'] ?? j['colorTeamA'] ?? j['colorA'];
    final colorBRaw = j['teamBColor'] ?? j['colorTeamB'] ?? j['colorB'];

    // Support multiple field-name conventions for player arrays.
    final aPlayers = parsePlayers(
        j['teamAPlayers'] ?? j['playersTeamA'] ?? j['playersA'], 1);
    final bPlayers = parsePlayers(
        j['teamBPlayers'] ?? j['playersTeamB'] ?? j['playersB'], 2);
    final unassigned =
        parsePlayers(j['unassignedPlayers'] ?? j['pendingPlayers'], 0);

    // Fallback: flat `players` list where each object carries its own `team`.
    final allPlayers =
        (aPlayers.isEmpty && bPlayers.isEmpty && unassigned.isEmpty)
            ? parsePlayers(j['players'] ?? j['matchPlayers'], 0)
                .map((p) => p.team != 0
                    ? p
                    : MatchPlayer.fromJson({
                        'team': 0,
                        'playerName': p.playerName,
                        'playerId': p.playerId,
                        'matchPlayerId': p.matchPlayerId,
                        'isGoalkeeper': p.isGoalkeeper
                      }))
                .toList()
            : [...aPlayers, ...bPlayers, ...unassigned];

    final statusInt = j['status'] as int? ?? 0;
    final statusName =
        j['statusName'] as String? ?? _statusNameFromInt(statusInt);

    final rawKey = j['stepKey'] as String? ?? j['StepKey'] as String?;
    final stepKey = rawKey ?? _stepKeyFromStatus(statusInt);

    return CurrentMatch(
      matchId: j['matchId'] as String? ?? j['id'] as String? ?? '',
      groupId: j['groupId'] as String? ?? '',
      playedAt: _parseDate(j['playedAt'] as String?),
      placeName: j['placeName'] as String? ?? '',
      status: statusInt,
      statusName: statusName,
      stepKey: stepKey,
      teamAGoals: j['teamAGoals'] as int? ?? 0,
      teamBGoals: j['teamBGoals'] as int? ?? 0,
      teamAColor: parseColor(colorARaw),
      teamBColor: parseColor(colorBRaw),
      players: allPlayers,
      linkedPollId: (j['linkedPollId'] ?? j['LinkedPollId'])?.toString(),
    );
  }

  @override
  List<Object?> get props => [matchId, status, teamAGoals, teamBGoals];
}

/// Maps the integer status code to its stepKey string.
/// Must match MatchStepKeys constants on the backend.
String _stepKeyFromStatus(int status) => switch (status) {
      1 => 'accept',
      2 => 'teams',
      3 => 'playing',
      4 => 'post',
      5 => 'done',
      6 => 'done',
      _ => 'create',
    };

/// Maps the integer status code the API returns to a human-readable label.
String _statusNameFromInt(int status) => switch (status) {
      0 => 'Agendada',
      1 => 'Aceite',
      2 => 'Aceite',
      3 => 'Em Jogo',
      4 => 'Pós-Jogo',
      5 => 'Encerrada',
      _ => 'Agendada',
    };

DateTime _parseDate(String? s) => parseApiDate(s);
