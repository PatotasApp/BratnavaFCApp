import '../entities/match_models.dart';

MatchPlayerInfo? resolveCurrentMatchPlayer({
  required Iterable<MatchPlayerInfo> players,
  required String userId,
  String? serverMatchPlayerId,
  String? activePlayerId,
}) {
  final playerList = players.toList(growable: false);

  final normalizedServerId = serverMatchPlayerId?.trim();
  if (normalizedServerId != null && normalizedServerId.isNotEmpty) {
    for (final player in playerList) {
      if (player.matchPlayerId == normalizedServerId) return player;
    }
  }

  final normalizedUserId = userId.trim().toLowerCase();
  if (normalizedUserId.isNotEmpty) {
    for (final player in playerList) {
      if (player.userId?.trim().toLowerCase() == normalizedUserId) {
        return player;
      }
    }
  }

  final normalizedPlayerId = activePlayerId?.trim();
  if (normalizedPlayerId != null && normalizedPlayerId.isNotEmpty) {
    for (final player in playerList) {
      if (player.playerId == normalizedPlayerId) return player;
    }
  }

  return null;
}
