class DiscoveryGroupItem {
  const DiscoveryGroupItem({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.city,
    required this.accepting,
    required this.members,
    this.isMember = false,
    this.isPublic = true,
  });
  final String id, name, code;
  final String? logoUrl, city;
  final bool accepting, isMember, isPublic;
  final int members;
  factory DiscoveryGroupItem.fromJson(Map<String, dynamic> j) =>
      DiscoveryGroupItem(
        id: j['groupId'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logoUrl'] as String?,
        city: j['city'] as String?,
        accepting: j['isAcceptingPlayers'] == true,
        members: (j['memberCount'] as num?)?.toInt() ?? 0,
        isMember: j['isMember'] == true,
        isPublic: j['isPublic'] == true,
      );
}

class DiscoveryPlayerItem {
  const DiscoveryPlayerItem({
    required this.id,
    required this.name,
    required this.userName,
    this.photoUrl,
    this.position,
    this.inGroup = false,
  });
  final String id, name, userName;
  final String? photoUrl, position;

  /// Já é mensalista da patota ativa de quem busca.
  final bool inGroup;
  factory DiscoveryPlayerItem.fromJson(Map<String, dynamic> j) =>
      DiscoveryPlayerItem(
        id: j['userId'] as String,
        name: j['name'] as String,
        userName: j['userName'] as String,
        photoUrl: j['photoUrl'] as String?,
        position: j['position'] as String?,
        inGroup: j['inGroup'] == true,
      );
}

class MatchOpening {
  const MatchOpening({
    required this.id,
    required this.slots,
    required this.available,
    required this.position,
  });
  final String id;
  final int slots, available, position;
  factory MatchOpening.fromJson(Map<String, dynamic> j) => MatchOpening(
        id: j['openingId'] as String,
        slots: (j['slots'] as num).toInt(),
        available: (j['availableSlots'] as num).toInt(),
        position: (j['position'] as num).toInt(),
      );
  String get label => position == 2
      ? 'Linha'
      : position == 3
          ? 'Goleiro'
          : 'Qualquer posição';
}

class DiscoveryMatch {
  const DiscoveryMatch({
    required this.id,
    required this.playedAt,
    this.placeName,
    this.applicationStatus,
    required this.openings,
    this.participating = false,
  });
  final String id;
  final DateTime playedAt;
  final String? placeName;
  final int? applicationStatus;
  final List<MatchOpening> openings;

