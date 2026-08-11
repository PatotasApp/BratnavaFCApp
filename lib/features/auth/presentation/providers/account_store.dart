import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/auth/jwt_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/account.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AccountState {
  final List<Account> accounts;
  final String? activeAccountId;

  const AccountState({
    this.accounts = const [],
    this.activeAccountId,
  });

  Account? get activeAccount {
    if (activeAccountId == null && accounts.isEmpty) return null;
    try {
      return accounts.firstWhere(
        (a) => a.userId == activeAccountId,
        orElse: () => accounts.first,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn {
    final a = activeAccount;
    return a != null && a.accessToken.isNotEmpty;
  }

  AccountState copyWith({
    List<Account>? accounts,
    String? activeAccountId,
  }) =>
      AccountState(
        accounts: accounts ?? this.accounts,
        activeAccountId: activeAccountId ?? this.activeAccountId,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AccountStore extends StateNotifier<AccountState> {
  final SharedPreferences _prefs;

  AccountStore(this._prefs) : super(const AccountState()) {
    _load();
  }

  // ── Persistência ──────────────────────────────────────────────────────────

  void _load() {
    final raw = _prefs.getString(AppConstants.accountsStorageKey);
    final activeId = _prefs.getString(AppConstants.activeAccountKey);

    if (raw == null) return;

    try {
      final list = (json.decode(raw) as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();

      // Remove sessões com "manter logado" desmarcado — sempre desloga ao reiniciar.
      // Remove sessões cujos tokens estão ambos expirados — entrar no app com tokens
      // mortos causa um cascade de 401s que tenta navegar para /login de dentro de
      // handlers Dio ativos, podendo crashar o engine Flutter.
      final activeList = list.where((a) {
        if (!a.keepLoggedIn) return false;
        final accessExpired =
            a.accessToken.isEmpty || JwtHelper.isExpired(a.accessToken);
        // O refresh token do backend e opaco, nao e um JWT. Sua validade so
        // pode ser confirmada pelo endpoint de refresh.
        final refreshUnavailable = a.refreshToken.isEmpty;
        if (accessExpired && refreshUnavailable) return false;
        return true;
      }).toList();

      final validActiveId = activeList.any((a) => a.userId == activeId)
          ? activeId
          : (activeList.isNotEmpty ? activeList.first.userId : null);

      final matchingAccounts =
          activeList.where((account) => account.userId == validActiveId);
      final activeAccount = matchingAccounts.isNotEmpty
          ? matchingAccounts.first
          : (activeList.isNotEmpty ? activeList.first : null);
      state = AccountState(
        accounts: activeAccount == null ? const [] : [activeAccount],
        activeAccountId: activeAccount?.userId,
      );
    } catch (_) {}
  }

  Future<void> _persist() async {
    final encoded = json.encode(state.accounts.map((a) => a.toJson()).toList());
    await _prefs.setString(AppConstants.accountsStorageKey, encoded);
    if (state.activeAccountId != null) {
      await _prefs.setString(
          AppConstants.activeAccountKey, state.activeAccountId!);
    } else {
      await _prefs.remove(AppConstants.activeAccountKey);
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Salva a única sessão autenticada do aplicativo.
  Future<void> upsertAccount(Account account) async {
    state = AccountState(accounts: [account], activeAccountId: account.userId);
    await _persist();
  }

  /// Sincroniza o estado em memoria com alteracoes feitas por isolates de
  /// background, como a renovacao de token ao responder uma notificacao.
  Future<void> reloadFromStorage() async {
    await _prefs.reload();
    _load();
  }

  /// Atualiza tokens do active account após um refresh.
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    final active = state.activeAccount;
    if (active == null) return;
    await upsertAccount(
      active.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    );
  }

  /// Patch genérico do active account (ex.: activeGroupId, groupAdminIds…).
  Future<void> patchActive(Account Function(Account) updater) async {
    final active = state.activeAccount;
    if (active == null) return;
    await upsertAccount(updater(active));
  }

  /// Limpa os tokens da conta ativa sem removê-la da lista.
  /// Usado quando o refresh falha — a conta permanece para re-autenticação.
  /// isLoggedIn retorna false, o que faz o router redirecionar para /login.
  Future<void> clearActiveTokens() async {
    final active = state.activeAccount;
    if (active == null) return;
    await upsertAccount(active.copyWith(accessToken: '', refreshToken: ''));
  }

  /// Encerra a sessão e remove eventuais contas legadas persistidas.
  Future<void> logout() async {
    await logoutAll();
  }

  Future<void> logoutAll() async {
    state = const AccountState();
    await _prefs.remove(AppConstants.accountsStorageKey);
    await _prefs.remove(AppConstants.activeAccountKey);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final accountStoreProvider =
    StateNotifierProvider<AccountStore, AccountState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountStore(prefs);
});
