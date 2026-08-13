import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/email_verification_banner.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/shell_navigation_policy.dart';
import '../widgets/app_top_bar.dart';

class ShellPage extends ConsumerStatefulWidget {
  final Widget child;

  const ShellPage({super.key, required this.child});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {
  static const _tabs = [
    _TabItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Dashboard',
        path: '/app'),
    _TabItem(
        icon: Icons.sports_soccer_outlined,
        activeIcon: Icons.sports_soccer,
        label: 'Partidas',
        path: '/app/matches'),
    _TabItem(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'Minha patota',
        path: '/app/groups'),
    _TabItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Histórico',
        path: '/app/history'),
    _TabItem(
        icon: Icons.more_horiz_outlined,
        activeIcon: Icons.more_horiz,
        label: 'Mais',
        path: ''),
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
      Future.microtask(_handleResume);
    }
  }

  Future<void> _handleResume() async {
    await ref.read(accountStoreProvider.notifier).reloadFromStorage();
    if (!mounted) return;
    await ref.read(authNotifierProvider.notifier).refreshGroupMembership();
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return shellNavigationIndexForPath(location);
  }

  @override
  Widget build(BuildContext context) {
    // O refresh de token deixou de existir aqui: o SDK do Firebase renova o ID
    // token sozinho, e o interceptor pega o token válido a cada request.

    final selected = _selectedIndex(context);
    // Key forces full widget subtree recreation on account switch, clearing
    // any widget-local state (timers, refresh flags) from the previous account.
    final accountKey = ref.watch(
      accountStoreProvider.select((s) => s.account?.userId),
    );

    return Scaffold(
      appBar: const AppTopBar(),
      body: Column(
        children: [
          // Fica acima de tudo e some sozinho quando o e-mail é verificado.
          // Não bloqueia navegação: verificar é recomendado, não exigido.
          const EmailVerificationBanner(),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(accountKey),
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PrototypeBottomNavigation(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          if (_tabs[i].path.isNotEmpty) {
            context.go(_tabs[i].path);
          } else {
            _openDrawer(context);
          }
        },
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _MoreSheet(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _PrototypeBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _PrototypeBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .96),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: PrototypeLayout.bottomNavigationHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: List.generate(_ShellPageState._tabs.length, (index) {
                final item = _ShellPageState._tabs[index];
                final selected = selectedIndex == index;

                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: item.label,
                    child: InkResponse(
                      radius: 34,
                      onTap: () => onDestinationSelected(index),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: PrototypeLayout.minimumTouchTarget,
                          minHeight: PrototypeLayout.minimumTouchTarget,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primaryContainer
                                    : AppColors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 19,
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet();

  static const _groups = [
    _MoreGroup(
      label: 'Desempenho',
      items: [
        _MoreItem(
          icon: Icons.bar_chart_outlined,
          label: 'Estatísticas',
          path: '/app/visual-stats',
          statsPermission: true,
        ),
        _MoreItem(
          icon: Icons.timeline_outlined,
          label: 'Meu Histórico',
          path: '/app/player-history',
        ),
        _MoreItem(
          icon: Icons.emoji_events_outlined,
          label: 'Conquistas',
          path: '/app/conquistas',
        ),
      ],
    ),
    _MoreGroup(
      label: 'Organização',
      items: [
        _MoreItem(
          icon: Icons.calendar_month_outlined,
          label: 'Calendário',
          path: '/app/calendar',
        ),
        _MoreItem(
          icon: Icons.event_busy_outlined,
          label: 'Ausências',
          path: '/app/absences',
        ),
        _MoreItem(
          icon: Icons.cake_outlined,
          label: 'Aniversários',
          path: '/app/birthdays',
        ),
        _MoreItem(
          icon: Icons.palette_outlined,
          label: 'Uniformes',
          path: '/app/team-colors',
        ),
        _MoreItem(
          icon: Icons.people_alt_outlined,
          label: 'Monte seu Time',
          path: '/app/team-builder',
        ),
      ],
    ),
    _MoreGroup(
      label: 'Social',
      items: [
        _MoreItem(
          icon: Icons.calendar_today_outlined,
          label: 'Eventos',
          path: '/app/polls/events',
        ),
        _MoreItem(
          icon: Icons.how_to_vote_outlined,
          label: 'Votações',
          path: '/app/polls/votes',
        ),
        _MoreItem(
          icon: Icons.monetization_on_outlined,
          label: 'Bet',
          path: '/app/bet',
        ),
        _MoreItem(
          icon: Icons.video_library_outlined,
          label: 'Replays',
          path: '/app/replays',
        ),
      ],
    ),
    _MoreGroup(
      label: 'Gestão',
      items: [
        _MoreItem(
          icon: Icons.payments_outlined,
          label: 'Pagamentos',
          path: '/app/payments',
        ),
        _MoreItem(
          icon: Icons.settings_outlined,
          label: 'Configurações',
          path: '/app/settings',
        ),
      ],
    ),
    _MoreGroup(
      label: 'Conta',
      items: [
        _MoreItem(
          icon: Icons.account_circle_outlined,
          label: 'Minha conta',
          path: '/app/account',
        ),
        _MoreItem(
          icon: Icons.palette_outlined,
          label: 'Tema',
          path: '/app/theme',
        ),
        _MoreItem(
          icon: Icons.mail_outline_rounded,
          label: 'Convites',
          path: '/app/invites',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;

    final isAdmin = groupId != null &&
        groupId.isNotEmpty &&
        (account?.isGroupAdmin(groupId) ?? false);
    final settings = groupId != null
        ? ref.watch(groupSettingsProvider(groupId)).valueOrNull
        : null;
    final canSeeStats = isAdmin || (settings?.showPlayerStats ?? false);

    return FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mais', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Recursos organizados por objetivo',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in _groups) ...[
                    Text(
                      group.label.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 320 ? 1 : 2;
                        const gap = 8.0;
                        final itemWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        final visibleItems = group.items.where((item) {
                          return isShellMenuItemVisible(
                            path: item.path,
                            isAdmin: isAdmin,
                            canSeeStats: canSeeStats,
                            requiresStatsPermission: item.statsPermission,
                          );
                        });

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final item in visibleItems)
                              SizedBox(
                                width: itemWidth,
                                child: PrototypeMenuTile(
                                  icon: Icon(item.icon),
                                  title: item.label,
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.go(item.path);
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreGroup {
  final String label;
  final List<_MoreItem> items;

  const _MoreGroup({required this.label, required this.items});
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String path;
  final bool statsPermission;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.path,
    this.statsPermission = false,
  });
}
