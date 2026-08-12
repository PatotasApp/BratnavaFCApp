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
      );

  test('guardar um perfil substitui o anterior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    await store.setAccount(account('1'));
    await store.setAccount(account('2'));

    expect(store.state.activeAccount?.userId, '2');
  });

  test('logout apaga o perfil persistido', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    await store.setAccount(account('1'));
    await store.logout();

    expect(store.state.activeAccount, isNull);
    expect(store.state.hasProfile, isFalse);
    expect(prefs.containsKey(AppConstants.accountStorageKey), isFalse);
  });

  test('perfil salvo é lido na inicialização', () async {
    final saved = account('persisted');
    SharedPreferences.setMockInitialValues({
      AppConstants.accountStorageKey: jsonEncode(saved.toJson()),
    });

    final prefs = await SharedPreferences.getInstance();
    final store = AccountStore(prefs);

    expect(store.state.hasProfile, isTrue);
    expect(store.state.activeAccount?.userId, 'persisted');
    expect(store.state.activeAccount?.email, 'persisted@example.com');
  });

  test('o perfil não guarda token: a sessão é do Firebase', () async {
    final json = account('1').toJson();

    expect(json.containsKey('accessToken'), isFalse);
    expect(json.containsKey('refreshToken'), isFalse);
    expect(json.containsKey('keepLoggedIn'), isFalse);
  });

  test('formato antigo (lista da v2) não derruba a inicialização', () async {
    // A chave subiu para v3, então o valor da v2 nunca é lido. Este teste cobre
    // o caso de alguém gravar uma lista na chave nova por engano: precisa cair no
    // catch e deixar o app subir, não estourar no construtor.
    SharedPreferences.setMockInitialValues({
      AppConstants.accountStorageKey: jsonEncode([account('1').toJson()]),
    });

    final prefs = await SharedPreferences.getInstance();

    expect(() => AccountStore(prefs), returnsNormally);
    expect(AccountStore(prefs).state.hasProfile, isFalse);
  });
}
