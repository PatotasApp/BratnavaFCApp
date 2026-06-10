import 'package:flutter/material.dart';

// ── Category labels & multipliers ────────────────────────────────────────────

const kCategoryLabels = <String, String>{
  'WinningTeam':   'Time vencedor',
  'FinalScore':    'Placar final',
  'PlayerGoals':   'Gols de jogador',
  'PlayerAssists': 'Assistências de jogador',
};

const kCategoryMultipliers = <String, String>{
  'WinningTeam':   '×1 (ou ×2.5 se Empate)',
  'FinalScore':    '×4 (exato) | reembolso ±1 gol',
  'PlayerGoals':   '×2.5 (exato) | reembolso ±1',
  'PlayerAssists': '×2.5 (exato) | reembolso ±1',
};

const kMaxWager = 200;

// ── BetPlayer ─────────────────────────────────────────────────────────────────

class BetPlayer {
  final String  matchPlayerId;
  final String  playerId;
  final String  name;
  final int     team; // 0=unassigned, 1=TeamA, 2=TeamB
  final bool    isGuest;
  final bool    hasBet;
  final int?    totalFichasWagered;

  const BetPlayer({
    required this.matchPlayerId,
    required this.playerId,
    required this.name,
    required this.team,
    required this.isGuest,
    required this.hasBet,
    this.totalFichasWagered,
  });

  factory BetPlayer.fromJson(Map<String, dynamic> j) => BetPlayer(
    matchPlayerId:     j['matchPlayerId'] as String? ?? '',
    playerId:          j['playerId']      as String? ?? '',
    name:              j['name']          as String? ?? '',
    team:              (j['team']         as num?)?.toInt() ?? 0,
    isGuest:           j['isGuest']       as bool?   ?? false,
    hasBet:            j['hasBet']        as bool?   ?? false,
    totalFichasWagered:(j['totalFichasWagered'] as num?)?.toInt(),
  );
}

// ── BetSelectionDto ───────────────────────────────────────────────────────────

class BetSelectionDto {
  final String  id;
  final String  category;
  final String  predictedValue;
  final String? actualValue;
  final int     fichasWagered;
  final int?    fichasEarned;
  final bool?   isCorrect;
  final bool?   isPartialCredit;

  const BetSelectionDto({
    required this.id,
    required this.category,
    required this.predictedValue,
    this.actualValue,
    required this.fichasWagered,
    this.fichasEarned,
    this.isCorrect,
    this.isPartialCredit,
  });

  factory BetSelectionDto.fromJson(Map<String, dynamic> j) => BetSelectionDto(
    id:             j['id']             as String? ?? '',
    category:       j['category']       as String? ?? '',
    predictedValue: j['predictedValue'] as String? ?? '',
    actualValue:    j['actualValue']    as String?,
    fichasWagered:  (j['fichasWagered'] as num?)?.toInt() ?? 0,
    fichasEarned:   (j['fichasEarned']  as num?)?.toInt(),
    isCorrect:      j['isCorrect']      as bool?,
    isPartialCredit:j['isPartialCredit']as bool?,
  );
}

// ── MatchBetDto (myBet) ───────────────────────────────────────────────────────

class MatchBetDto {
  final String               id;
  final String               matchId;
  final bool                 isLocked;
  final List<BetSelectionDto> selections;

  const MatchBetDto({
    required this.id,
    required this.matchId,
    required this.isLocked,
    required this.selections,
  });

  factory MatchBetDto.fromJson(Map<String, dynamic> j) {
    final raw = j['selections'];
    final sels = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(BetSelectionDto.fromJson).toList()
        : <BetSelectionDto>[];
    return MatchBetDto(
      id:         j['id']       as String? ?? '',
      matchId:    j['matchId']  as String? ?? '',
      isLocked:   j['isLocked'] as bool?   ?? false,
      selections: sels,
    );
  }
}

// ── BettableMatchDto ─────────────────────────────────────────────────────────

class BettableMatchDto {
  final String matchId;
  final String placeName;
  final DateTime playedAt;

  const BettableMatchDto({
    required this.matchId,
    required this.placeName,
    required this.playedAt,
  });

  factory BettableMatchDto.fromJson(Map<String, dynamic> j) => BettableMatchDto(
    matchId:   (j['matchId']   ?? j['MatchId']   ?? '').toString(),
    placeName: (j['placeName'] ?? j['PlaceName'] ?? '').toString(),
    playedAt:  _parseBetDate((j['playedAt'] ?? j['PlayedAt'])?.toString()),
  );
}

DateTime _parseBetDate(String? s) {
  if (s == null || s.isEmpty) return DateTime.now();
  final utc = (s.endsWith('Z') || s.contains('+')) ? s : '${s}Z';
  return DateTime.tryParse(utc)?.toLocal() ?? DateTime.now();
}

