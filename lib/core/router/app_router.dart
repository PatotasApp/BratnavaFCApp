import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/account_store.dart';
import '../../features/account/presentation/pages/my_account_page.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/team_colors/presentation/pages/team_colors_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/match_details_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/group_settings/presentation/pages/group_settings_page.dart';
import '../../features/birthdays/presentation/pages/birthday_page.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/shell/presentation/pages/theme_page.dart';
import '../../features/visual_stats/presentation/pages/visual_stats_page.dart';
import '../../features/polls/presentation/pages/polls_page.dart';
import '../../features/matches/presentation/pages/matches_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/absences/presentation/pages/absences_page.dart';
import '../../features/bet/presentation/pages/bet_page.dart';
import '../../features/replays/presentation/pages/replay_vault_page.dart';
import '../../features/player_spotlight/presentation/pages/player_spotlight_page.dart';
import '../../features/player_history/presentation/pages/player_history_page.dart';
import '../../features/groups/presentation/pages/group_invites_page.dart';
import '../../features/team_builder/presentation/pages/team_builder_page.dart';
import '../../features/conquistas/presentation/pages/conquistas_page.dart';
import '../../features/conquistas/presentation/pages/public_profile_page.dart';
import '../../core/push/local_notifications.dart';

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

// ── NavigatorKey global (compartilhado com PushService) ──────────────────────

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (_) => GlobalKey<NavigatorState>(),
);

// ── Router Provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final navigatorKey = ref.watch(navigatorKeyProvider);
  final authListenable = _AccountStateListenable(ref);

  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: authListenable,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = ref.read(accountStoreProvider).isLoggedIn;
      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' || path == '/register' || path.startsWith('/login');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/app';
      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterPage(),
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
            ),
          ),
          GoRoute(
            path: '/app/groups',
            builder: (_, __) => const GroupsPage(),
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
            builder: (_, __) => const TeamColorsPage(),
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
            builder: (_, __) => const PollsPage(showEvents: true),
          ),
          GoRoute(
            path: '/app/polls/votes',
            builder: (_, __) => const PollsPage(showEvents: false),
          ),
          GoRoute(
            path: '/app/birthdays',
            builder: (_, __) => const BirthdayPage(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (_, __) => const GroupSettingsPage(),
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
            path: '/app/bet',
            builder: (_, __) => const BetPage(),
          ),
          GoRoute(
            path: '/app/replays',
            builder: (_, __) => const ReplayVaultPage(),
          ),
          GoRoute(
            path: '/app/spotlight',
            builder: (_, __) => const PlayerSpotlightPage(),
          ),
          GoRoute(
            path: '/app/player-history',
            builder: (_, __) => const PlayerHistoryPage(),
          ),
          GoRoute(
            path: '/app/invites',
            builder: (_, __) => const GroupInvitesPage(),
          ),
          GoRoute(
            path: '/app/account',
            builder: (_, __) => const MyAccountPage(),
          ),
          GoRoute(
            path: '/app/team-builder',
            builder: (_, __) => const TeamBuilderPage(),
          ),
          GoRoute(
            path: '/app/conquistas',
            builder: (_, __) => const ConquistasPage(),
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
class _AccountStateListenable extends ChangeNotifier {
  final Ref _ref;

  _AccountStateListenable(this._ref) {
    _ref.listen<AccountState>(accountStoreProvider, (_, __) {
      notifyListeners();
    });
  }
}
