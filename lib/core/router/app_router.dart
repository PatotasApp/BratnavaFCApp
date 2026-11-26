import '../../features/billing/presentation/group_plan_page.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/providers/account_store.dart';
import '../../features/discovery/presentation/pages/guest_match_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/feature_flags.dart';
import '../../features/moderation/moderation.dart';
import '../../features/auth/presentation/pages/email_login_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/session_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/team_colors/presentation/pages/team_colors_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/match_details_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/discovery/presentation/pages/discovery_search_page.dart';
import '../../features/discovery/presentation/pages/discovery_group_profile_page.dart';
import '../../features/discovery/presentation/pages/discovery_applicants_page.dart';
import '../../features/discovery/presentation/pages/discovery_invitations_page.dart';
import '../../features/group_settings/presentation/pages/group_settings_page.dart';
import '../../features/birthdays/presentation/pages/birthday_page.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/shell/domain/shell_navigation_policy.dart';
import '../../features/shell/presentation/pages/theme_page.dart';
import '../../features/visual_stats/presentation/pages/visual_stats_page.dart';
import '../../features/polls/presentation/pages/polls_page.dart';
import '../../features/matches/presentation/pages/matches_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/absences/presentation/pages/absences_page.dart';
import '../../features/replays/presentation/pages/replay_vault_page.dart';
import '../../features/replays/presentation/providers/replay_access_provider.dart';
import '../../features/player_spotlight/presentation/pages/player_spotlight_page.dart';
import '../../features/retrospective/presentation/pages/retrospective_page.dart';
import '../../features/player_history/presentation/pages/player_history_page.dart';
import '../../features/team_builder/presentation/pages/team_builder_page.dart';
import '../../features/conquistas/presentation/pages/conquistas_page.dart';
import '../../features/conquistas/presentation/pages/public_profile_page.dart';
import '../../features/championships/presentation/pages/championships_page.dart';
import '../../features/championships/presentation/pages/championship_wizard_page.dart';
import '../../features/championships/presentation/pages/championship_detail_page.dart';
import '../../features/seasons/presentation/pages/season_summary_page.dart';
import '../../features/seasons/presentation/pages/seasons_settings_page.dart';
import '../../core/push/local_notifications.dart';
import '../../features/share/presentation/share_link_page.dart';
import '../share/pending_share_link.dart';
import '../share/share_links.dart';
import '../../features/group_spreadsheets/presentation/group_spreadsheets_page.dart';
import '../onboarding/new_group_tour_storage.dart';

// ── Placeholder para rotas ainda não implementadas ────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage(this.title);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(
            '$title\nem desenvolvimento',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
}

// ── Página temporária de Partidas com botão de teste de push ─────────────────
class _MatchesTestPage extends StatelessWidget {
  const _MatchesTestPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partidas')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Partidas\nem desenvolvimento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            // ── BOTÃO TEMPORÁRIO DE TESTE ───────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Simular convite de partida'),
              onPressed: () => LocalNotifications.showMatchInvite(
                title: 'Convite para partida',
                body:
                    'Você foi convidado para uma partida. Confirme sua presença!',
                groupId: '00000000-0000-0000-0000-000000000001', // placeholder
                matchId: '00000000-0000-0000-0000-000000000002', // placeholder
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tela de espera da sessão ─────────────────────────────────────────────────
//
// Cobre duas esperas: o SDK do Firebase lendo a sessão do disco no cold start, e
// o GET /me que traz identidade e permissões.
class _SessionLoadingPage extends StatelessWidget {
  const _SessionLoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ResumeNewGroupTourPage extends ConsumerStatefulWidget {
  const _ResumeNewGroupTourPage();

  @override
  ConsumerState<_ResumeNewGroupTourPage> createState() =>
      _ResumeNewGroupTourPageState();
}

class _ResumeNewGroupTourPageState
    extends ConsumerState<_ResumeNewGroupTourPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  Future<void> _resume() async {
    if (mounted) setState(() => _error = null);
    final account = ref.read(accountStoreProvider).activeAccount;
    final pending =
        ref.read(newGroupTourStorageProvider).readForCreator(account?.userId);
    if (pending == null) {
      if (mounted) context.go('/app');
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).selectActiveGroup(
            groupId: pending.groupId,
          );
      if (mounted) context.go(pending.location);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível reabrir a patota do tour.';
        });
      }
    }
  }

  Future<void> _skip() async {
    await ref.read(newGroupTourStorageProvider).clear();
    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Retomando o tour da sua nova patota…'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 42),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _resume,
                        child: const Text('Tentar novamente'),
                      ),
                      TextButton(
                        onPressed: _skip,
                        child: const Text('Pular tour'),
                      ),
                    ],
                  ),
          ),
        ),
      );
}

