import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/god_mode_models.dart';
import '../providers/god_mode_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MAIN PAGE
// ══════════════════════════════════════════════════════════════════════════════

class GodModePage extends ConsumerStatefulWidget {
  const GodModePage({super.key});

  @override
  ConsumerState<GodModePage> createState() => _GodModePageState();
}

class _GodModePageState extends ConsumerState<GodModePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isGodMode {
    final account = ref.read(accountStoreProvider).activeAccount;
    return account?.roles.any((r) => r.toLowerCase() == 'godmode') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isGodMode) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 48,
                  color: isDark ? AppColors.slate600 : AppColors.slate300),
              const SizedBox(height: 12),
              Text(
                'Acesso restrito',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Rota do shell sem AppBar: precisa respeitar o inset da status bar.
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildHeader(isDark),
              ),
            ),
          ],
          body: Column(
            children: [
              Container(
                color: isDark ? AppColors.slate900 : AppColors.onDark,
                child: TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(text: 'Usuarios'),
                    Tab(text: 'Grupos'),
                  ],
                  labelColor: isDark ? AppColors.onDark : AppColors.slate900,
                  unselectedLabelColor:
                      isDark ? AppColors.slate500 : AppColors.slate400,
                  indicatorColor:
                      isDark ? AppColors.onDark : AppColors.slate900,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: const [
                    _UsersTab(),
                    _GroupsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkApp.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.onDark.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.onDark.withValues(alpha: .2)),
          ),
          child: const Icon(Icons.admin_panel_settings,
              size: 26, color: AppColors.onDark),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('God Mode',
              style: TextStyle(
                  color: AppColors.onDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          Text(
            'Painel de super-administrador',
            style: TextStyle(
                color: AppColors.onDark.withValues(alpha: .5), fontSize: 12),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA USUARIOS
// ══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(usersFilterProvider.notifier).setSearch(q);
    });
  }

  void _setStatus(UserStatusFilter s) {
    ref.read(usersFilterProvider.notifier).setStatus(s);
  }

  void _refresh() {
    ref.invalidate(pagedUsersProvider);
  }

  Future<void> _confirmToggleUser(
      BuildContext ctx, UserItemListDto user) async {
    final activate = !user.isActive;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(activate ? 'Ativar usuario' : 'Inativar usuario'),
        content: Text(
          activate
              ? 'Deseja ativar o usuario "${user.fullName}"?'
              : 'Deseja inativar o usuario "${user.fullName}"?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              activate ? 'Ativar' : 'Inativar',
              style: TextStyle(
                  color:
                      activate ? AppColors.primaryPressed : AppColors.rose500),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final ds = ref.read(godModeDsProvider);
      if (activate) {
        await ds.reactivateUser(user.id);
      } else {
        await ds.inactivateUser(user.id);
      }
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(activate
                  ? 'Usuario ativado com sucesso'
                  : 'Usuario inativado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    }
  }

  Future<void> _showChangePasswordDialog(
      BuildContext ctx, UserItemListDto user) async {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final newPassCtrl = TextEditingController();
    final currentPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureCurrent = true;

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Alterar senha — ${user.fullName}',
              style: const TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.onDark : AppColors.slate900,
                foregroundColor: isDark ? AppColors.slate900 : AppColors.onDark,
              ),
              onPressed: () async {
                final np = newPassCtrl.text.trim();
                final cp = currentPassCtrl.text.trim();
                if (np.isEmpty || cp.isEmpty) return;
                Navigator.pop(dialogCtx);
                try {
                  final ds = ref.read(godModeDsProvider);
                  await ds.changeUserPassword(user.id,
                      currentPassword: cp, newPassword: np);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Senha alterada com sucesso')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Erro ao alterar senha: $e'),
                      backgroundColor: AppColors.rose500,
                    ));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    newPassCtrl.dispose();
    currentPassCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(usersFilterProvider);
    final usersAsync = ref.watch(pagedUsersProvider);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar usuario...',
              hintStyle: TextStyle(
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                  fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: AppColors.slate400),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.slate800 : AppColors.slate100,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Filter chips ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: filter.status == UserStatusFilter.all,
                isDark: isDark,
                onTap: () => _setStatus(UserStatusFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ativos',
                selected: filter.status == UserStatusFilter.active,
                isDark: isDark,
                onTap: () => _setStatus(UserStatusFilter.active),
                activeColor: AppColors.primaryPressed,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Inativos',
                selected: filter.status == UserStatusFilter.inactive,
                isDark: isDark,
                onTap: () => _setStatus(UserStatusFilter.inactive),
                activeColor: AppColors.rose500,
              ),
            ],
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────────
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(extractDioError(e), isDark: isDark),
            data: (paged) {
              if (paged.items.isEmpty) {
                return _EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Nenhum usuario encontrado',
                  sub: filter.search.isNotEmpty
                      ? 'Tente um termo diferente'
                      : 'Nenhum usuario no sistema ainda',
                  isDark: isDark,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: paged.items.length + (paged.hasMore ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == paged.items.length) {
                      return _LoadMoreButton(
                        isDark: isDark,
                        onTap: () {
                          ref
                              .read(usersFilterProvider.notifier)
                              .setPage(filter.page + 1);
                        },
                      );
                    }
                    final user = paged.items[i];
                    return _UserCard(
                      user: user,
                      isDark: isDark,
                      onToggleActive: () => _confirmToggleUser(context, user),
                      onChangePassword: () =>
                          _showChangePasswordDialog(context, user),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // ── Total count ───────────────────────────────────────────────────────
        usersAsync.maybeWhen(
          data: (paged) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${paged.totalCount} usuario${paged.totalCount != 1 ? 's' : ''} encontrado${paged.totalCount != 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserItemListDto user;
  final bool isDark;
  final VoidCallback onToggleActive;
  final VoidCallback onChangePassword;

  const _UserCard({
    required this.user,
    required this.isDark,
    required this.onToggleActive,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor = isDark ? AppColors.slate900 : AppColors.onDark;
    final initials = _initials(user.fullName);
    final gradient = AppColors.gradientForName(user.fullName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                  color: AppColors.onDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _StatusBadge(isActive: user.isActive),
            ]),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              overflow: TextOverflow.ellipsis,
            ),
            if (user.roles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: user.roles
                    .map((r) => _RoleChip(role: r, isDark: isDark))
                    .toList(),
              ),
            ],
          ]),
        ),

        // Actions menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              size: 20,
              color: isDark ? AppColors.slate400 : AppColors.slate500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                  user.isActive
                      ? Icons.person_off_outlined
                      : Icons.person_outlined,
                  size: 18,
                  color: user.isActive
                      ? AppColors.rose500
                      : AppColors.primaryPressed,
                ),
                const SizedBox(width: 8),
                Text(user.isActive ? 'Inativar' : 'Ativar'),
              ]),
            ),
            const PopupMenuItem(
              value: 'password',
              child: Row(children: [
                Icon(Icons.lock_reset, size: 18, color: AppColors.slate500),
                SizedBox(width: 8),
                Text('Alterar senha'),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'toggle') onToggleActive();
            if (v == 'password') onChangePassword();
          },
        ),
      ]),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ABA GRUPOS
