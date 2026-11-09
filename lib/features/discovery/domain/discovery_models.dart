class DiscoveryGroupItem {
  const DiscoveryGroupItem({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.city,
    required this.accepting,
    required this.members,
  });
  final String id, name, code;
  final String? logoUrl, city;
  final bool accepting;
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
      );
}

class DiscoveryPlayerItem {
  const DiscoveryPlayerItem({
    required this.id,
    required this.name,
    required this.userName,
    this.photoUrl,
    this.position,
  });
  final String id, name, userName;
  final String? photoUrl, position;
  factory DiscoveryPlayerItem.fromJson(Map<String, dynamic> j) =>
      DiscoveryPlayerItem(
        id: j['userId'] as String,
        name: j['name'] as String,
        userName: j['userName'] as String,
        photoUrl: j['photoUrl'] as String?,
        position: j['position'] as String?,
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
  });
  final String id;
  final DateTime playedAt;
  final String? placeName;
  final int? applicationStatus;
  final List<MatchOpening> openings;
  factory DiscoveryMatch.fromJson(Map<String, dynamic> j) => DiscoveryMatch(
        id: j['matchId'] as String,
        playedAt: DateTime.parse(j['playedAt'] as String).toLocal(),
        placeName: j['placeName'] as String?,
        applicationStatus: (j['applicationStatus'] as num?)?.toInt(),
        openings: ((j['openings'] as List?) ?? [])
            .map((e) =>
                MatchOpening.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
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
    required this.members,
    required this.isPublic,
    required this.accepting,
    required this.showMembers,
    required this.matches,
    required this.people,
  });
  final String id, name, code;
  final String? logoUrl, description, city;
  final int members;
  final bool isPublic, accepting, showMembers;
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
        members: (j['memberCount'] as num?)?.toInt() ?? 0,
        isPublic: j['isPublic'] != false,
        accepting: j['isAcceptingPlayers'] == true,
        showMembers: j['showMembers'] == true,
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
    this.photoUrl,
    this.placeName,
    required this.playedAt,
    required this.status,
    this.position,
  });
  final String id, userId, name, userName, groupName;
  final String? photoUrl, placeName;
  final DateTime playedAt;
  final int status;
  final int? position;
  factory MatchApplication.fromJson(Map<String, dynamic> j) => MatchApplication(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['playerName'] as String,
        userName: j['userName'] as String,
        groupName: j['groupName'] as String? ?? '',
        photoUrl: j['photoUrl'] as String?,
        placeName: j['placeName'] as String?,
        playedAt: DateTime.parse(j['playedAt'] as String).toLocal(),
        status: (j['status'] as num).toInt(),
        position: (j['openingPosition'] as num?)?.toInt(),
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
