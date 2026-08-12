import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/auth/firebase_auth_service.dart';
import '../../../../core/push/push_token_api.dart';
import '../../../../core/push/local_notifications.dart';
import '../../../../core/home_widget/match_home_widget_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import 'account_store.dart';
import 'session_provider.dart';

// ── Firebase Auth, interceptor e Dio ─────────────────────────────────────────

final firebaseAuthServiceProvider =
    Provider<FirebaseAuthService>((ref) => FirebaseAuthService());

/// Sessão do Firebase. O primeiro evento é o que distingue "ainda carregando"
/// de "deslogado" — antes dele chegar, o SDK ainda está lendo a sessão do disco.
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthServiceProvider).authStateChanges(),
);

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);

  return AuthInterceptor(
    authService: authService,
    onUnauthorized: () async {
      // 401 que sobreviveu ao token novo: a sessão não vale mais. Encerrar no
      // Firebase é o que faz o router redirecionar, já que quem manda no
      // roteamento agora é o authStateChanges.
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
      await LocalNotifications.plugin.cancelAll();
      await authService.signOut();
      await ref.read(accountStoreProvider.notifier).logout();
    },
  );
});

// ── Dio configurado com AuthInterceptor ───────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  return buildDio(authInterceptor: ref.watch(authInterceptorProvider));
});

// ── Acesso ao perfil ─────────────────────────────────────────────────────────
//
// O repositório e os use cases de login/cadastro foram removidos: eles
// envelopavam endpoints que a API deletou. O FirebaseAuthService ocupa esse
// lugar, e envolver o SDK numa segunda abstração não acrescentaria nada.

final authDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

/// ID token corrente, para quem precisa do token como VALOR e não via header.
///
/// São os casos em que a autenticação viaja na query string, porque nem o
/// `<video src>` nem o cliente SignalR mandam header `Authorization`: `?t=` em
/// `/stream` e `?access_token=` em `/hubs/realtime`. A API trata os dois no
/// `OnMessageReceived`.
///
/// É um FutureProvider porque `getIdToken()` é assíncrono. Reexecuta quando a
/// sessão troca, então o token nunca sobrevive a um logout.
final idTokenProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.uid));
  if (uid == null) return null;

  return ref.watch(firebaseAuthServiceProvider).idToken();
});

