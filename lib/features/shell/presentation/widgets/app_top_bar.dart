import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/push/notification_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../groups/presentation/providers/group_invites_provider.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountStoreProvider);
    final active        = accountState.activeAccount;
    final playersAsync  = ref.watch(myPlayersProvider);
    // Durante re-fetch (isRefreshing) valueOrNull expõe dados da conta anterior.
    // Usar lista vazia enquanto carrega para não passar patotas obsoletas ao menu.
    final players       = playersAsync.isLoading ? <MyPlayer>[] : (playersAsync.valueOrNull ?? []);
    final activePlayer  = ref.watch(activePlayerProvider);

    // Bootstrap: igual ao site — quando players carregam e o account não tem
    // activePlayerId/activeGroupId, persiste o primeiro player automaticamente.
    // Também atualiza activeGroupIsAdmin/Financeiro na inicialização, para que
    // os menus de admin apareçam corretamente sem precisar trocar de patota.
    ref.listen(myPlayersProvider, (_, next) {
      next.whenData((list) {
        if (list.isEmpty) return;
        final acc = ref.read(accountStoreProvider).activeAccount;
        if (acc == null) return;

        String? groupId = acc.activeGroupId;

        if (acc.activePlayerId == null || acc.activeGroupId == null) {
          final first = list.first;
          groupId = acc.activeGroupId ?? first.groupId;
          ref.read(accountStoreProvider.notifier).patchActive(
            (a) => a.copyWith(
              activePlayerId: a.activePlayerId ?? first.playerId,
              activeGroupId:  a.activeGroupId  ?? first.groupId,
            ),
          );
        }

        // Refresh roles do grupo ativo (cobre login inicial + retorno ao app)
        if (groupId != null) {
          ref.read(authNotifierProvider.notifier).refreshMyGroupRoles(groupId);
        }
      });
    });

    final displayName = activePlayer?.playerName
        ?? active?.name
        ?? active?.email
        ?? '—';
    final subtitle = activePlayer?.groupName;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      // ── LEFT: avatar + nome + grupo ──────────────────────────────
      title: Row(
        children: [
          AvatarWidget(name: displayName, size: 34),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.slate400
                          : AppColors.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      // ── RIGHT: convites + botão de usuário ───────────────────────
      actions: [
        _NotificationBell(),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _UserMenuButton(
            active:       active,
            accounts:     accountState.accounts,
            activeId:     accountState.activeAccountId,
            players:      players,
            activePlayer: activePlayer,
          ),
        ),
      ],
    );
  }
}

// ── Sino de notificações ──────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tenta o endpoint unificado; fallback para convites de grupo se falhar.
    final unreadAsync = ref.watch(notifUnreadCountProvider);
    final fallback    = ref.watch(myGroupInviteCountProvider).valueOrNull ?? 0;
    final count       = unreadAsync.maybeWhen(
      data:    (n) => n > 0 ? n : fallback,
      orElse:  () => fallback,
    );

    return IconButton(
      tooltip:  'Notificações',
      onPressed: () => _openSheet(context, ref),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (count > 0)
            Positioned(
              top: -2, right: -2,
              child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationSheet(),
    );
  }
}

// ── Sheet de notificações ─────────────────────────────────────────────────────

class _NotificationSheet extends ConsumerStatefulWidget {
  const _NotificationSheet();

  @override
  ConsumerState<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<_NotificationSheet> {

  // Optimistic local read-state overlay (id → isRead).
  final Map<String, bool> _readOverlay = {};

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead || (_readOverlay[n.id] ?? false)) return;
    setState(() => _readOverlay[n.id] = true);
    try {
      await ref.read(notificationsDsProvider).markRead(n.id);
      ref.invalidate(notifUnreadCountProvider);
    } catch (_) {
      // rollback
      if (mounted) setState(() => _readOverlay.remove(n.id));
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    for (final n in notifications) {
      setState(() => _readOverlay[n.id] = true);
    }
    try {
      await ref.read(notificationsDsProvider).markAllRead();
      ref.invalidate(notifUnreadCountProvider);
      ref.invalidate(myNotificationsProvider);
    } catch (_) {
      if (mounted) setState(() => _readOverlay.clear());
    }
  }