  /// O visitante já está confirmado nesta partida (mensalista ou convidado).
  final bool participating;
  factory DiscoveryMatch.fromJson(Map<String, dynamic> j) => DiscoveryMatch(
        id: j['matchId'] as String,
        playedAt: DateTime.parse(j['playedAt'] as String).toLocal(),
        placeName: j['placeName'] as String?,
        applicationStatus: (j['applicationStatus'] as num?)?.toInt(),
        openings: ((j['openings'] as List?) ?? [])
            .map((e) =>
                MatchOpening.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        participating: j['participating'] == true,
      );
}

class DiscoveryGroupProfile {
  const DiscoveryGroupProfile({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.description,
    this.city,
    this.defaultDayOfWeek,
    this.defaultKickoffTime,
    required this.members,
    required this.isPublic,
    required this.accepting,
    required this.showMembers,
    this.showGoalsToGuests = false,
    required this.matches,
    required this.people,
  });
  final String id, name, code;
  final String? logoUrl, description, city;
  final int? defaultDayOfWeek;
  final String? defaultKickoffTime;
  final int members;
  final bool isPublic, accepting, showMembers, showGoalsToGuests;
  final List<DiscoveryMatch> matches;
  final List<DiscoveryPlayerItem> people;
  factory DiscoveryGroupProfile.fromJson(Map<String, dynamic> j) =>
      DiscoveryGroupProfile(
        id: j['groupId'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logoUrl'] as String?,
        description: j['description'] as String?,
        city: j['city'] as String?,
        defaultDayOfWeek: (j['defaultDayOfWeek'] as num?)?.toInt(),
        defaultKickoffTime: j['defaultKickoffTime'] as String?,
        members: (j['memberCount'] as num?)?.toInt() ?? 0,
        isPublic: j['isPublic'] != false,
        accepting: j['isAcceptingPlayers'] == true,
        showMembers: j['showMembers'] == true,
        showGoalsToGuests: j['showGoalsToGuests'] == true,
        matches: ((j['upcomingMatches'] as List?) ?? [])
            .map(
              (e) =>
                  DiscoveryMatch.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        people: ((j['members'] as List?) ?? [])
            .map(
              (e) => DiscoveryPlayerItem.fromJson({
                ...Map<String, dynamic>.from(e as Map),
                'position': null,
              }),
            )
            .toList(),
      );
}

class MatchApplication {
  const MatchApplication({
    required this.id,
    required this.userId,
    required this.name,
    required this.userName,
    required this.groupName,
    this.groupId = '',
    this.matchId = '',
    this.matchStatus = 0,
    this.photoUrl,
    this.placeName,
    required this.playedAt,
    required this.status,
    required this.source,
    this.position,
    this.message,
    this.decisionReason,
  });
  final String id, userId, name, userName, groupName;
  final String groupId, matchId;

  /// Situação da partida (4 = encerrada, 5 = pós-jogo, 6 = finalizada).
  final int matchStatus;
  final String? photoUrl, placeName;
  final DateTime playedAt;
  final int status;

  /// 1 = candidatura do jogador; 2 = convite direto da patota.
  final int source;
  final int? position;
  final String? message, decisionReason;
  factory MatchApplication.fromJson(Map<String, dynamic> j) => MatchApplication(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['playerName'] as String,
        userName: j['userName'] as String,
        groupName: j['groupName'] as String? ?? '',
        groupId: j['groupId'] as String? ?? '',
        matchId: j['matchId'] as String? ?? '',
        matchStatus: (j['matchStatus'] as num?)?.toInt() ?? 0,
        photoUrl: j['photoUrl'] as String?,
        placeName: j['placeName'] as String?,
        playedAt: DateTime.parse(j['playedAt'] as String).toLocal(),
        status: (j['status'] as num).toInt(),
        source: (j['source'] as num?)?.toInt() ?? 1,
        position: (j['openingPosition'] as num?)?.toInt(),
        message: j['message'] as String?,
        decisionReason: j['decisionReason'] as String?,
      );
}

class GuestCandidate {
  const GuestCandidate({
    required this.id,
    required this.name,
    required this.origin,
    required this.linked,
  });
  final String id, name;
  final int origin;
  final bool linked;
  factory GuestCandidate.fromJson(Map<String, dynamic> j) => GuestCandidate(
        id: j['playerId'] as String,
        name: j['name'] as String,
        origin: (j['origin'] as num).toInt(),
        linked: j['linkedToThisUser'] == true,
      );
}

class GuestMatchColor {
  const GuestMatchColor({required this.name, required this.hexValue});
  final String name, hexValue;
  factory GuestMatchColor.fromJson(Map<String, dynamic> j) => GuestMatchColor(
        name: j['name'] as String? ?? '',
        hexValue: j['hexValue'] as String? ?? '',
      );
}

class GuestMatchPlayer {
  const GuestMatchPlayer({
    required this.name,
    this.photoUrl,
    required this.team,
    required this.isGoalkeeper,
    required this.isMe,
    this.isMvp = false,
  });
  final String name;
  final String? photoUrl;
  final int team;
  final bool isGoalkeeper, isMe, isMvp;
  factory GuestMatchPlayer.fromJson(Map<String, dynamic> j) => GuestMatchPlayer(
        name: j['name'] as String? ?? '',
        photoUrl: j['photoUrl'] as String?,
        team: (j['team'] as num?)?.toInt() ?? 0,
        isGoalkeeper: j['isGoalkeeper'] == true,
        isMe: j['isMe'] == true,
        isMvp: j['isMvp'] == true,
      );
}

/// Partida vista por quem foi aceito como convidado (somente leitura).
class GuestMatch {
  const GuestMatch({
    required this.groupName,
    required this.matchId,
    required this.playedAt,
    this.placeName,
    required this.matchStatus,
    this.teamAGoals,
    this.teamBGoals,
    this.teamAColor,
    this.teamBColor,
    required this.myResponse,
    required this.canChangeAttendance,
    required this.players,
    this.goalsVisible = false,
    this.goals = const [],
    this.myGoals,
    this.myAssists,
  });
  final String groupName, matchId;
  final DateTime playedAt;
  final String? placeName;
  final int matchStatus;
  final int? teamAGoals, teamBGoals;
  final GuestMatchColor? teamAColor, teamBColor;

  /// "pending", "going", "waiting" ou "not_going".
  final String myResponse;
  final bool canChangeAttendance;
  final List<GuestMatchPlayer> players;

  /// A patota habilitou a exibição de gols para convidados.
  final bool goalsVisible;
  final List<GuestMatchGoal> goals;
  final int? myGoals, myAssists;

  static GuestMatchColor? _color(Object? v) =>
      v is Map ? GuestMatchColor.fromJson(Map<String, dynamic>.from(v)) : null;

  factory GuestMatch.fromJson(Map<String, dynamic> j) => GuestMatch(
        groupName: j['groupName'] as String? ?? '',
        matchId: j['matchId'] as String,
        playedAt: DateTime.parse(j['playedAt'] as String).toLocal(),
        placeName: j['placeName'] as String?,
        matchStatus: (j['matchStatus'] as num?)?.toInt() ?? 0,
        teamAGoals: (j['teamAGoals'] as num?)?.toInt(),
        teamBGoals: (j['teamBGoals'] as num?)?.toInt(),
        teamAColor: _color(j['teamAColor']),
        teamBColor: _color(j['teamBColor']),
        myResponse: j['myResponse'] as String? ?? 'pending',
        canChangeAttendance: j['canChangeAttendance'] == true,
        players: ((j['players'] as List?) ?? [])
            .map((e) =>
                GuestMatchPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        goalsVisible: j['goalsVisible'] == true,
        goals: ((j['goals'] as List?) ?? [])
            .map((e) =>
                GuestMatchGoal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        myGoals: (j['myGoals'] as num?)?.toInt(),
        myAssists: (j['myAssists'] as num?)?.toInt(),
      );
}

class GuestMatchGoal {
  const GuestMatchGoal({
    required this.scorer,
    this.assist,
    required this.team,
    required this.ownGoal,
  });
  final String scorer;
  final String? assist;
  final int team;
  final bool ownGoal;
  factory GuestMatchGoal.fromJson(Map<String, dynamic> j) => GuestMatchGoal(
        scorer: j['scorer'] as String? ?? '',
        assist: j['assist'] as String?,
        team: (j['team'] as num?)?.toInt() ?? 0,
        ownGoal: j['ownGoal'] == true,
      );
}