// ── CurrentMatchBetContext ────────────────────────────────────────────────────

class CurrentMatchBetContext {
  final String          matchId;
  final String          playedAt;
  final String          statusName;
  final bool            betWindowOpen;
  final String?         teamAName;
  final String?         teamBName;
  final String?         teamAColorHex;
  final String?         teamBColorHex;
  final List<BetPlayer> players;
  final MatchBetDto?    myBet;

  const CurrentMatchBetContext({
    required this.matchId,
    required this.playedAt,
    required this.statusName,
    required this.betWindowOpen,
    required this.players,
    this.teamAName,
    this.teamBName,
    this.teamAColorHex,
    this.teamBColorHex,
    this.myBet,
  });

  Color? get teamAColor => _hexToColor(teamAColorHex);
  Color? get teamBColor => _hexToColor(teamBColorHex);

  static Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse('FF$clean', radix: 16);
    return value != null ? Color(value) : null;
  }

  factory CurrentMatchBetContext.fromJson(Map<String, dynamic> j) {
    final rawPlayers = j['players'];
    final players = rawPlayers is List
        ? rawPlayers.whereType<Map<String, dynamic>>().map(BetPlayer.fromJson).toList()
        : <BetPlayer>[];
    return CurrentMatchBetContext(
      matchId:       j['matchId']       as String? ?? '',
      playedAt:      j['playedAt']      as String? ?? '',
      statusName:    j['statusName']    as String? ?? '',
      betWindowOpen: j['betWindowOpen'] as bool?   ?? false,
      teamAName:     j['teamAName']     as String? ?? j['TeamAName']     as String?,
      teamBName:     j['teamBName']     as String? ?? j['TeamBName']     as String?,
      teamAColorHex: j['teamAColorHex'] as String? ?? j['TeamAColorHex'] as String?,
      teamBColorHex: j['teamBColorHex'] as String? ?? j['TeamBColorHex'] as String?,
      players:       players,
      myBet: j['myBet'] is Map<String, dynamic>
          ? MatchBetDto.fromJson(j['myBet'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ── Place bet DTO ─────────────────────────────────────────────────────────────

class PlaceBetSelectionDto {
  final String category;
  final String predictedValue;
  final int    fichasWagered;

  const PlaceBetSelectionDto({
    required this.category,
    required this.predictedValue,
    required this.fichasWagered,
  });

  Map<String, dynamic> toJson() => {
    'category':       category,
    'predictedValue': predictedValue,
    'fichasWagered':  fichasWagered,
  };
}

class PlaceMatchBetDto {
  final List<PlaceBetSelectionDto> selections;
  const PlaceMatchBetDto({required this.selections});

  Map<String, dynamic> toJson() => {
    'selections': selections.map((s) => s.toJson()).toList(),
  };
}

// ── Leaderboard ───────────────────────────────────────────────────────────────

class BetLeaderboardEntry {
  final int    rank;
  final String userId;
  final String userName;
  final int    balance;
  final int    totalBets;
  final int    totalCorrect;

  const BetLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.balance,
    required this.totalBets,
    required this.totalCorrect,
  });

  factory BetLeaderboardEntry.fromJson(Map<String, dynamic> j) => BetLeaderboardEntry(
    rank:         (j['rank']         as num?)?.toInt() ?? 0,
    userId:       j['userId']        as String? ?? '',
    userName:     j['userName']      as String? ?? '',
    balance:      (j['balance']      as num?)?.toInt() ?? 0,
    totalBets:    (j['totalBets']    as num?)?.toInt() ?? 0,
    totalCorrect: (j['totalCorrect'] as num?)?.toInt() ?? 0,
  );
}

// ── History ───────────────────────────────────────────────────────────────────

class UserBetInHistoryDto {
  final String               userId;
  final String               userName;
  final String               placedAt;
  final List<BetSelectionDto> selections;
  final int                  baseReward;
  final int                  betEarnings;
  final int                  totalForMatch;

  const UserBetInHistoryDto({
    required this.userId,
    required this.userName,
    required this.placedAt,
    required this.selections,
    required this.baseReward,
    required this.betEarnings,
    required this.totalForMatch,
  });

  factory UserBetInHistoryDto.fromJson(Map<String, dynamic> j) {
    final raw = j['selections'];
    final sels = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(BetSelectionDto.fromJson).toList()
        : <BetSelectionDto>[];
    return UserBetInHistoryDto(
      userId:        j['userId']        as String? ?? '',
      userName:      j['userName']      as String? ?? '',
      placedAt:      j['placedAt']      as String? ?? '',
      selections:    sels,
      baseReward:    (j['baseReward']    as num?)?.toInt() ?? 0,
      betEarnings:   (j['betEarnings']   as num?)?.toInt() ?? 0,
      totalForMatch: (j['totalForMatch'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchBetHistoryDto {
  final String                    matchId;
  final String                    playedAt;
  final int                       teamAGoals;
  final int                       teamBGoals;
  final List<UserBetInHistoryDto> userBets;

  const MatchBetHistoryDto({
    required this.matchId,
    required this.playedAt,
    required this.teamAGoals,
    required this.teamBGoals,
    required this.userBets,
  });

  factory MatchBetHistoryDto.fromJson(Map<String, dynamic> j) {
    final raw = j['userBets'];
    final userBets = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(UserBetInHistoryDto.fromJson).toList()
        : <UserBetInHistoryDto>[];
    return MatchBetHistoryDto(
      matchId:    j['matchId']    as String? ?? '',
      playedAt:   j['playedAt']   as String? ?? '',
      teamAGoals: (j['teamAGoals'] as num?)?.toInt() ?? 0,
      teamBGoals: (j['teamBGoals'] as num?)?.toInt() ?? 0,
      userBets:   userBets,
    );
  }
}

// ── SelectionFormState (UI only) ──────────────────────────────────────────────

class SelectionFormState {
  final String  category;
  final int     fichasWagered;
  final String? winTeam;       // 'TeamA' | 'TeamB' | 'Draw'
  final int?    scoreA;
  final int?    scoreB;
  final String? playerMatchId;
  final int?    playerCount;

  const SelectionFormState({
    required this.category,
    this.fichasWagered = 50,
    this.winTeam,
    this.scoreA,
    this.scoreB,
    this.playerMatchId,
    this.playerCount,
  });

  SelectionFormState copyWith({
    String? category,
    int?    fichasWagered,
    String? winTeam,
    int?    scoreA,
    int?    scoreB,
    String? playerMatchId,
    int?    playerCount,
    bool    clearWinTeam       = false,
    bool    clearScores        = false,
    bool    clearPlayerMatchId = false,
    bool    clearPlayerCount   = false,
  }) => SelectionFormState(
    category:      category      ?? this.category,
    fichasWagered: fichasWagered ?? this.fichasWagered,
    winTeam:       clearWinTeam       ? null : (winTeam       ?? this.winTeam),
    scoreA:        clearScores        ? null : (scoreA        ?? this.scoreA),
    scoreB:        clearScores        ? null : (scoreB        ?? this.scoreB),
    playerMatchId: clearPlayerMatchId ? null : (playerMatchId ?? this.playerMatchId),
    playerCount:   clearPlayerCount   ? null : (playerCount   ?? this.playerCount),
  );

  bool get isValid {
    if (fichasWagered < 30) return false;
    switch (category) {
      case 'WinningTeam':   return winTeam != null && winTeam!.isNotEmpty;
      case 'FinalScore':    return scoreA != null && scoreB != null;
      case 'PlayerGoals':
      case 'PlayerAssists': return playerMatchId != null && playerMatchId!.isNotEmpty;
      default:              return false;
    }
  }

  String get predictedValue {
    switch (category) {
      case 'WinningTeam':   return winTeam ?? '';
      case 'FinalScore':    return '${scoreA ?? 0}:${scoreB ?? 0}';
      case 'PlayerGoals':
      case 'PlayerAssists': return '${playerMatchId ?? ''}|${playerCount ?? 0}';
      default:              return '';
    }
  }

  PlaceBetSelectionDto toDto() => PlaceBetSelectionDto(
    category:       category,
    predictedValue: predictedValue,
    fichasWagered:  fichasWagered,
  );
}

// ── Display helpers ───────────────────────────────────────────────────────────

String formatSelectionValue(String category, String? value) {
  if (value == null || value.isEmpty) return '–';
  if (category == 'WinningTeam') {
    if (value == 'TeamA') return 'Time A';
    if (value == 'TeamB') return 'Time B';
    if (value == 'Draw')  return 'Empate';
    return value;
  }
  if (category == 'FinalScore') {
    return value.replaceAll(':', ' × ');
  }
  // PlayerGoals / PlayerAssists: "{matchPlayerId}|{count}"
  final parts = value.split('|');
  if (parts.length >= 2) {
    final n = parts[1];
    return category == 'PlayerGoals'
        ? '$n gol${n != "1" ? "s" : ""}'
        : '$n assist.';
  }
  return value;
}

Color fichasColor(int? v) {
  if (v == null)  return const Color(0xFF94A3B8); // slate-400
  if (v > 0)      return const Color(0xFF34D399); // emerald-400
  if (v < 0)      return const Color(0xFFF87171); // red-400
  return          const Color(0xFFFBBF24);         // amber-400
}