// ══════════════════════════════════════════════════════════════════════════════

class _GroupsTab extends ConsumerStatefulWidget {
  const _GroupsTab();

  @override
  ConsumerState<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends ConsumerState<_GroupsTab> {
  void _refresh() => ref.invalidate(godModeGroupsProvider);

  Future<void> _confirmToggleGroup(BuildContext ctx, GroupDto group) async {
    final activate = !group.isActive;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(activate ? 'Ativar grupo' : 'Inativar grupo'),
        content: Text(
          activate
              ? 'Deseja ativar o grupo "${group.name}"?'
              : 'Deseja inativar o grupo "${group.name}"?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              activate ? 'Ativar' : 'Inativar',
              style: TextStyle(
                  color:
                      activate ? AppColors.primaryPressed : AppColors.rose500),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final ds = ref.read(godModeDsProvider);
      if (activate) {
        await ds.reactivateGroup(group.groupId);
      } else {
        await ds.inactivateGroup(group.groupId);
      }
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(activate
                  ? 'Grupo ativado com sucesso'
                  : 'Grupo inativado com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.rose500,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(godModeGroupsProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(extractDioError(e), isDark: isDark),
      data: (groups) {
        if (groups.isEmpty) {
          return _EmptyState(
            icon: Icons.group_outlined,
            title: 'Nenhum grupo encontrado',
            sub: 'Nenhum grupo cadastrado no sistema',
            isDark: isDark,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: groups.length,
            itemBuilder: (ctx, i) {
              final group = groups[i];
              return _GroupCard(
                group: group,
                isDark: isDark,
                onToggleActive: () => _confirmToggleGroup(context, group),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final GroupDto group;
  final bool isDark;
  final VoidCallback onToggleActive;

  const _GroupCard({
    required this.group,
    required this.isDark,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor = isDark ? AppColors.slate900 : AppColors.onDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_outlined,
              size: 22, color: AppColors.slate400),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _StatusBadge(isActive: group.isActive),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.people_outline,
                  size: 14,
                  color: isDark ? AppColors.slate500 : AppColors.slate400),
              const SizedBox(width: 4),
              Text(
                '${group.playerCount} jogador${group.playerCount != 1 ? 'es' : ''}',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              if (group.createdAt != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_outlined,
                    size: 13,
                    color: isDark ? AppColors.slate500 : AppColors.slate400),
                const SizedBox(width: 4),
                Text(
                  _fmtDate(group.createdAt!),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ],
            ]),
          ]),
        ),

        // Actions menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              size: 20,
              color: isDark ? AppColors.slate400 : AppColors.slate500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                  group.isActive
                      ? Icons.do_not_disturb_outlined
                      : Icons.check_circle_outline,
                  size: 18,
                  color: group.isActive
                      ? AppColors.rose500
                      : AppColors.primaryPressed,
                ),
                const SizedBox(width: 8),
                Text(group.isActive ? 'Inativar' : 'Ativar'),
              ]),
            ),
          ],
          onSelected: (v) {
            if (v == 'toggle') onToggleActive();
          },
        ),
      ]),
    );
  }

  String _fmtDate(String s) {
    try {
      final d = AppDateUtils.parseOrNow(s);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return s;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.green100 : AppColors.rose50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          isActive ? 'Ativo' : 'Inativo',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.primaryPressed : AppColors.rose500,
          ),
        ),
      );
}

