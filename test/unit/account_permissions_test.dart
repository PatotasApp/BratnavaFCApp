import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bratnava = '11111111-1111-1111-1111-111111111111';
  const patoteiros = '22222222-2222-2222-2222-222222222222';

  Account account({
    required String activeGroupId,
    bool? isAdmin,
    bool? isFinanceiro,
  }) =>
      Account(
        userId: 'user-1',
        name: 'Luis',
        email: 'luis@example.com',
        roles: const ['Admin'],
        accessToken: 'token',
        refreshToken: 'refresh',
        activeGroupId: activeGroupId,
        groupAdminIds: const [bratnava],
        groupFinanceiroIds: const [bratnava],
        activeGroupIsAdmin: isAdmin,
        activeGroupIsFinanceiro: isFinanceiro,
      );

  test('papéis da Bratnava não vazam para a Patoteiros', () {
    final value = account(
      activeGroupId: patoteiros,
      isAdmin: false,
      isFinanceiro: false,
    );

    expect(value.isGroupAdmin(patoteiros), isFalse);
    expect(value.isGroupFinanceiro(patoteiros), isFalse);
  });

  test('papéis confirmados continuam válidos na patota correta', () {
    final value = account(
      activeGroupId: bratnava,
      isAdmin: true,
      isFinanceiro: true,
    );

    expect(value.isGroupAdmin(bratnava), isTrue);
    expect(value.isGroupFinanceiro(bratnava), isTrue);
  });

  test('resposta autoritativa negativa prevalece sobre cache antigo', () {
    final value = account(
      activeGroupId: bratnava,
      isAdmin: false,
      isFinanceiro: false,
    );

    expect(value.isGroupAdmin(bratnava), isFalse);
    expect(value.isGroupFinanceiro(bratnava), isFalse);
  });

  test('GodMode não concede papel em nenhuma patota no aplicativo', () {
    final value = Account(
      userId: 'user-1',
      name: 'Luis',
      email: 'luis@example.com',
      roles: const ['User', 'GodMode'],
      accessToken: 'token',
      refreshToken: 'refresh',
      activeGroupId: patoteiros,
      activeGroupIsAdmin: false,
      activeGroupIsFinanceiro: false,
    );

    expect(value.isGroupAdmin(patoteiros), isFalse);
    expect(value.isGroupFinanceiro(patoteiros), isFalse);
    expect(value.isAdmin, isFalse);
  });

  test('conta persistida remove o papel GodMode ao carregar no app', () {
    final value = Account.fromJson({
      'userId': 'user-1',
      'name': 'Luis',
      'email': 'luis@example.com',
      'roles': ['User', 'GodMode'],
      'accessToken': 'token',
      'refreshToken': 'refresh',
    });

    expect(value.roles, ['User']);
  });
}
