import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/interceptors/auth_interceptor.dart';
import '../../../../core/auth/jwt_helper.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'account_store.dart';

// ── AuthInterceptor (singleton por conta ativa) ───────────────────────────────

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final notifier = ref.read(accountStoreProvider.notifier);
  return AuthInterceptor(
    getAccessToken: () {
      final t = ref.read(accountStoreProvider).activeAccount?.accessToken;
      return (t == null || t.isEmpty) ? null : t;
    },
    getRefreshToken: () {
      final t = ref.read(accountStoreProvider).activeAccount?.refreshToken;
      return (t == null || t.isEmpty) ? null : t;
    },
    onTokensRefreshed: (access, refresh) async {
      await notifier.updateTokens(access, refresh);
    },
    onUnauthorized: () async {
      // Limpa os tokens sem remover a conta — o router redireciona para /login
      // e a conta permanece na lista para re-autenticação.
      await notifier.clearActiveTokens();
    },
  );
});

// ── Dio configurado com AuthInterceptor ───────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  return buildDio(authInterceptor: ref.watch(authInterceptorProvider));
});

// ── Repositório & Use Cases ───────────────────────────────────────────────────

final _authDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDataSourceProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);

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

  Future<void> login(
    String email,
    String password, {
    bool keepLoggedIn = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(loginUseCaseProvider);
      final account = await useCase(email: email, password: password);
      final accountStore = ref.read(accountStoreProvider.notifier);
      final previous = ref
          .read(accountStoreProvider)
          .accounts
          .where((item) => item.userId == account.userId)
          .firstOrNull;

      // O AuthInterceptor obtém o token diretamente do AccountStore. Portanto,
      // a sessão precisa ser gravada antes das consultas autenticadas de
      // patotas e jogadores. Na ordem anterior essas chamadas saíam sem o novo
      // token (ou com o token vencido da mesma conta) e o login terminava com
      // uma patota aparentemente vazia.
      final authenticated = account.copyWith(
        activeGroupId: previous?.activeGroupId,
        activePlayerId: previous?.activePlayerId,
        groupAdminIds: previous?.groupAdminIds,
        groupFinanceiroIds: previous?.groupFinanceiroIds,
        activeGroupIsAdmin: previous?.activeGroupIsAdmin,
        activeGroupIsFinanceiro: previous?.activeGroupIsFinanceiro,
        keepLoggedIn: keepLoggedIn,
      );
      await accountStore.upsertAccount(authenticated);

      // Um 401 anterior pode ter armado o guard do interceptor. A nova sessão
      // já é válida e deve poder fazer as consultas de inicialização.
      ref.read(authInterceptorProvider).resetUnauthorizedGuard();

      final dataSource = ref.read(_authDataSourceProvider);

      // Busca em paralelo: roles de grupo + grupos do jogador.
      final (roles, groupIds) = await (
        dataSource.fetchGroupRoles(account.userId),
        dataSource.fetchMyGroupIds(),
      ).wait;

      // Considera também patotas em que a conta é admin/financeiro. Um usuário
      // pode administrar uma patota mesmo antes de possuir jogador vinculado.
      final candidateGroupIds = <String>[
        ...groupIds,
        ...?roles?['adminIds'],
        ...?roles?['financeiroIds'],
      ];
      final activeGroupId = _resolveActiveGroupId(
        previousGroupId: authenticated.activeGroupId,
        candidateGroupIds: candidateGroupIds,
      );

      final enriched = authenticated.copyWith(
        groupAdminIds: roles?['adminIds'] ?? authenticated.groupAdminIds,
        groupFinanceiroIds:
            roles?['financeiroIds'] ?? authenticated.groupFinanceiroIds,
        activeGroupId: activeGroupId,
      );

      await accountStore.upsertAccount(enriched);

      // Confirma o papel na patota já no login. Sem isto, quem tem uma patota só
      // entrava com activeGroupIsAdmin nulo e dependia do array de fallback.
      if (activeGroupId != null && activeGroupId.isNotEmpty) {
        await refreshMyGroupRoles(activeGroupId);
      }
    });
  }

  Future<void> register({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(registerUseCaseProvider);
      await useCase(
        userName: userName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
    });
  }

  Future<void> logout() async {
    await ref.read(accountStoreProvider.notifier).logout();
    ref.invalidateSelf();
  }

  /// Consulta o backend especificamente para [groupId] e atualiza
  /// [activeGroupIsAdmin] / [activeGroupIsFinanceiro] na conta ativa.
  /// Chamado toda vez que o usuário troca de patota.
  Future<void> refreshMyGroupRoles(String groupId) async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    try {
      final dataSource = ref.read(_authDataSourceProvider);
      final roles = await dataSource.fetchMyGroupRoles(groupId);
      // Falhou a consulta: não sobrescreve com `false`, senão um erro de rede
      // rebaixa o admin e ele cai na tela "Sem acesso".
      if (roles == null) return;
      await ref.read(accountStoreProvider.notifier).upsertAccount(
            account.copyWith(
              activeGroupIsAdmin: roles.isAdmin,
              activeGroupIsFinanceiro: roles.isFinanceiro,
            ),
          );
    } catch (_) {
      // silencioso — UI já usa os arrays de fallback
    }
  }

  /// Re-busca os groupAdminIds e groupFinanceiroIds da conta ativa.
  /// Chamado no startup e no resume para refletir mudanças de role feitas
  /// enquanto o usuário estava fora (ex: foi promovido a admin).
  Future<void> refreshRoles() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    try {
      final dataSource = ref.read(_authDataSourceProvider);
      final roles = await dataSource.fetchGroupRoles(account.userId);
      if (roles == null) {
        return; // falha de rede não pode apagar permissão salva
      }
      await ref.read(accountStoreProvider.notifier).upsertAccount(
            account.copyWith(
              groupAdminIds: roles['adminIds'],
              groupFinanceiroIds: roles['financeiroIds'],
            ),
          );

      // Reconfirma o papel na patota ativa — é o valor que o isGroupAdmin usa.
      final groupId = account.activeGroupId;
      if (groupId != null && groupId.isNotEmpty) {
        await refreshMyGroupRoles(groupId);
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
      final dataSource = ref.read(_authDataSourceProvider);
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
      await ref.read(accountStoreProvider.notifier).upsertAccount(
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
        await refreshMyGroupRoles(resolvedGroupId);
      }
    } catch (_) {}
  }

  /// Tenta renovar o token proativamente antes de expirar.
  /// Delega ao AuthInterceptor para reutilizar a lógica de envelope e mutex.
  Future<void> proactiveRefresh() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    if (!JwtHelper.isExpiring(account.accessToken, bufferSeconds: 300)) return;

    debugPrint('🔄 proactiveRefresh: token expirando, renovando...');
    final newToken = await ref.read(authInterceptorProvider).tryRefresh();
    if (newToken != null) {
      debugPrint('✅ proactiveRefresh: token renovado');
    } else {
      debugPrint(
          '⚠ proactiveRefresh: renovação falhou (interceptor tratará 401)');
    }
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

// ── Serviço de refresh proativo ───────────────────────────────────────────────

/// Agenda renovação do token 5 minutos antes de expirar.
/// Deve ser assistido por um widget de longa duração (ShellPage).
final tokenRefreshServiceProvider = Provider<void>((ref) {
  final token = ref.watch(
    accountStoreProvider.select((s) => s.activeAccount?.accessToken),
  );
  if (token == null) return;

  final expiresAt = JwtHelper.expiresAt(token);
  if (expiresAt == null) return;

  final refreshAt = expiresAt.subtract(const Duration(minutes: 5));
  final delay = refreshAt.difference(DateTime.now());

  Timer? timer;

  if (delay.isNegative || delay.inSeconds < 30) {
    // Token já próximo do limite — agenda refresh imediato
    Future.microtask(
      () => ref.read(authNotifierProvider.notifier).proactiveRefresh(),
    );
  } else {
    timer = Timer(delay, () {
      ref.read(authNotifierProvider.notifier).proactiveRefresh();
    });
  }

  ref.onDispose(() => timer?.cancel());
});
