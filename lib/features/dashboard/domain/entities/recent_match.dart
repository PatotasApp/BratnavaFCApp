import 'package:equatable/equatable.dart';
import 'current_match.dart';
import '../../../../core/utils/date_utils.dart';

enum MatchOutcome { win, draw, loss, presence }

class RecentMatch extends Equatable {
  final String matchId;
  final DateTime playedAt;
  final String placeName;
  final int goals;
  final int assists;
  final bool isMvp;
  final MatchOutcome outcome;
  final TeamColor? myTeamColor;
  final TeamColor? opponentColor;
  final int myTeamGoals;
  final int opponentGoals;
  final String? kind;
  final String? championshipId;
  final String? championshipName;

  const RecentMatch({
    required this.matchId,
    required this.playedAt,
    required this.placeName,
    required this.goals,
    required this.assists,
    this.isMvp = false,
    required this.outcome,
    this.myTeamColor,
    this.opponentColor,
    required this.myTeamGoals,
    required this.opponentGoals,
    this.kind,
    this.championshipId,
    this.championshipName,
  });

  bool get isConsolidatedChampionship => kind == 'championship';
  bool get isChampionshipGame => kind == 'championshipGame';
  bool get isChampionshipItem =>
      isConsolidatedChampionship || isChampionshipGame;

  factory RecentMatch.fromJson(Map<String, dynamic> j) {
    // Tenta objeto aninhado; cai para campos flat (teamAColorHex / teamAColorName)
    TeamColor? parseColor(dynamic nested, String hexKey, String nameKey) {
      if (nested != null && nested is Map<String, dynamic>) {
        return TeamColor.fromJson(nested);
      }
      final hex = j[hexKey] as String?;
      final name = j[nameKey] as String?;
      if (hex == null && name == null) return null;
      return TeamColor(id: '', name: name ?? '', hexValue: hex ?? '');
    }

    final myTeam = j['playerTeam'] as int? ?? 1;
    final teamAGoals = j['teamAGoals'] as int? ?? 0;
    final teamBGoals = j['teamBGoals'] as int? ?? 0;
    final myGoals = myTeam == 1 ? teamAGoals : teamBGoals;
    final oppGoals = myTeam == 1 ? teamBGoals : teamAGoals;

    final outcome = _outcomeFromApi(j['playerResult'] as String?) ??
        (myGoals > oppGoals
            ? MatchOutcome.win
            : myGoals < oppGoals
                ? MatchOutcome.loss
                : MatchOutcome.draw);

    return RecentMatch(
      matchId: j['matchId'] as String? ?? '',
      playedAt: _parseDate(j['playedAt'] as String?),
      placeName: j['placeName'] as String? ?? '',
      // Aceita tanto playerGoals/playerAssists quanto goals/assists
      goals: (j['playerGoals'] ?? j['goals']) as int? ?? 0,
      assists: (j['playerAssists'] ?? j['assists']) as int? ?? 0,
      isMvp: j['isMvp'] as bool? ?? j['IsMvp'] as bool? ?? false,
      outcome: outcome,
      myTeamColor: parseColor(
        myTeam == 1 ? j['teamAColor'] : j['teamBColor'],
        myTeam == 1 ? 'teamAColorHex' : 'teamBColorHex',
        myTeam == 1 ? 'teamAColorName' : 'teamBColorName',
      ),
      opponentColor: parseColor(
        myTeam == 1 ? j['teamBColor'] : j['teamAColor'],
        myTeam == 1 ? 'teamBColorHex' : 'teamAColorHex',
        myTeam == 1 ? 'teamBColorName' : 'teamAColorName',
      ),
      myTeamGoals: myGoals,
      opponentGoals: oppGoals,
      kind: j['kind'] as String?,
      championshipId: j['championshipId']?.toString(),
      championshipName: j['championshipName'] as String?,
    );
  }

  @override
  List<Object?> get props => [matchId, playedAt, outcome];
}

MatchOutcome? _outcomeFromApi(String? value) => switch (value?.toUpperCase()) {
      'W' => MatchOutcome.win,
      'D' => MatchOutcome.draw,
      'L' => MatchOutcome.loss,
      'N' => MatchOutcome.presence,
      _ => null,
    };

DateTime _parseDate(String? s) => parseApiDate(s);
