import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/account.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Perfil da única sessão possível.
///
/// Era uma lista com conta ativa por id. Duas coisas tornaram isso inútil: o
/// app já havia sido reduzido a uma sessão só, e o Firebase Auth suporta um
/// usuário por vez por instância — não há como manter duas sessões.
///
/// `activeAccount` sobreviveu como nome do acessor porque é o que 40 arquivos já
/// leem; trocá-lo seria churn sem ganho.
class AccountState {
  const AccountState({this.account});

  final Account? account;

  Account? get activeAccount => account;

  /// Presença de perfil, NÃO de sessão. Quem decide se há sessão é o
  /// `authStateChanges` do Firebase — ver `sessionProvider`.
  bool get hasProfile => account != null;

  AccountState copyWith({Account? account}) =>
      AccountState(account: account ?? this.account);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AccountStore extends StateNotifier<AccountState> {
  AccountStore(this._prefs) : super(const AccountState()) {
    _load();
  }

  final SharedPreferences _prefs;

  // ── Persistência ──────────────────────────────────────────────────────────

  void _load() {
    final raw = _prefs.getString(AppConstants.accountStorageKey);
    if (raw == null) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return;

      state = AccountState(account: Account.fromJson(decoded));
    } catch (_) {
      // Perfil corrompido não impede o app de subir: ele é recarregado do
      // `GET /me` na próxima vez que a sessão do Firebase for resolvida.
    }
  }

  Future<void> _persist() async {
    final account = state.account;

    if (account == null) {
      await _prefs.remove(AppConstants.accountStorageKey);
      return;
    }

    await _prefs.setString(
      AppConstants.accountStorageKey,
      json.encode(account.toJson()),
    );
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Grava o perfil da sessão, substituindo o anterior.
  Future<void> setAccount(Account account) async {
    state = AccountState(account: account);
    await _persist();
  }

  /// Sincroniza o estado em memória com alterações feitas por isolates de
  /// background, como as ações rápidas de notificação.
  Future<void> reloadFromStorage() async {
    await _prefs.reload();
    _load();
  }

  /// Patch do perfil (ex.: activeGroupId, groupAdminIds…).
  Future<void> patchActive(Account Function(Account) updater) async {
    final account = state.account;
    if (account == null) return;
    await setAccount(updater(account));
  }

  /// Descarta o perfil local. Não encerra a sessão do Firebase — quem faz isso
  /// é o `FirebaseAuthService.signOut`, e é ele que dispara o redirecionamento.
  Future<void> logout() async {
    state = const AccountState();
    await _prefs.remove(AppConstants.accountStorageKey);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final accountStoreProvider =
    StateNotifierProvider<AccountStore, AccountState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountStore(prefs);
});
