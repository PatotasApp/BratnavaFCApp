import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/jwt_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/app_top_bar.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../polls/presentation/providers/polls_provider.dart';

class ShellPage extends ConsumerStatefulWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined,          activeIcon: Icons.home,             label: 'Dashboard', path: '/app'),
    _TabItem(icon: Icons.sports_soccer_outlined, activeIcon: Icons.sports_soccer,    label: 'Partidas',  path: '/app/matches'),
    _TabItem(icon: Icons.group_outlined,         activeIcon: Icons.group,            label: 'Grupos',    path: '/app/groups'),
    _TabItem(icon: Icons.history_outlined,       activeIcon: Icons.history,          label: 'Histórico', path: '/app/history'),
    _TabItem(icon: Icons.more_horiz_outlined,    activeIcon: Icons.more_horiz,       label: 'Mais',      path: ''),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Atualiza roles e grupos no startup para refletir promoções/convites externos.
    Future.microtask(
      () => ref.read(authNotifierProvider.notifier).refreshGroupMembership(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTokenOnResume();
      // Atualiza roles e grupos ao voltar para o app.
      Future.microtask(
        () => ref.read(authNotifierProvider.notifier).refreshGroupMembership(),
      );
    }
  }

  Future<void> _checkTokenOnResume() async {
    final account = ref.read(accountStoreProvider).activeAccount;
    if (account == null) return;
    if (JwtHelper.isExpiring(account.accessToken, bufferSeconds: 300)) {
      await ref.read(authNotifierProvider.notifier).proactiveRefresh();
    }
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length - 1; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Mantém o serviço de refresh ativo enquanto o shell estiver na tela.
    ref.watch(tokenRefreshServiceProvider);

    final selected = _selectedIndex(context);
    // Key forces full widget subtree recreation on account switch, clearing
    // any widget-local state (timers, refresh flags) from the previous account.
    final accountKey = ref.watch(
      accountStoreProvider.select((s) => s.activeAccountId),
    );

    return Scaffold(
      appBar: const AppTopBar(),
      body: KeyedSubtree(
        key: ValueKey(accountKey),
        child: widget.child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          if (_tabs[i].path.isNotEmpty) {
            context.go(_tabs[i].path);
          } else {
            _openDrawer(context);
          }
        },
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon:         Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon),
                  label:        t.label,
                ))
            .toList(),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _MoreSheet(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   path;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet();

  // (icon, label, path, hasBadge, adminOnly)
  static const _items = [
    (Icons.calendar_month_outlined,  'Calendário',            '/app/calendar',       false, false),
    (Icons.palette_outlined,         'Cores',                 '/app/team-colors',    false, false),
    (Icons.bar_chart_outlined,       'Visual Stats',          '/app/visual-stats',   false, true),
    (Icons.timeline_outlined,        'Histórico do Jogador',  '/app/player-history', false, true),
    (Icons.people_alt_outlined,      'Monte seu Time 🎉',     '/app/team-builder',   false, false),
    (Icons.payments_outlined,        'Pagamentos',            '/app/payments',       false, false),
    (Icons.how_to_vote_outlined,     'Votações',              '/app/polls',          true,  false),
    (Icons.event_busy_outlined,      'Ausências',             '/app/absences',       false, false),
    (Icons.monetization_on_outlined,  'Bet',                   '/app/bet',            false, false),
    (Icons.video_library_outlined,   'Replays',               '/app/replays',        false, true),
    (Icons.cake_outlined,            'Aniversários',          '/app/birthdays',      false, true),
    (Icons.settings_outlined,        'Configurações',         '/app/settings',       false, true),
    (Icons.manage_accounts_outlined, 'Usuários',              '/app/admin/users',    false, false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account      = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId      = account?.activeGroupId ?? activePlayer?.groupId;

    final isAdmin = groupId != null &&
        groupId.isNotEmpty &&
        (account?.isGroupAdmin(groupId) ?? false);

    final pendingCount = groupId != null
        ? ref.watch(pendingPollsCountProvider(groupId)).valueOrNull ?? 0
        : 0;

    // Filter out admin-only items for regular players
    final visibleItems = _items.where((item) => !item.$5 || isAdmin).toList();

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:        AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...visibleItems.map(
              (item) => ListTile(
                leading: item.$4 && pendingCount > 0
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.$1, size: 22),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text('$pendingCount',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      )
                    : Icon(item.$1, size: 22),
                title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  context.go(item.$3);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
