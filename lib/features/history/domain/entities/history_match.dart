import '../../../../core/utils/date_utils.dart';

class HistoryPodiumTeam {
  final int position;
  final String teamName;
  final String? colorHex;

  const HistoryPodiumTeam({
    required this.position,
    required this.teamName,
    this.colorHex,
  });
}

class HistoryMatch {
  final String id;
  final String groupId;
  final DateTime? playedAt;
  final int? teamAGoals;
  final int? teamBGoals;
  final String? teamAColorHex;
  final String? teamBColorHex;
  final String? teamAColorName;
  final String? teamBColorName;
  final String? statusName;
  final String? placeName;
  final String? linkedPollTitle;
  final String? linkedPollType;
  final String? kind;
  final String? championshipId;
  final String? championshipName;
  final String? championTeamName;
  final String? championTeamColorHex;
  final List<String> ruleBadges;

  /// Pódio do campeonato consolidado (1º a 3º), mostrado no lugar do placar.
  final List<HistoryPodiumTeam> podium;

  const HistoryMatch({
    required this.id,
    required this.groupId,
    this.playedAt,
    this.teamAGoals,
    this.teamBGoals,
    this.teamAColorHex,
    this.teamBColorHex,
    this.teamAColorName,
    this.teamBColorName,
    this.statusName,
    this.placeName,
    this.linkedPollTitle,
    this.linkedPollType,
    this.kind,
    this.championshipId,
    this.championshipName,
    this.championTeamName,
    this.championTeamColorHex,
    this.ruleBadges = const [],
    this.podium = const [],
  });

  bool get isConsolidatedChampionship => kind == 'championship';
  bool get isChampionshipGame => kind == 'championshipGame';
  bool get isChampionshipItem =>
      isConsolidatedChampionship || isChampionshipGame;
  bool get hasScore =>
      !isConsolidatedChampionship && teamAGoals != null && teamBGoals != null;

  factory HistoryMatch.fromJson(Map<String, dynamic> json,
      {String groupId = ''}) {
    final aHex = _hex(json['teamAColorHex']) ??
        _hex((json['teamAColor'] as Map?)?.tryGet('hexValue'));
    final bHex = _hex(json['teamBColorHex']) ??
        _hex((json['teamBColor'] as Map?)?.tryGet('hexValue'));
    final aName = (json['teamAColorName'] as String?) ??
        (json['teamAColor'] as Map?)?.tryGet('name');
    final bName = (json['teamBColorName'] as String?) ??
        (json['teamBColor'] as Map?)?.tryGet('name');

    return HistoryMatch(
      id: (json['id'] ?? json['matchId'] ?? '') as String,
      groupId: groupId,
      playedAt: AppDateUtils.parse(json['playedAt'] as String?),
      teamAGoals:
          (json['teamAGoals'] ?? json['teamAScore'] ?? json['scoreA']) as int?,
      teamBGoals:
          (json['teamBGoals'] ?? json['teamBScore'] ?? json['scoreB']) as int?,
      teamAColorHex: aHex,
      teamBColorHex: bHex,
      teamAColorName: aName as String?,
      teamBColorName: bName as String?,
      statusName:
          (json['statusName'] ?? json['status'] ?? json['stepKey']) as String?,
      placeName: json['placeName'] as String?,
      linkedPollTitle: json['linkedPollTitle'] as String?,
      linkedPollType: json['linkedPollType'] as String?,
      kind: json['kind'] as String?,
      championshipId: json['championshipId']?.toString(),
      championshipName: json['championshipName'] as String?,
      championTeamName: json['championTeamName'] as String?,
      championTeamColorHex: _hex(json['championTeamColorHex']),
      podium: (json['podium'] as List?)
              ?.whereType<Map>()
              .map((item) => HistoryPodiumTeam(
                    position: (item['position'] as num?)?.toInt() ?? 0,
                    teamName: (item['teamName'] as String?) ?? 'Time',
                    colorHex: _hex(item['colorHex']),
                  ))
              .where((item) => item.position > 0)
              .toList(growable: false) ??
          const [],
      ruleBadges: (json['ruleBadges'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
    );
  }

  static String? _hex(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s.startsWith('#') ? s : '#$s';
  }
}

extension _MapExt on Map {
  dynamic tryGet(String key) {
    try {
      return this[key];
    } catch (_) {
      return null;
    }
  }
}