String _normalizeGroupId(String? id) =>
    (id ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

String? _resolveActiveGroupId({
  required String? previousGroupId,
  required Iterable<String> candidateGroupIds,
}) {
  final unique = <String, String>{};
  for (final id in candidateGroupIds) {
    final normalized = _normalizeGroupId(id);
    if (normalized.isNotEmpty) unique.putIfAbsent(normalized, () => id);
  }

  final previousNormalized = _normalizeGroupId(previousGroupId);
  if (previousNormalized.isNotEmpty && unique.containsKey(previousNormalized)) {
    return unique[previousNormalized];
  }

  // Mantém o comportamento do site: quando não há uma seleção anterior,
  // começa pela primeira patota disponível e o seletor permite trocar depois.
  return unique.values.firstOrNull;
}

// ── AsyncNotifier para operações de login/registro ───────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Autentica no Firebase. Nada mais acontece aqui de propósito.
  ///
  /// Quem carrega o perfil é o `sessionProvider`, que observa
  /// `authStateChanges` e dispara o `GET /me` seguido do enriquecimento de
  /// patotas. Duplicar isso no login deixaria os dois caminhos divergentes —
  /// e o cold start, que nunca passa pela tela de login, ficaria de fora.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthServiceProvider).signInWithEmail(
            email: email,
            password: password,
          );

      // Um 401 anterior pode ter armado o guard do interceptor. A sessão nova é
      // válida e precisa poder fazer as consultas de inicialização.
      ref.read(authInterceptorProvider).resetUnauthorizedGuard();
    });
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthServiceProvider).signInWithGoogle();
      ref.read(authInterceptorProvider).resetUnauthorizedGuard();
    });
  }

  /// Cria a conta no Firebase. A linha em `Users` nasce depois, no primeiro
  /// `GET /me` — não existe endpoint de cadastro.
  ///
  /// Não recebe `userName`: o backend gera um a partir do e-mail no
  /// provisionamento, e o usuário troca depois no perfil.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = ref.read(firebaseAuthServiceProvider);

      final credential = await auth.createAccount(
        email: email,
        password: password,
      );

      final displayName = '$firstName $lastName'.trim();

      // Mantém o registro do Firebase correto mesmo que o resto falhe. Não
      // adianta para o provisionamento: o token já foi emitido sem a claim
      // `name`, e token não muda depois de emitido.
      await credential.user?.updateDisplayName(displayName);

      // Verificar o e-mail é o que impede o Firebase de apagar a credencial de
      // senha caso a pessoa entre com o Google mais tarde. Também é o que
      // libera o vínculo com uma linha existente no provisionamento. Não
      // bloqueia o uso do app, e falhar aqui não invalida o cadastro.
      try {
        await auth.sendEmailVerification();
      } catch (_) {}

      ref.read(authInterceptorProvider).resetUnauthorizedGuard();

      // O sessionProvider já disparou o GET /me quando a conta foi criada; aqui
      // esperamos essa mesma chamada terminar, porque a linha precisa existir
      // antes do PUT. Sem o await, os dois provisionariam em paralelo e um
      // estouraria o índice único de FirebaseUid.
      await ref.read(sessionProvider.notifier).loadProfile();

      // Segunda etapa: a linha nasceu com o nome derivado do e-mail (o token não
      // tinha `name`), então corrigimos aqui. É este passo que faz os campos do
      // formulário valerem de fato.
      await ref.read(authDataSourceProvider).updateMe(
            firstName: firstName,
            lastName: lastName,
          );

      await ref.read(sessionProvider.notifier).loadProfile();
    });
  }

  Future<void> logout() async {
    final messaging = FirebaseMessaging.instance;
    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await PushTokenApi(ref.read(dioProvider)).unregisterToken(token);
      }
    } catch (error) {
      debugPrint('[Logout] Falha ao remover token push: $error');
    }

    // Limpa a sessao antes de invalidar o FCM. Se o Firebase gerar um novo
    // token, o listener nao conseguira associa-lo a uma conta deslogada.
    await ref.read(accountStoreProvider.notifier).logout();

    // Encerra a sessão no Firebase (e no Google). É isto que faz o
    // authStateChanges emitir null e o router redirecionar para /login — sem
    // isso o app limparia o perfil e continuaria autenticado.
    await ref.read(firebaseAuthServiceProvider).signOut();

    try {
      await messaging.deleteToken();
    } catch (error) {
      debugPrint('[Logout] Falha ao invalidar token FCM local: $error');
    }
    await LocalNotifications.plugin.cancelAll();
    await MatchHomeWidgetService.clear();
    ref.invalidateSelf();
  }

  /// Consulta o backend especificamente para [groupId] e atualiza
  /// [activeGroupIsAdmin] / [activeGroupIsFinanceiro] na conta ativa.
  /// Chamado toda vez que o usuário troca de patota.
  Future<void> refreshMyGroupRoles(
    String groupId, {
    Map<String, List<String>>? knownRoles,
  }) async {
    final requestedAccount = ref.read(accountStoreProvider).activeAccount;
    if (requestedAccount == null) return;
    try {
      final dataSource = ref.read(authDataSourceProvider);
      // O mobile não usa o atalho `my-roles`: papéis de plataforma podem ter
      // bypass nesse endpoint. As listas por usuário contêm apenas vínculos
      // explícitos e são a fonte de verdade do aplicativo.
      final roles = knownRoles ??
          await dataSource.fetchGroupRoles(requestedAccount.userId);
      // Falhou a consulta: não sobrescreve com `false`, senão um erro de rede
      // rebaixa o admin e ele cai na tela "Sem acesso".
      if (roles == null) return;

      final adminIds = roles['adminIds'] ?? const <String>[];
      final financeiroIds = roles['financeiroIds'] ?? const <String>[];
      final normalizedGroupId = _normalizeGroupId(groupId);
      final isAdmin = adminIds.any(
        (id) => _normalizeGroupId(id) == normalizedGroupId,
      );
      final isFinanceiro = financeiroIds.any(
        (id) => _normalizeGroupId(id) == normalizedGroupId,
      );

      // A pessoa pode ter trocado de conta ou de patota enquanto a chamada
      // estava em andamento. Uma resposta antiga jamais pode sobrescrever as
      // permissões (nem o activeGroupId) da seleção atual.
      final current = ref.read(accountStoreProvider).activeAccount;
      if (current == null ||
          current.userId != requestedAccount.userId ||
          !_sameGroupId(current.activeGroupId, groupId)) {
        return;
      }
      await ref.read(accountStoreProvider.notifier).patchActive(
            (latest) => latest.copyWith(
              groupAdminIds: adminIds,
              groupFinanceiroIds: financeiroIds,
              activeGroupIsAdmin: isAdmin,
              activeGroupIsFinanceiro: isFinanceiro,
            ),
          );
    } catch (_) {
      // silencioso — UI já usa os arrays de fallback
    }
  }

  /// Troca o contexto ativo de patota de forma atômica para a autorização.
  ///
  /// Primeiro revoga localmente os papéis da patota anterior (fail closed),
  /// depois persiste o novo jogador/grupo e só então consulta os vínculos
  /// explícitos no backend. Como o AccountStore é observado globalmente,
  /// menus, providers e páginas deixam de reutilizar permissões antigas já no
  /// primeiro frame da troca.
  Future<void> selectActiveGroup({
    required String groupId,
    required String playerId,
  }) async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;

    await ref.read(accountStoreProvider.notifier).patchActive(
          (current) => current.copyWith(
            activePlayerId: playerId,
            activeGroupId: groupId,
            activeGroupIsAdmin: false,
            activeGroupIsFinanceiro: false,
          ),
        );

    await refreshMyGroupRoles(groupId);
  }

  static bool _sameGroupId(String? left, String? right) =>
      (left ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '') ==
      (right ?? '').trim().toLowerCase().replaceAll(RegExp(r'[{}]'), '');

  /// Re-busca os groupAdminIds e groupFinanceiroIds da conta ativa.
  /// Chamado no startup e no resume para refletir mudanças de role feitas
  /// enquanto o usuário estava fora (ex: foi promovido a admin).
  Future<void> refreshRoles() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    try {
      final dataSource = ref.read(authDataSourceProvider);
      final roles = await dataSource.fetchGroupRoles(account.userId);
      if (roles == null) {
        return; // falha de rede não pode apagar permissão salva
      }
      await ref.read(accountStoreProvider.notifier).setAccount(
            account.copyWith(
              groupAdminIds: roles['adminIds'],
              groupFinanceiroIds: roles['financeiroIds'],
            ),
          );

      // Reconfirma o papel na patota ativa — é o valor que o isGroupAdmin usa.
      final groupId = account.activeGroupId;
      if (groupId != null && groupId.isNotEmpty) {
        await refreshMyGroupRoles(groupId, knownRoles: roles);
      }
    } catch (_) {
      // Silencioso — permissões desatualizadas são melhor que crash
    }
  }

  /// Re-busca roles + grupos do usuário e atualiza activeGroupId se ainda não definido.
  /// Chamado no startup, no resume, após aceitar convite ou criar nova patota.
  Future<void> refreshGroupMembership() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    try {
      final dataSource = ref.read(authDataSourceProvider);
      final (roles, groupIds) = await (
        dataSource.fetchGroupRoles(account.userId),
        dataSource.fetchMyGroupIds(),
      ).wait;

      final candidateGroupIds = <String>[
        ...groupIds,
        ...?roles?['adminIds'],
        ...?roles?['financeiroIds'],
      ];
      final resolvedGroupId = _resolveActiveGroupId(
            previousGroupId: account.activeGroupId,
            candidateGroupIds: candidateGroupIds,
          ) ??
          account.activeGroupId;

      // `roles == null` significa que a consulta falhou. Mantém o que já estava
      // salvo em vez de zerar as permissões por causa de uma queda de rede.
      await ref.read(accountStoreProvider.notifier).setAccount(
            account.copyWith(
              groupAdminIds: roles?['adminIds'],
              groupFinanceiroIds: roles?['financeiroIds'],
              activeGroupId: resolvedGroupId,
            ),
          );

      // O flag da patota ativa é a fonte da verdade do isGroupAdmin, mas só era
      // preenchido ao trocar de patota — num login com grupo único ele nunca
      // chegava a ser carregado.
      if (resolvedGroupId != null && resolvedGroupId.isNotEmpty) {
        await refreshMyGroupRoles(resolvedGroupId, knownRoles: roles);
      }
    } catch (_) {}
  }

}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
