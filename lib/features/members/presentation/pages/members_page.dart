import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../domain/entities/app_user.dart';
import '../providers/members_provider.dart';
import '../../../groups/presentation/providers/group_invites_provider.dart';
import '../../../groups/domain/entities/group_invite.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/errors/app_exception.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (account == null) return const SizedBox.shrink();

    return _AdminUsersPage(currentUserId: account.userId, isDark: isDark);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN — grid de cards igual ao site
// ══════════════════════════════════════════════════════════════════════════════

class _AdminUsersPage extends ConsumerStatefulWidget {
  final String currentUserId;
  final bool isDark;
  const _AdminUsersPage({required this.currentUserId, required this.isDark});

  @override
  ConsumerState<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<_AdminUsersPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final async = ref.watch(usersProvider);
    final allUsers = async.valueOrNull ?? [];

    final filtered = _query.isEmpty
        ? allUsers
        : allUsers.where((u) {
            final q = _query.toLowerCase();
            return u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.userName.toLowerCase().contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(usersProvider),
      child: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _AdminHeader(
              count: async.valueOrNull?.length ?? 0,
              isDark: isDark,
            ),
          ),

          // ── Convites de patota (admin também pode ser convidado) ────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _InvitesCard(isDark: isDark),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                  color: isDark ? AppColors.slate200 : AppColors.slate800,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome, usuário ou email...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.blue500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          async.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message:
                    extractDioError(e, 'Não foi possível carregar usuários.'),
                onRetry: () => ref.invalidate(usersProvider),
              ),
            ),
            data: (_) {
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(query: _query, isDark: isDark),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 145,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _UserCard(
                      user: filtered[i],
                      isCurrentUser: filtered[i].id == widget.currentUserId,
                      isDark: isDark,
                      onEdit: () => _showEditSheet(
                        ctx,
                        filtered[i],
                        isDark,
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext ctx, AppUser user, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _UserDetailSheet(user: user, isDark: isDark),
    );
  }
}

