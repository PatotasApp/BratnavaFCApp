import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:patotas_app/features/auth/presentation/providers/account_store.dart';
import 'package:patotas_app/features/dashboard/domain/entities/my_player.dart';
import 'package:patotas_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const players = [
  MyPlayer(
    playerId: 'player-1',
    groupId: 'group-1',
    groupName: 'Patota 1',
    playerName: 'Jogador 1',
    isGoalkeeper: false,
    skillPoints: 0,
    isGuest: false,
  ),
  MyPlayer(
    playerId: 'player-2',
    groupId: 'group-2',
    groupName: 'Patota 2',
    playerName: 'Jogador 2',
    isGoalkeeper: false,
    skillPoints: 0,
    isGuest: false,
  ),
];

Future<ProviderContainer> containerFor(Account account) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = AccountStore(preferences);
  await store.setAccount(account);

  final container = ProviderContainer(
    overrides: [
      accountStoreProvider.overrideWith((ref) => store),
      myPlayersProvider.overrideWith((ref) async => players),
    ],
  );
  await container.read(myPlayersProvider.future);
  return container;
}

void main() {
  test('não reaproveita jogador quando não existe patota ativa', () async {
    final container = await containerFor(
      const Account(
        userId: 'user-1',
        name: 'Usuário',
        email: 'user@teste.com',
        roles: [],
      ),
    );
    addTearDown(container.dispose);

    expect(container.read(activePlayerProvider), isNull);
  });

  test('resolve somente jogador pertencente à nova patota ativa', () async {
    final container = await containerFor(
      const Account(
        userId: 'user-1',
        name: 'Usuário',
        email: 'user@teste.com',
        roles: [],
        activeGroupId: 'group-2',
        activePlayerId: 'player-1',
      ),
    );
    addTearDown(container.dispose);

    expect(container.read(activePlayerProvider)?.playerId, 'player-2');
  });
}
