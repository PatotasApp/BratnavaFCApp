import 'package:patotas_app/features/dashboard/domain/entities/my_player.dart';
import 'package:patotas_app/features/player_history/presentation/pages/player_history_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MyPlayer player(String playerId, String groupId, String name) => MyPlayer(
        playerId: playerId,
        groupId: groupId,
        groupName: 'Patota $groupId',
        playerName: name,
        isGoalkeeper: false,
        skillPoints: 0,
        isGuest: false,
      );

  test('histórico usa somente o jogador da patota ativa', () {
    final players = [
      player('player-bratnava', 'bratnava', 'Luis'),
      player('player-patoteiros', 'patoteiros', 'Luis Mello'),
    ];

    final selected = resolveActiveHistoryPlayer(
      players: players,
      groupId: 'PATOTEIROS',
      activePlayerId: 'player-bratnava',
    );

    expect(selected?.playerId, 'player-patoteiros');
  });

  test('activePlayerId tem preferência dentro da patota ativa', () {
    final players = [
      player('player-1', 'group-1', 'Primeiro'),
      player('player-2', 'group-1', 'Selecionado'),
    ];

    final selected = resolveActiveHistoryPlayer(
      players: players,
      groupId: 'group-1',
      activePlayerId: 'PLAYER-2',
    );

    expect(selected?.playerName, 'Selecionado');
  });
}
