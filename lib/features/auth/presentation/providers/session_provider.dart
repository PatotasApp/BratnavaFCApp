import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/firebase_auth_service.dart';
import '../../../../core/errors/app_exception.dart';
import 'account_store.dart';
import 'auth_provider.dart';

/// Resultado do `GET /api/users/me`.
///
/// `forbidden` não é falha técnica: é o backend recusando a identidade — conta
/// inativa, ou vínculo negado por e-mail não verificado. O middleware devolve
/// 403 porque usuário inativo não recebe a claim de role.
enum ProfileStatus { idle, loading, ready, forbidden, error }

class SessionState {
  const SessionState({
    this.initializing = true,
    this.user,
    this.profileStatus = ProfileStatus.idle,
  });

  /// `true` até o primeiro evento de `authStateChanges`.
  ///
  /// Enquanto for true, NADA que dependa de estar logado pode renderizar: o SDK
  /// ainda está lendo a sessão do disco, e tratar esse instante como
  /// "deslogado" chuta para o login quem estava autenticado. É o bug clássico
  /// que aparece em todo cold start.
  final bool initializing;

  final User? user;
  final ProfileStatus profileStatus;

  bool get isAuthenticated => user != null;

  bool get emailVerified => user?.emailVerified ?? false;

  /// Só aqui o app pode entrar. Ter sessão não basta: nome, GUID interno e
  /// permissões vêm do `GET /me`, e renderizar antes disso mostra a tela toda
  /// com os fallbacks — patota vazia, sem permissão de admin.
  bool get isReady =>
      !initializing && user != null && profileStatus == ProfileStatus.ready;

  /// Estados em que a decisão do que mostrar é de produto, não do roteamento.
  bool get profileBlocked =>
      profileStatus == ProfileStatus.forbidden ||
      profileStatus == ProfileStatus.error;

  SessionState copyWith({
    bool? initializing,
    User? user,
    bool clearUser = false,
    ProfileStatus? profileStatus,
  }) =>
      SessionState(
        initializing: initializing ?? this.initializing,
        user: clearUser ? null : (user ?? this.user),
        profileStatus: profileStatus ?? this.profileStatus,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref, this._auth) : super(const SessionState()) {
    _subscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final Ref _ref;
  final FirebaseAuthService _auth;

  late final StreamSubscription<User?> _subscription;

  /// Compartilha a chamada em voo em vez de descartar a segunda. Duas requests
  /// simultâneas entrariam no provisionamento ao mesmo tempo e a segunda
  /// estouraria a violação do índice único de FirebaseUid — e quem chama precisa
  /// poder ESPERAR o perfil existir, não só saber que alguém já pediu (é disso
  /// que o cadastro depende para corrigir o nome).
  Future<void>? _inFlight;

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      state = const SessionState(initializing: false);
      await _ref.read(accountStoreProvider.notifier).logout();
      return;
    }

    state = state.copyWith(
      initializing: false,
      user: user,
      profileStatus: ProfileStatus.loading,
    );

    await loadProfile();
  }

  Future<void> loadProfile() {
    final pending = _inFlight;
    if (pending != null) return pending;

    final request = _load();
    _inFlight = request;

    return request.whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    state = state.copyWith(profileStatus: ProfileStatus.loading);

    try {
      final account = await _ref.read(authDataSourceProvider).fetchMe();

      // O GET /me traz identidade + roles globais, mas NÃO a patota selecionada
      // (isso é preferência local do app). Sem preservar a seleção anterior, o
      // app reabria sempre na primeira patota em vez da última usada.
      final previous = _ref.read(accountStoreProvider).activeAccount;
      final merged = previous == null
          ? account
          : account.copyWith(
              activeGroupId: previous.activeGroupId,
              activePlayerId: previous.activePlayerId,
              activeGroupIsAdmin: previous.activeGroupIsAdmin,
              activeGroupIsFinanceiro: previous.activeGroupIsFinanceiro,
            );
      await _ref.read(accountStoreProvider.notifier).setAccount(merged);

      // Antes de liberar a UI: as requests que ela vai disparar devem sair já
      // com o token novo, senão todas pagam o caminho lento do backend.
      await _auth.refreshClaimsIfMissing();

      // Patotas e permissões. Falha aqui não invalida a sessão — o método já
      // preserva o que estava salvo em caso de erro de rede.
      await _ref.read(authNotifierProvider.notifier).refreshGroupMembership();

      state = state.copyWith(profileStatus: ProfileStatus.ready);
    } catch (error) {
      final status = error is ServerException ? error.statusCode : null;

      debugPrint('[Session] GET /me falhou (HTTP ${status ?? '-'}): $error');

      state = state.copyWith(
        profileStatus: status == 401 || status == 403
            ? ProfileStatus.forbidden
            : ProfileStatus.error,
      );
    }
  }

  /// Relê o registro do Firebase para descobrir se o e-mail foi verificado. O
  /// SDK não avisa o app quando isso acontece — o link costuma ser aberto em
  /// outro aparelho.
  Future<bool> recheckEmailVerified() async {
    final verified = await _auth.reloadAndCheckEmailVerified();
    if (verified) state = state.copyWith(user: _auth.currentUser);
    return verified;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref, ref.watch(firebaseAuthServiceProvider));
});