// ── NavigatorKey global (compartilhado com PushService) ──────────────────────

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (_) => GlobalKey<NavigatorState>(),
);

// ── Router Provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final navigatorKey = ref.watch(navigatorKeyProvider);
  final authListenable = _SessionListenable(ref);
  final pendingShare = PendingShareLink();

  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: authListenable,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      // /forgot-password é alcançável nos dois estados: deslogado (esqueceu a
      // senha) e logado (troca de senha vem de Minha conta). Por isso não entra
      // em isAuthRoute, que redireciona para /app quando há sessão.
      if (path == '/forgot-password') return null;

      final isAuthRoute =
          path == '/login' || path == '/login/email' || path == '/register';

      // 1. O SDK ainda está lendo a sessão do disco. Tratar este instante como
      //    "deslogado" chutaria para o login quem estava autenticado — é o bug
      //    clássico de cold start.
      if (session.initializing) {
        pendingShare.remember(state.uri);
        return path == '/splash' ? null : '/splash';
      }

      // 2. Sem sessão no Firebase. Link compartilhado (perfil, partida…) fica
      //    guardado e abre depois do login.
      if (!session.isAuthenticated) {
        pendingShare.remember(state.uri);
        return isAuthRoute ? null : '/login';
      }

      // 3. Tem sessão, mas o GET /me ainda não voltou. Esperar o PERFIL, não só
      //    a sessão: nome, GUID interno e permissões vêm dele, e entrar antes
      //    renderiza o app inteiro com os fallbacks — patota vazia, sem admin.
      //
      //    `forbidden` e `error` seguem para o app de propósito: o que fazer com
      //    conta inativa ou e-mail não verificado é decisão de produto, não
      //    desta rota.
      if (session.profileStatus == ProfileStatus.idle ||
          session.profileStatus == ProfileStatus.loading) {
        pendingShare.remember(state.uri);
        return path == '/splash' ? null : '/splash';
      }

      final account = ref.read(accountStoreProvider).activeAccount;
      final pendingTour =
          ref.read(newGroupTourStorageProvider).readForCreator(account?.userId);

      if (isAuthRoute || path == '/splash') {
        if (pendingTour != null &&
            account?.activeGroupId?.toLowerCase() !=
                pendingTour.groupId.toLowerCase()) {
          return '/resume-new-group-tour';
        }
        return pendingTour?.location ?? pendingShare.take() ?? '/app';
      }

      // O onboarding iniciado pelo criador é uma tarefa pendente, não um
      // estado apenas da rota. Reabrir o app (ou sair da tela sem concluir)
      // retorna à etapa persistida até finalizar ou escolher "Pular tour".
      if (pendingTour != null) {
        final activeGroupId = account?.activeGroupId?.toLowerCase();
        if (activeGroupId != pendingTour.groupId.toLowerCase()) {
          return path == '/resume-new-group-tour'
              ? null
              : '/resume-new-group-tour';
        }
        final isCurrentTourPage = path == pendingTour.path &&
            state.uri.queryParameters['tour'] == 'true';
        if (!isCurrentTourPage) return pendingTour.location;
      }

      // Convidado de fora (sem patota ativa): notificações de partida levam à
      // tela dele, não às telas da patota, que ele não enxerga.
      if (account != null && account.activeGroupId == null) {
        final matchId = state.uri.queryParameters['matchId'];
        if (path == '/app/matches' && matchId != null && matchId.isNotEmpty) {
          return '/app/guest-match/$matchId';
        }
        final history =
            RegExp(r'^/app/history/[^/]+/([^/]+)$').firstMatch(path);
        if (history != null) return '/app/guest-match/${history.group(1)}';
      }

      final guestRedirect = guestOnlyRedirect(
        location: path,
        isGuestOnly: account?.isGuestOnly ?? false,
      );
      if (guestRedirect != null) return guestRedirect;

      // A tela continua implementada para futura reativação, mas não pode ser
      // aberta por link ou navegação antiga enquanto o fluxo externo estiver
      // desligado.
      if (!FeatureFlags.externalPlayerInteractionsEnabled &&
          path == '/app/applicants') {
        return '/app';
      }

      return null;
    },
    routes: [
      // ── Links compartilhados (App Links / Universal Links) ────────
      // Mesmos caminhos do site (lib/core/share/share_links.dart).
      GoRoute(
        path: '/perfil/:userId',
        redirect: (_, state) =>
            '/app/profile/${state.pathParameters['userId']}',
      ),
      GoRoute(
        path: '/patota/:groupId',
        builder: (_, state) =>
            SharedGroupLinkPage(groupId: state.pathParameters['groupId']!),
      ),
      for (final kind in ShareKind.values.where((k) => k.isInternal))
        GoRoute(
          path: '/${kind.path}/:id',
          builder: (_, state) => SharedContentLinkPage(
              kind: kind, id: state.pathParameters['id']!),
        ),
      // ── Auth ──────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SessionLoadingPage(),
      ),
      GoRoute(
        path: '/resume-new-group-tour',
        builder: (_, __) => const _ResumeNewGroupTourPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/login/email',
        builder: (_, __) => const EmailLoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordPage(
          // Pré-preenche quando vem da tela Minha conta de quem já está logado.
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),

      // ── App shell ─────────────────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: '/app/matches',
            builder: (_, state) => MatchesPage(
              initialMatchId: state.uri.queryParameters['matchId'],
              onboarding: state.uri.queryParameters['tour'] == 'true',
            ),
          ),
          GoRoute(
            path: '/app/groups',
            builder: (_, state) => GroupsPage(
              openCreateSheet: state.uri.queryParameters['create'] == 'true',
            ),
          ),
          GoRoute(
            path: '/app/search',
            builder: (_, __) => const DiscoverySearchPage(),
          ),
          GoRoute(
            path: '/app/discover/groups/:groupId',
            builder: (_, state) => DiscoveryGroupProfilePage(
              groupId: state.pathParameters['groupId'] ?? '',
              groupName: state.uri.queryParameters['name'],
            ),
          ),
          GoRoute(
            path: '/app/applicants',
            builder: (_, __) => const DiscoveryApplicantsPage(),
          ),
          GoRoute(
            path: '/app/match-invitations',
            builder: (_, __) => const DiscoveryInvitationsPage(),
          ),
          GoRoute(
            path: '/app/guest-match/:matchId',
            builder: (_, state) =>
                GuestMatchPage(matchId: state.pathParameters['matchId']!),
          ),
          GoRoute(
            path: '/app/history',
            builder: (_, __) => const HistoryPage(),
          ),
          GoRoute(
            path: '/app/history/:groupId/:matchId',
            builder: (_, state) => MatchDetailsPage(
              groupId: state.pathParameters['groupId'] ?? '',
              matchId: state.pathParameters['matchId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/app/calendar',
            builder: (_, __) => const CalendarPage(),
          ),
          GoRoute(
            path: '/app/team-colors',
            builder: (_, state) => TeamColorsPage(
              onboarding: state.uri.queryParameters['tour'] == 'true',
            ),
          ),
          GoRoute(
            path: '/app/visual-stats',
            builder: (_, __) => const VisualStatsPage(),
          ),
          GoRoute(
            path: '/app/payments',
            builder: (_, __) => const PaymentsPage(),
          ),
          GoRoute(
            path: '/app/polls',
            builder: (_, __) => const PollsPage(),
          ),
          GoRoute(
            path: '/app/polls/events',
            builder: (_, state) => PollsPage(
              showEvents: true,
              initialPollId: state.uri.queryParameters['pollId'],
            ),
          ),
          GoRoute(
            path: '/app/polls/votes',
            builder: (_, state) => PollsPage(
              showEvents: false,
              initialPollId: state.uri.queryParameters['pollId'],
            ),
          ),
          GoRoute(
            path: '/app/birthdays',
            builder: (_, __) => const BirthdayPage(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (_, state) => GroupSettingsPage(
              onboarding: state.uri.queryParameters['tour'] == 'true',
              initialTourTab:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/app/spreadsheets',
            builder: (_, state) => GroupSpreadsheetsPage(
              groupId: state.uri.queryParameters['groupId'],
            ),
          ),
          GoRoute(
            path: '/app/theme',
            builder: (_, __) => const ThemePage(),
          ),
          GoRoute(
            path: '/app/absences',
            builder: (_, __) => const AbsencesPage(),
          ),
          GoRoute(
            path: '/app/replays',
            redirect: (_, __) =>
                ref.read(activeGroupReplayUiProvider) ? null : '/app',
            builder: (_, __) => const ReplayVaultPage(),
          ),
          GoRoute(
            path: '/app/spotlight',
            builder: (_, __) => const PlayerSpotlightPage(),
          ),
          GoRoute(
            path: '/app/retrospectiva',
            builder: (_, __) => const RetrospectivePage(),
          ),
          GoRoute(
            path: '/app/player-history',
            builder: (_, __) => const PlayerHistoryPage(),
          ),
          GoRoute(
            path: '/app/invites',
            redirect: (_, __) => '/app/account?tab=invites',
          ),
          GoRoute(
            path: '/app/account',
            builder: (_, __) => const MyAccountPage(),
          ),
          GoRoute(
            path: '/app/account/blocked',
            builder: (_, __) => const BlockedUsersPage(),
          ),
          GoRoute(
            path: '/app/team-builder',
            builder: (_, __) => const TeamBuilderPage(),
          ),
          GoRoute(
            path: '/app/plano',
            builder: (_, state) => GroupPlanPage(
              groupId: state.uri.queryParameters['groupId'],
            ),
          ),
          GoRoute(
            path: '/app/conquistas',
            builder: (_, __) => const ConquistasPage(),
          ),
          GoRoute(
            path: '/app/seasons',
            builder: (_, __) => const SeasonsSettingsPage(),
          ),
          GoRoute(
            path: '/app/seasons/:seasonId',
            builder: (_, state) => SeasonSummaryPage(
              seasonId: state.pathParameters['seasonId']!,
            ),
          ),
          GoRoute(
            path: '/app/championships',
            builder: (_, __) => const ChampionshipsPage(),
          ),
          GoRoute(
            path: '/app/championships/new',
            builder: (_, __) => const ChampionshipWizardPage(),
          ),
          GoRoute(
            path: '/app/championships/:championshipId',
            builder: (_, state) => ChampionshipDetailPage(
              championshipId: state.pathParameters['championshipId']!,
            ),
          ),
          GoRoute(
            path: '/app/profile/:userId',
            builder: (_, state) => PublicProfilePage(
              userId: state.pathParameters['userId'] ?? '',
            ),
          ),
        ],
      ),
    ],
  );
});

/// Conecta o Riverpod AccountState ao sistema de refresh do GoRouter.
class _SessionListenable extends ChangeNotifier {
  final Ref _ref;

  _SessionListenable(this._ref) {
    // Escuta a sessão do Firebase e o estado do perfil. Antes escutava o
    // AccountStore, que deixou de ser quem decide se há sessão.
    _ref.listen<SessionState>(sessionProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<AccountState>(accountStoreProvider, (_, __) {
      notifyListeners();
    });
  }
}
