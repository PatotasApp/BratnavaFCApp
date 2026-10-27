import '../../domain/entities/championship_models.dart';

abstract interface class ChampionshipDataSource {
  Future<List<ChampionshipSummary>> fetchAll(String groupId);
  Future<ChampionshipDetails> fetchById(String groupId, String id);
  Future<NextGameSuggestion?> fetchNextGame(String groupId, String id);
  Future<String> create(String groupId, ChampionshipUpsert input);
  Future<void> update(String groupId, String id, ChampionshipUpsert input);
  Future<void> cancel(String groupId, String id);
  Future<void> openAcceptation(String groupId, String id);
  Future<void> acceptMyInvite(String groupId, String id);
  Future<void> rejectMyInvite(String groupId, String id);
  Future<void> acceptInvite(String groupId, String id, String playerId);
  Future<void> rejectInvite(String groupId, String id, String playerId);
  Future<void> addGuest(String groupId, String id, String playerId);
  Future<ChampionshipTeamsDraw> drawTeams(
    String groupId,
    String id,
    int teamCount,
  );
  Future<void> defineTeams(
    String groupId,
    String id,
    DefineChampionshipTeams input,
  );
  Future<void> assignPlayerTeam(
    String groupId,
    String id,
    String playerId,
    String teamId,
  );

  /// Devolve o `message` do servidor (aviso de poucas cores), se houver.
  Future<String?> drawTeamColors(String groupId, String id);
  Future<void> updateTeam(
    String groupId,
    String id,
    String teamId, {
    required String name,
    String? colorId,
  });

  /// Volta o campeonato para a etapa anterior (`POST /{id}/step-back`).
  Future<void> stepBack(String groupId, String id);
  Future<void> start(String groupId, String id);
  Future<String> createGame(
    String groupId,
    String id,
    String teamAId,
    String teamBId,
  );
  Future<void> addGoal(
    String groupId,
    String id,
    String gameId, {
    required String scorerPlayerId,
    String? assistPlayerId,
    required bool isOwnGoal,
    int? timeSeconds,
  });
  Future<void> deleteGoal(
    String groupId,
    String id,
    String gameId,
    String goalId,
  );
  Future<void> setGoalkeeper(
    String groupId,
    String id,
    String teamId,
    String playerId,
  );
  Future<void> endGame(
    String groupId,
    String id,
    String gameId, {
    String? externalWinnerTeamId,
  });

  /// Marca um lance para as câmeras ("GolTimeA", "GolTimeB" ou "Jogada"),
  /// gravando campeonato, jogo e horário (`POST /{id}/games/{gameId}/events`).
  Future<void> publishGameEvent(
    String groupId,
    String id,
    String gameId,
    String type,
  );
  Future<void> finish(String groupId, String id);
  Future<void> vote(
    String groupId,
    String id,
    String votedPlayerId, {
    String? gameId,
  });
  Future<void> finalize(
    String groupId,
    String id, {
    List<String>? externalDecisionTeamOrder,
  });
}
