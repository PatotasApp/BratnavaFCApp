import 'dart:convert';

import 'package:patotas_app/core/constants/app_constants.dart';
import 'package:patotas_app/features/auth/domain/entities/account.dart';
import 'package:patotas_app/features/auth/presentation/providers/account_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Account account(String id) => Account(
        userId: id,
        name: 'Usuário $id',
        email: '$id@example.com',
        roles: const ['User'],
        accessToken: 'access-$id',
        refreshToken: 'refresh-$id',
      );

  test('salvar uma sessão substitui qualquer conta anterior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    await store.upsertAccount(account('1'));
    await store.upsertAccount(account('2'));

    expect(store.state.accounts, hasLength(1));
    expect(store.state.activeAccount?.userId, '2');
  });

  test('logout remove toda a sessão persistida', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    await store.upsertAccount(account('1'));
    await store.logout();

    expect(store.state.accounts, isEmpty);
    expect(store.state.activeAccount, isNull);
    expect(prefs.containsKey(AppConstants.accountsStorageKey), isFalse);
    expect(prefs.containsKey(AppConstants.activeAccountKey), isFalse);
  });

  test('mantem login com access expirado e refresh token opaco', () async {
    final saved = account('persisted');
    SharedPreferences.setMockInitialValues({
      AppConstants.accountsStorageKey: jsonEncode([saved.toJson()]),
      AppConstants.activeAccountKey: saved.userId,
    });

    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    expect(store.state.isLoggedIn, isTrue);
    expect(store.state.activeAccount?.refreshToken, 'refresh-persisted');
  });
}
