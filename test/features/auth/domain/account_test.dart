import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';

void main() {
  const account = Account(
    userId: 'user-1',
    name: 'Usuário',
    email: 'usuario@teste.com',
    roles: [],
    activeGroupId: 'group-1',
    activePlayerId: 'player-1',
    activeGroupIsAdmin: true,
    activeGroupIsFinanceiro: true,
  );

  test('copyWith mantém a seleção quando não há ordem para limpar', () {
    final updated = account.copyWith(name: 'Novo nome');

    expect(updated.activeGroupId, 'group-1');
    expect(updated.activePlayerId, 'player-1');
  });

  test('copyWith permite limpar patota e jogador ativos', () {
    final updated = account.copyWith(
      clearActiveGroupId: true,
      clearActivePlayerId: true,
      activeGroupIsAdmin: false,
      activeGroupIsFinanceiro: false,
    );

    expect(updated.activeGroupId, isNull);
    expect(updated.activePlayerId, isNull);
    expect(updated.isActiveGroupAdmin, isFalse);
    expect(updated.isActiveGroupFinanceiro, isFalse);
  });
}