  void _navigate(BuildContext ctx, AppNotification n) {
    _markRead(n);
    Navigator.pop(ctx);

    // actionUrl explícito tem prioridade
    if (n.actionUrl != null && n.actionUrl!.isNotEmpty) {
      ctx.push(n.actionUrl!);
      return;
    }

    // Usa dataJson (IDs) para montar a rota mais específica possível
    final route = notificationRoute(n.type, n.dataJson ?? {});
    if (route.isNotEmpty) ctx.push(route);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'match_invite':
      case 'match_invite_reminder':
      case 'match_started':
      case 'match_ended':
      case 'match_finalized':
      case 'match_no_quorum':
      case 'teams_assigned':
      case 'attendance_accepted':
      case 'attendance_rejected':
        return Icons.sports_soccer_rounded;

      case 'match_mvp':
      case 'mvp_voting_reminder':
        return Icons.emoji_events_rounded;

      case 'poll_created':
      case 'poll_closed':
      case 'poll_reminder':
      case 'poll_deadline_changed':
        return Icons.how_to_vote_rounded;

      case 'event_created':
      case 'event_deleted':
      case 'event_reminder':
        return Icons.calendar_month_rounded;

      case 'payment_pending':
      case 'payment_confirmed':
      case 'monthly_payment_reminder':
      case 'extra_charge_discount':
        return Icons.payments_rounded;

      case 'group_invite':
        return Icons.group_add_rounded;

      case 'promoted_admin':
      case 'promoted_financeiro':
        return Icons.shield_rounded;

      case 'player_left':
      case 'player_removed':
      case 'player_removed_self':
        return Icons.person_remove_rounded;

      case 'bet_resolved':
      case 'bet_created':
        return Icons.casino_rounded;

      case 'birthday':
        return Icons.cake_rounded;

      case 'replay':
        return Icons.videocam_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'match_invite':
      case 'match_invite_reminder':
      case 'match_started':
      case 'match_ended':
      case 'match_finalized':
      case 'match_no_quorum':
      case 'teams_assigned':
      case 'attendance_accepted':
      case 'attendance_rejected':
        return const Color(0xFF3B82F6); // blue

      case 'match_mvp':
      case 'mvp_voting_reminder':
        return const Color(0xFFEAB308); // yellow

      case 'poll_created':
      case 'poll_closed':
      case 'poll_reminder':
      case 'poll_deadline_changed':
        return const Color(0xFFF59E0B); // amber

      case 'event_created':
      case 'event_deleted':
      case 'event_reminder':
        return const Color(0xFF6366F1); // indigo

      case 'payment_pending':
      case 'payment_confirmed':
      case 'monthly_payment_reminder':
      case 'extra_charge_discount':
        return const Color(0xFF10B981); // green

      case 'group_invite':
      case 'promoted_admin':
      case 'promoted_financeiro':
        return const Color(0xFF8B5CF6); // violet

      case 'player_left':
      case 'player_removed':
      case 'player_removed_self':
        return const Color(0xFFEF4444); // red

      case 'bet_resolved':
      case 'bet_created':
        return const Color(0xFFEC4899); // pink

      case 'birthday':
        return const Color(0xFFEC4899); // pink

      case 'replay':
        return const Color(0xFFEF4444); // red

      default:
        return const Color(0xFF64748B); // slate
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt   = AppDateUtils.parseOrNow(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
      if (diff.inHours   < 24) return '${diff.inHours}h atrás';
      if (diff.inDays    < 7)  return '${diff.inDays}d atrás';
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.slate900 : Colors.white;
    final divCol  = isDark ? AppColors.slate800 : AppColors.slate100;

    final notifsAsync = ref.watch(myNotificationsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.slate400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  'Notificações',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const Spacer(),
                notifsAsync.maybeWhen(
                  data: (list) {
                    final hasUnread = list.any(
                      (n) => !(_readOverlay[n.id] ?? n.isRead),
                    );
                    if (!hasUnread) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () => _markAllRead(list),
                      child: const Text(
                        'Marcar tudo como lido',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: divCol),

          // ── Body ──────────────────────────────────────────────────
          Flexible(
            child: notifsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _EmptyNotifs(
                isDark: isDark,
                icon:   Icons.wifi_off_rounded,
                label:  'Não foi possível carregar as notificações.',
              ),
              data: (notifs) {
                if (notifs.isEmpty) {
                  return _EmptyNotifs(
                    isDark: isDark,
                    icon:   Icons.notifications_off_outlined,
                    label:  'Nenhuma notificação por enquanto.',
                  );
                }

                return ListView.separated(
                  shrinkWrap:   true,
                  padding:      const EdgeInsets.only(bottom: 24),
                  itemCount:    notifs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1, indent: 72, color: divCol,
                  ),
                  itemBuilder: (ctx, i) {
                    final n    = notifs[i];
                    final read = _readOverlay[n.id] ?? n.isRead;
                    final col  = _colorFor(n.type);

                    return InkWell(
                      onTap: () => _navigate(ctx, n),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Icon circle
                            Container(
                              width: 40, height: 40,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color:  col.withValues(alpha: .15),
                                shape:  BoxShape.circle,
                              ),
                              child: Icon(_iconFor(n.type),
                                  size: 18, color: col),
                            ),

                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize:   13,
                                      fontWeight: read
                                          ? FontWeight.w400
                                          : FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.slate900,
                                    ),
                                  ),
                                  if (n.body.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.slate400
                                            : AppColors.slate500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (n.createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(n.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.slate500
                                            : AppColors.slate400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Unread dot
                            if (!read)
                              Container(
                                margin: const EdgeInsets.only(top: 4, left: 8),
                                width:  8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyNotifs extends StatelessWidget {
  final bool     isDark;
  final IconData icon;
  final String   label;

  const _EmptyNotifs({
    required this.isDark,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40,
              color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botão + menu do usuário ───────────────────────────────────────────────────

class _UserMenuButton extends ConsumerWidget {
  final Account?       active;
  final List<Account>  accounts;
  final String?        activeId;
  final List<MyPlayer> players;
  final MyPlayer?      activePlayer;

  const _UserMenuButton({
    required this.active,
    required this.accounts,
    required this.activeId,
    required this.players,
    required this.activePlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final displayName = activePlayer?.playerName
        ?? active?.name
        ?? active?.email
        ?? '—';
    final label = accounts.length > 1
        ? '${accounts.length} contas'
        : displayName;

    return GestureDetector(
      onTap: () => _openMenu(context, ref),
      child: Container(
        height:  36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(name: displayName, size: 24),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate300 : AppColors.slate600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size:  16,
              color: isDark ? AppColors.slate400 : AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserMenuSheet(
        accounts:     accounts,
        activeId:     activeId,
        players:      players,
        activePlayer: activePlayer,
        onAccountSwitch: (userId) {
          // Zera a seleção manual de jogador antes de qualquer coisa.
          ref.read(activePlayerIdProvider.notifier).state = null;
          // Ativa a conta destino limpando activeGroupId/activePlayerId dela,
          // evitando dados contaminados de trocas anteriores.
          ref.read(accountStoreProvider.notifier).switchTo(userId);
          // Reseta o guard de 401 para que o interceptor não trate a nova
          // conta como se já estivesse em processo de logout.
          ref.read(authInterceptorProvider).resetUnauthorizedGuard();
          // Força re-fetch imediato dos jogadores da nova conta.
          ref.invalidate(myPlayersProvider);
          // Invalida caches de notificações/convites (sempre assistidos, nunca
          // se auto-dispõem).
          ref.invalidate(notifUnreadCountProvider);
          ref.invalidate(myGroupInviteCountProvider);
          // Busca roles e grupo correto para a conta recém-ativada.
          ref.read(authNotifierProvider.notifier).refreshGroupMembership();
          context.go('/app');
        },
        onPlayerSwitch: (player) {
          ref.read(accountStoreProvider.notifier).patchActive(
            (a) => a.copyWith(
              activePlayerId:          player.playerId,
              activeGroupId:           player.groupId,
              activeGroupIsAdmin:      false,
              activeGroupIsFinanceiro: false,
            ),
          );
          ref.read(activePlayerIdProvider.notifier).state = player.playerId;
          ref.read(authNotifierProvider.notifier).refreshMyGroupRoles(player.groupId);
          context.go('/app');
        },
        onAddAccount: () {
          // Pequeno delay para garantir que o modal já fechou
          // antes de disparar a navegação do GoRouter.
          Future.microtask(() {
            if (context.mounted) context.go('/login?add=1');
          });
        },
        onLogout: () async {
          await ref.read(authNotifierProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
      ),
    );
  }
}

// ── Bottom Sheet ──────────────────────────────────────────────────────────────

class _UserMenuSheet extends StatelessWidget {
  final List<Account>  accounts;
  final String?        activeId;
  final List<MyPlayer> players;
  final MyPlayer?      activePlayer;
  final ValueChanged<String>   onAccountSwitch;
  final ValueChanged<MyPlayer> onPlayerSwitch;
  final VoidCallback           onAddAccount;
  final VoidCallback           onLogout;

  const _UserMenuSheet({
    required this.accounts,
    required this.activeId,
    required this.players,
    required this.activePlayer,
    required this.onAccountSwitch,
    required this.onPlayerSwitch,
    required this.onAddAccount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin:      const EdgeInsets.only(top: 12, bottom: 8),
                width:       36,
                height:      4,
                decoration:  BoxDecoration(
                  color:        AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Contas ──────────────────────────────────────────────
            _sectionLabel('Contas', isDark),
            ...accounts.map((a) {
              final isActive  = a.userId == activeId;
              final name      = a.name.isNotEmpty ? a.name : a.email;
              return _AccountTile(
                name:     name,
                email:    a.email,
                isActive: isActive,
                onTap: () {
                  Navigator.pop(context);
                  onAccountSwitch(a.userId);
                },
              );
            }),

            // ── Patota (se múltiplos jogadores) ─────────────────────
            if (players.length > 1) ...[
              _divider(isDark),
              _sectionLabel('Patota', isDark),
              ...players.map((p) {
                final isActive = p.playerId == activePlayer?.playerId;
                return _PlayerTile(
                  player:   p,
                  isActive: isActive,
                  onTap: () {
                    Navigator.pop(context);
                    onPlayerSwitch(p);
                  },
                );
              }),
            ],

            _divider(isDark),

            // ── Adicionar conta ──────────────────────────────────────
            _ActionTile(
              icon:      Icons.person_add_outlined,
              label:     'Adicionar conta',
              iconColor: isDark ? AppColors.slate400 : AppColors.slate600,
              bgColor:   isDark ? AppColors.slate800 : AppColors.slate100,
              onTap: () {
                Navigator.pop(context);
                onAddAccount();
              },
            ),

            _divider(isDark),

            // ── Sair ─────────────────────────────────────────────────
            _ActionTile(
              icon:      Icons.logout_rounded,
              label:     'Sair',
              iconColor: AppColors.rose500,
              bgColor:   isDark
                  ? AppColors.rose500.withAlpha(25)
                  : AppColors.rose50,
              labelColor: AppColors.rose600,
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w600,
            color:         isDark ? AppColors.slate500 : AppColors.slate400,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _divider(bool isDark) => Divider(
        height: 8,
        indent: 16,
        endIndent: 16,
        color: isDark ? AppColors.slate800 : AppColors.slate100,
      );
}

// ── Tiles ─────────────────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final String  name;
  final String  email;
  final bool    isActive;
  final VoidCallback onTap;

  const _AccountTile({
    required this.name,
    required this.email,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap:       onTap,
      tileColor:   isActive
          ? (isDark ? AppColors.slate800 : AppColors.slate50)
          : null,
      leading:     AvatarWidget(name: name, size: 32),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: name != email
          ? Text(email,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400))
          : null,
      trailing: isActive
          ? const Icon(Icons.check_rounded,
              color: AppColors.emerald500, size: 18)
          : null,
      dense: true,
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final MyPlayer player;
  final bool     isActive;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.player,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap:    onTap,
      leading:  AvatarWidget(name: player.playerName, size: 32),
      title: Text(
        player.playerName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: player.groupName.isNotEmpty
          ? Text(player.groupName,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400))
          : null,
      trailing: isActive
          ? const Icon(Icons.check_rounded,
              color: AppColors.emerald500, size: 18)
          : null,
      dense: true,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final Color     iconColor;
  final Color     bgColor;
  final Color?    labelColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width:       28,
        height:      28,
        decoration:  BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w500,
          color:      labelColor ??
              (isDark ? AppColors.slate300 : AppColors.slate700),
        ),
      ),
      dense: true,
    );
  }
}