// ── Admin header ──────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final int count;
  final bool isDark;
  const _AdminHeader({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/app');
                  }
                },
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.onDark,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.onDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.onDark.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  size: 24,
                  color: AppColors.onDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usuários',
                      style: TextStyle(
                        color: AppColors.onDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$count usuário${count == 1 ? '' : 's'} encontrado${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.onDark.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User Card (grid item) ─────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isCurrentUser;
  final bool isDark;
  final VoidCallback onEdit;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;
    final border = isCurrentUser
        ? AppColors.emerald500
        : (isDark ? AppColors.slate700 : AppColors.slate200);

    final subtitle =
        '@${user.userName.isNotEmpty ? user.userName : user.email.split('@').first} · ${user.email}';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isCurrentUser ? 1.5 : 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.darkApp.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + badges/actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarWidget(
                    name: user.fullName, photoUrl: user.photoUrl, size: 38),
                const Spacer(),
                if (isCurrentUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.slate900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Você',
                      style: TextStyle(
                        color: AppColors.onDark,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (user.roles.isNotEmpty)
                    _RoleBadge(role: user.roles.first, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NON-ADMIN — perfil próprio igual ao site
// ══════════════════════════════════════════════════════════════════════════════

// Mantido temporariamente para compatibilidade com os sheets legados deste
// arquivo; a rota Minha conta usa MyAccountPage e não esta tela administrativa.
// ignore: unused_element
class _MyProfilePage extends ConsumerWidget {
  final Account account;
  final bool isDark;
  const _MyProfilePage({required this.account, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    final user = async.valueOrNull;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ProfileHeader(
            account: account,
            user: user,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => _ProfileCard(
                user: _fallback(account),
                isDark: isDark,
              ),
              data: (u) => _ProfileCard(user: u, isDark: isDark),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _InvitesCard(isDark: isDark),
          ),
        ),
      ],
    );
  }

  static AppUser _fallback(Account acc) {
    final parts = acc.name.trim().split(' ');
    return AppUser(
      id: acc.userId,
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
      email: acc.email,
      userName: acc.email.split('@').first,
      roles: acc.roles,
      isActive: true,
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Account account;
  final AppUser? user;
  const _ProfileHeader({required this.account, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user?.fullName ?? account.name;
    final username = user?.userName.isNotEmpty == true
        ? user!.userName
        : account.email.split('@').first;
    final role = (user?.roles ?? account.roles).isNotEmpty
        ? (user?.roles ?? account.roles).first
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.onDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.onDark.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  size: 24,
                  color: AppColors.onDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.onDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@$username${role.isNotEmpty ? ' · $role' : ''}',
                      style: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.slate600 : AppColors.slate300;
    final fg = isDark ? AppColors.slate300 : AppColors.slate600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser user;
  final bool isDark;
  const _ProfileCard({required this.user, required this.isDark});

  void _showEditDataSheet(BuildContext ctx, AppUser u, bool dark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _EditProfileSheet(user: u, isDark: dark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: isDark ? AppColors.slate300 : AppColors.slate600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perfil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.slate100 : AppColors.slate800,
                        ),
                      ),
                      Text(
                        'Seus dados pessoais',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? AppColors.slate500 : AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                _ProfileActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Alterar dados',
                  isDark: isDark,
                  onTap: () => _showEditDataSheet(context, user, isDark),
                ),
                const SizedBox(width: 8),
                _ProfileActionButton(
                  icon: Icons.lock_outline_rounded,
                  label: 'Alterar senha',
                  isDark: isDark,
                  // Mesmo destino do botão em my_account_page: a senha vive no Firebase e
                  // a API não tem endpoint para ela. Redefinir por e-mail também marca o
                  // endereço como verificado, que é o que o provisionamento exige para
                  // vincular contas anteriores à migração.
                  onTap: () => context.push(
                    '/forgot-password?email=${Uri.encodeQueryComponent(user.email)}',
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.slate700 : AppColors.slate100,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FieldRow(
                  fields: [
                    _FieldData(
                      'PRIMEIRO NOME',
                      user.firstName.isNotEmpty ? user.firstName : '—',
                    ),
                    _FieldData(
                      'SOBRENOME',
                      user.lastName.isNotEmpty ? user.lastName : '—',
                    ),
                    _FieldData(
                      'USUÁRIO',
                      '@${user.userName.isNotEmpty ? user.userName : user.email.split('@').first}',
                    ),
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _FieldRow(
                  fields: [
                    _FieldData(
                        'EMAIL', user.email.isNotEmpty ? user.email : '—'),
                    _FieldData('TELEFONE', user.phone ?? '—'),
                    _FieldData('NASCIMENTO', user.birthDate ?? '—'),
                  ],
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldData {
  final String label;
  final String value;
  final Color? valueColor;
  const _FieldData(this.label, this.value, {this.valueColor});
}

class _FieldRow extends StatelessWidget {
  final List<_FieldData> fields;
  final bool isDark;
  const _FieldRow({required this.fields, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields
          .map(
            (f) => Expanded(
              child: f.label.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          f.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: f.valueColor ??
                                (isDark
                                    ? AppColors.slate100
                                    : AppColors.slate800),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          )
          .toList(),
    );
  }
}

// ── Convites de patota card ───────────────────────────────────────────────────

class _InvitesCard extends ConsumerStatefulWidget {
  final bool isDark;
  const _InvitesCard({required this.isDark});

  @override
  ConsumerState<_InvitesCard> createState() => _InvitesCardState();
}

class _InvitesCardState extends ConsumerState<_InvitesCard> {
  final Set<String> _loading = {};

  Future<void> _accept(GroupInvite invite) async {
    setState(() => _loading.add(invite.id));
    try {
      await ref.read(groupInvitesDsProvider).acceptInvite(invite.id);
      ref.invalidate(myGroupInvitesProvider);
      ref.invalidate(myGroupInviteCountProvider);
      await ref.read(authNotifierProvider.notifier).refreshGroupMembership();
      ref.invalidate(myPlayersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Você entrou em ${invite.groupName}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar convite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove(invite.id));
    }
  }

  Future<void> _reject(GroupInvite invite) async {
    setState(() => _loading.add('reject_${invite.id}'));
    try {
      await ref.read(groupInvitesDsProvider).rejectInvite(invite.id);
      ref.invalidate(myGroupInvitesProvider);
      ref.invalidate(myGroupInviteCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite recusado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao recusar convite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove('reject_${invite.id}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.slate800 : AppColors.onDark;
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final invitesAsync = ref.watch(myGroupInvitesProvider);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
                const SizedBox(width: 8),
                Text(
                  'Convites de patota',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.slate100 : AppColors.slate800,
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate100),
          invitesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erro ao carregar convites.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ),
            data: (invites) {
              if (invites.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nenhum convite pendente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                  ),
                );
              }
              return Column(
                children: invites
                    .map((invite) => _InviteRow(
                          invite: invite,
                          isDark: isDark,
                          acceptLoading: _loading.contains(invite.id),
                          rejectLoading:
                              _loading.contains('reject_${invite.id}'),
                          onAccept: () => _accept(invite),
                          onReject: () => _reject(invite),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  final GroupInvite invite;
  final bool isDark;
  final bool acceptLoading;
  final bool rejectLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InviteRow({
    required this.invite,
    required this.isDark,
    required this.acceptLoading,
    required this.rejectLoading,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                name: invite.groupName,
                photoUrl: invite.groupLogoUrl,
                size: 36,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate100 : AppColors.slate800,
                      ),
                    ),
                    if (invite.invitedByName != null)
                      Text(
                        'Convidado por ${invite.invitedByName}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: rejectLoading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose500,
                    side: const BorderSide(color: AppColors.rose500),
                  ),
                  child: rejectLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: acceptLoading ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                  ),
                  child: acceptLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onDark))
                      : const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Admin Edit User Sheet ──────────────────────────────────────────────────────

class _UserDetailSheet extends ConsumerStatefulWidget {
  final AppUser user;
  final bool isDark;
  const _UserDetailSheet({required this.user, required this.isDark});

  @override
  ConsumerState<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<_UserDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstCtrl = TextEditingController(text: widget.user.firstName);
  late final _lastCtrl = TextEditingController(text: widget.user.lastName);
  late final _userCtrl = TextEditingController(text: widget.user.userName);
  late final _emailCtrl = TextEditingController(text: widget.user.email);
  late final _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
  late final _birthCtrl =
      TextEditingController(text: widget.user.birthDate ?? '');
  late bool _isActive = widget.user.isActive;
  bool _loading = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final ds = ref.read(membersDsProvider);
      String? birthIso;
      final bRaw = _birthCtrl.text.trim();
      if (bRaw.isNotEmpty) {
        try {
          final parts = bRaw.split('/');
          if (parts.length == 3) {
            birthIso =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } catch (_) {}
      }
      await ds.updateUser(
        widget.user.id,
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        userName: _userCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        birthDate: birthIso,
        isActive: _isActive,
      );
      ref.invalidate(usersProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário atualizado com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractDioError(e, 'Ocorreu um erro inesperado.')),
            backgroundColor: AppColors.rose600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive() async {
    final activate = !_isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? 'Ativar usuário' : 'Inativar usuário'),
        content: Text(
          activate
              ? 'Deseja ativar ${widget.user.fullName}?'
              : 'Deseja inativar ${widget.user.fullName}? O usuário perderá o acesso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  activate ? AppColors.emerald500 : AppColors.rose600,
            ),
            child: Text(activate ? 'Ativar' : 'Inativar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(membersDsProvider).toggleUserActive(
            widget.user.id,
            activate: activate,
          );
      ref.invalidate(usersProvider);
      if (mounted) {
        setState(() => _isActive = activate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activate ? 'Usuário ativado.' : 'Usuário inativado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractDioError(e, 'Ocorreu um erro inesperado.')),
            backgroundColor: AppColors.rose600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    final bg = dark ? AppColors.slate900 : AppColors.onDark;
    final fgSub = dark ? AppColors.slate400 : AppColors.slate500;
    final fgMain = dark ? AppColors.slate100 : AppColors.slate800;
    final fill = dark ? AppColors.slate800 : AppColors.slate50;
    final border = dark ? AppColors.slate700 : AppColors.slate200;

    final myUserId = ref.read(accountStoreProvider).activeAccount?.userId;
    final isMe = myUserId != null && widget.user.id == myUserId;

    InputDecoration dec(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: fgSub, fontSize: 13),
          filled: true,
          fillColor: fill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.blue500),
          ),
        );

    Widget field(
      String lbl,
      TextEditingController ctrl,
      String hint, {
      TextInputType? keyboard,
      String? Function(String?)? validator,
    }) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lbl,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fgSub,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: ctrl,
              keyboardType: keyboard,
              style: TextStyle(fontSize: 14, color: fgMain),
              decoration: dec(hint),
              validator: validator,
            ),
          ],
        );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.lightText, AppColors.darkCard],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.onDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.onDark.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: AppColors.onDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Editar usuário',
                            style: TextStyle(
                              color: AppColors.onDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'PatotasApp',
                            style: TextStyle(
                              color: AppColors.onDark.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.onDark.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            'PRIMEIRO NOME',
                            _firstCtrl,
                            'João',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: field('SOBRENOME', _lastCtrl, 'Silva'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            'USUÁRIO',
                            _userCtrl,
                            'joaosilva',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: field(
                            'EMAIL',
                            _emailCtrl,
                            'joao@email.com',
                            keyboard: TextInputType.emailAddress,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            'TELEFONE',
                            _phoneCtrl,
                            '+55 11 99999-9999',
                            keyboard: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: field(
                            'NASCIMENTO',
                            _birthCtrl,
                            'dd/MM/aaaa',
                            keyboard: TextInputType.datetime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: fgSub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<bool>(
                          initialValue: _isActive,
                          decoration: dec(''),
                          dropdownColor: bg,
                          style: TextStyle(fontSize: 14, color: fgMain),
                          items: [
                            const DropdownMenuItem(
                              value: true,
                              child: Text(
                                'Ativo',
                                style: TextStyle(
                                  color: AppColors.emerald500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text(
                                'Inativo',
                                style: TextStyle(color: fgSub),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _isActive = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Alterar senha — visível apenas quando o admin edita a própria conta
                    if (isMe) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/forgot-password?email='
                            '${Uri.encodeQueryComponent(widget.user.email)}',
                          ),
                          icon:
                              const Icon(Icons.lock_outline_rounded, size: 16),
                          label: const Text('Alterar senha'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: border),
                            foregroundColor:
                                dark ? AppColors.slate300 : AppColors.slate600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _loading ? null : _toggleActive,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _isActive
                                  ? AppColors.warning
                                  : AppColors.emerald500,
                            ),
                            foregroundColor: _isActive
                                ? AppColors.warning
                                : AppColors.emerald500,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(_isActive ? 'Inativar' : 'Ativar'),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: border),
                            foregroundColor:
                                dark ? AppColors.slate300 : AppColors.slate600,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _loading ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.slate900,
                            foregroundColor: AppColors.onDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onDark,
                                  ),
                                )
                              : const Text('Salvar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final AppUser user;
  final bool isDark;
  const _EditProfileSheet({required this.user, required this.isDark});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _firstCtrl = TextEditingController(text: widget.user.firstName);
  late final _lastCtrl = TextEditingController(text: widget.user.lastName);
  late final _userCtrl = TextEditingController(text: widget.user.userName);
  late final _emailCtrl = TextEditingController(text: widget.user.email);
  late final _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
  late final _birthCtrl =
      TextEditingController(text: widget.user.birthDate ?? '');
  bool _loading = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final ds = ref.read(membersDsProvider);
      String? birthIso;
      final bRaw = _birthCtrl.text.trim();
      if (bRaw.isNotEmpty) {
        try {
          final parts = bRaw.split('/');
          if (parts.length == 3) {
            birthIso =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } catch (_) {}
      }
      await ds.updateUser(
        widget.user.id,
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        userName: _userCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        birthDate: birthIso,
      );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados atualizados com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractDioError(e, 'Ocorreu um erro inesperado.')),
            backgroundColor: AppColors.rose600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark;
    final bg = dark ? AppColors.slate900 : AppColors.onDark;
    final label = dark ? AppColors.slate400 : AppColors.slate500;
    final input = dark ? AppColors.slate100 : AppColors.slate800;
    final fill = dark ? AppColors.slate800 : AppColors.slate50;
    final border = dark ? AppColors.slate700 : AppColors.slate200;

    InputDecoration dec(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: label, fontSize: 13),
          filled: true,
          fillColor: fill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.blue500),
          ),
        );

    Widget field(
      String label2,
      TextEditingController ctrl,
      String hint, {
      TextInputType? keyboard,
      String? Function(String?)? validator,
    }) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: label,
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: ctrl,
              keyboardType: keyboard,
              style: TextStyle(fontSize: 14, color: input),
              decoration: dec(hint),
              validator: validator,
            ),
          ],
        );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: dark ? AppColors.slate300 : AppColors.slate600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar dados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: dark ? AppColors.slate100 : AppColors.slate800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'PRIMEIRO NOME',
                        _firstCtrl,
                        'João',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field('SOBRENOME', _lastCtrl, 'Silva'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'USUÁRIO',
                        _userCtrl,
                        'joaosilva',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field(
                        'EMAIL',
                        _emailCtrl,
                        'joao@email.com',
                        keyboard: TextInputType.emailAddress,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obrigatório'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'TELEFONE',
                        _phoneCtrl,
                        '+55 11 99999-9999',
                        keyboard: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field(
                        'NASCIMENTO',
                        _birthCtrl,
                        'dd/MM/aaaa',
                        keyboard: TextInputType.datetime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          foregroundColor:
                              dark ? AppColors.slate300 : AppColors.slate600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.slate900,
                          foregroundColor: AppColors.onDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onDark,
                                ),
                              )
                            : const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool isDark;
  const _RoleBadge({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (role.toLowerCase()) {
      case 'admin':
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        break;
      case 'financeiro':
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.amber500;
        break;
      default:
        bg = isDark ? AppColors.slate700 : AppColors.slate100;
        fg = isDark ? AppColors.slate300 : AppColors.slate500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  final bool isDark;
  const _EmptyState({required this.query, required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              query.isEmpty
                  ? Icons.people_outline_rounded
                  : Icons.search_off_rounded,
              size: 52,
              color: isDark ? AppColors.slate700 : AppColors.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'Nenhum usuário encontrado'
                  : 'Sem resultados para "$query"',
              style: TextStyle(
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.rose500,
              ),
              const SizedBox(height: 12),
              const Text(
                'Erro ao carregar usuários',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}
