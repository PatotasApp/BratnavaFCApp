import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/account/presentation/pages/my_account_page.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:patotas_app/features/dashboard/domain/entities/my_player.dart';

void main() {
  const player = MyPlayer(
    playerId: 'player-1',
    groupId: 'GROUP-1',
    groupName: 'Resenha FC',
    playerName: 'Alexandre',
    isGoalkeeper: false,
    skillPoints: 0,
    isGuest: false,
  );

  Account account({
    List<String> adminIds = const [],
    List<String> financeiroIds = const [],
  }) =>
      Account(
        userId: 'user-1',
        name: 'Alexandre',
        email: 'alexandre@example.com',
        roles: const ['User'],
        groupAdminIds: adminIds,
        groupFinanceiroIds: financeiroIds,
      );

  test('mostra Administrador na patota administrada', () {
    expect(
      groupMembershipLabel(account(adminIds: const ['group-1']), player),
      'Administrador',
    );
  });

  test('mostra Financeiro na patota em que cuida do financeiro', () {
    expect(
      groupMembershipLabel(
        account(financeiroIds: const ['{group-1}']),
        player,
      ),
      'Financeiro',
    );
  });

  test('administrador tem prioridade se acumular os dois papeis', () {
    expect(
      groupMembershipLabel(
        account(
          adminIds: const ['group-1'],
          financeiroIds: const ['group-1'],
        ),
        player,
      ),
      'Administrador',
    );
  });

  test('mantem Mensalista quando nao possui papel de gestao', () {
    expect(groupMembershipLabel(account(), player), 'Mensalista');
  });
}