class _RoleChip extends StatelessWidget {
  final String role;
  final bool isDark;
  const _RoleChip({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isGodMode = role.toLowerCase() == 'godmode';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isGodMode
            ? AppColors.info.withValues(alpha: .12)
            : (isDark ? AppColors.slate800 : AppColors.slate100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isGodMode
              ? AppColors.info.withValues(alpha: .4)
              : (isDark ? AppColors.slate700 : AppColors.slate200),
        ),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isGodMode
              ? AppColors.info
              : (isDark ? AppColors.slate400 : AppColors.slate600),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final active =
        activeColor ?? (isDark ? AppColors.onDark : AppColors.slate900);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? active.withValues(alpha: .12)
              : (isDark ? AppColors.slate800 : AppColors.slate100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? active.withValues(alpha: .5)
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? active
                : (isDark ? AppColors.slate400 : AppColors.slate600),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _LoadMoreButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: isDark ? AppColors.slate600 : AppColors.slate300),
              foregroundColor: isDark ? AppColors.slate300 : AppColors.slate600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Carregar mais',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 40,
                color: isDark ? AppColors.slate600 : AppColors.slate300),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                ),
              ),
            ],
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final bool isDark;
  const _ErrorState(this.error, {required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erro: $error',
            style: const TextStyle(color: AppColors.rose500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
