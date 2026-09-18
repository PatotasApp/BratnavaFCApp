import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';
import 'package:patotas_app/features/matches/domain/utils/match_participant_resolver.dart';

MatchPlayerInfo player({
  required String matchPlayerId,
  required String playerId,
  String? userId,
}) =>
    MatchPlayerInfo(
      matchPlayerId: matchPlayerId,
      playerId: playerId,
      userId: userId,
      playerName: playerId,
      isGoalkeeper: false,
      isGuest: false,
      team: 1,
      inviteResponse: InviteResponse.accepted,
    );

void main() {
  final first = player(
    matchPlayerId: 'match-player-1',
    playerId: 'player-1',
    userId: 'user-1',
  );
  final currentUser = player(
    matchPlayerId: 'match-player-2',
    playerId: 'player-2',
    userId: 'USER-2',
  );
  final players = [first, currentUser];

  test('prioriza o vínculo retornado pelo backend', () {
    final result = resolveCurrentMatchPlayer(
      players: players,
      userId: 'user-1',
      serverMatchPlayerId: 'match-player-2',
      activePlayerId: 'player-1',
    );

    expect(result, same(currentUser));
  });

  test('resolve pelo userId quando o player ativo local está desatualizado',
      () {
    final result = resolveCurrentMatchPlayer(
      players: players,
      userId: ' user-2 ',
      activePlayerId: 'player-inexistente',
    );

    expect(result, same(currentUser));
  });

  test('usa o player ativo como fallback para respostas antigas da API', () {
    final result = resolveCurrentMatchPlayer(
      players: players,
      userId: 'user-sem-vinculo',
      activePlayerId: 'player-1',
    );

    expect(result, same(first));
  });

  test('retorna null quando nenhum vínculo corresponde', () {
    final result = resolveCurrentMatchPlayer(
      players: players,
      userId: 'user-inexistente',
      activePlayerId: 'player-inexistente',
    );

    expect(result, isNull);
  });
}
