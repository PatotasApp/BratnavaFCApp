import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../groups/presentation/providers/group_invites_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class MyAccountPage extends ConsumerWidget {
  const MyAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountStoreProvider);
    final active = accountState.activeAccount;
    final playersAsync = ref.watch(myPlayersProvider);
    final players = playersAsync.valueOrNull ?? const <MyPlayer>[];
    final activePlayer = ref.watch(activePlayerProvider);

    if (active == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: () => context.go('/app'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Minha conta'),
              Text(
                'Seus dados, contas e privacidade',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Perfil'),
              Tab(text: 'Contas'),
              Tab(text: 'Patotas'),
              Tab(text: 'Segurança'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(account: active, activePlayer: activePlayer),
            _AccountsTab(
              accounts: accountState.accounts,
              activeId: accountState.activeAccountId,
              onSwitch: (userId) => _switchAccount(context, ref, userId),
              onAdd: () => context.go('/login?add=1'),
            ),
            _GroupsTab(
              players: players,
              activePlayer: activePlayer,
              loading: playersAsync.isLoading,
              onSwitch: (player) => _switchPlayer(context, ref, player),
            ),
            _SecurityTab(
              keepLoggedIn: active.keepLoggedIn,
              onLogout: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    ref.read(activePlayerIdProvider.notifier).state = null;
    await ref.read(accountStoreProvider.notifier).switchTo(userId);
    ref.read(authInterceptorProvider).resetUnauthorizedGuard();
    ref.invalidate(myPlayersProvider);
    ref.invalidate(notifUnreadCountProvider);
    ref.invalidate(myGroupInviteCountProvider);
    await ref.read(authNotifierProvider.notifier).refreshGroupMembership();
    if (context.mounted) context.go('/app');
  }

  Future<void> _switchPlayer(
    BuildContext context,
    WidgetRef ref,
    MyPlayer player,
  ) async {
    await ref.read(accountStoreProvider.notifier).patchActive(
          (account) => account.copyWith(
            activePlayerId: player.playerId,
            activeGroupId: player.groupId,
            activeGroupIsAdmin: false,
            activeGroupIsFinanceiro: false,
          ),
        );
    ref.read(activePlayerIdProvider.notifier).state = player.playerId;
    await ref
        .read(authNotifierProvider.notifier)
        .refreshMyGroupRoles(player.groupId);
    if (context.mounted) context.go('/app');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _ProfileTab extends StatelessWidget {
  final Account account;
  final MyPlayer? activePlayer;

  const _ProfileTab({required this.account, required this.activePlayer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = activePlayer?.playerName.isNotEmpty == true
        ? activePlayer!.playerName
        : account.name;

    return PrototypeScrollView(
      child: PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarWidget(name: displayName, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activePlayer != null)
                        ConfiguredPlayerName(
                          groupId: activePlayer!.groupId,
                          name: displayName,
                          isGoalkeeper: activePlayer!.isGoalkeeper,
                          iconSize: 16,
                          style: theme.textTheme.titleMedium,
                        )
                      else
                        Text(displayName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(account.email, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'Nome da conta', value: account.name),
            const SizedBox(height: 10),
            _ReadOnlyField(label: 'E-mail', value: account.email),
            if (activePlayer != null) ...[
              const SizedBox(height: 10),
              _ReadOnlyField(
                label: 'Perfil ativo',
                value:
                    '${activePlayer!.playerName} · ${activePlayer!.groupName}',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Os dados são os mesmos utilizados no login e nos vínculos das patotas.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  final List<Account> accounts;
  final String? activeId;
  final ValueChanged<String> onSwitch;
  final VoidCallback onAdd;

  const _AccountsTab({
    required this.accounts,
    required this.activeId,
    required this.onSwitch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return PrototypeScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeSectionTitle(
            title: 'Contas conectadas',
            count: '${accounts.length}',
          ),
          const SizedBox(height: 10),
          PrototypeCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (var index = 0; index < accounts.length; index++) ...[
                  _AccountRow(
                    account: accounts[index],
                    active: accounts[index].userId == activeId,
                    onTap: () => onSwitch(accounts[index].userId),
                  ),
                  if (index < accounts.length - 1)
                    const Divider(indent: 52, endIndent: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Adicionar outra conta'),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final Account account;
  final bool active;
  final VoidCallback onTap;

  const _AccountRow({
    required this.account,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AvatarWidget(name: account.name, size: 36),
      title: Text(account.name.isEmpty ? account.email : account.name),
      subtitle: Text(active ? 'Conta ativa' : account.email),
      trailing: active
          ? const PrototypeBadge(
              label: 'Ativa',
              tone: PrototypeBadgeTone.success,
            )
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  final List<MyPlayer> players;
  final MyPlayer? activePlayer;
  final bool loading;
  final ValueChanged<MyPlayer> onSwitch;

  const _GroupsTab({
    required this.players,
    required this.activePlayer,
    required this.loading,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PrototypeScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeSectionTitle(
            title: 'Suas patotas',
            count: '${players.length}',
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            const PrototypeCard(
              child: Text('Nenhuma patota vinculada a esta conta.'),
            )
          else
            PrototypeCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (var index = 0; index < players.length; index++) ...[
                    ListTile(
                      onTap: () => onSwitch(players[index]),
                      leading: const PrototypeIconBox(
                        icon: Icon(Icons.groups_outlined),
                      ),
                      title: Text(players[index].groupName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConfiguredPlayerName(
                            groupId: players[index].groupId,
                            name: players[index].playerName,
                            isGoalkeeper: players[index].isGoalkeeper,
                            iconSize: 13,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            players[index].isGuest ? 'Convidado' : 'Mensalista',
                          ),
                        ],
                      ),
                      trailing:
                          players[index].playerId == activePlayer?.playerId
                              ? const PrototypeBadge(
                                  label: 'Ativa',
                                  tone: PrototypeBadgeTone.success,
                                )
                              : const Icon(Icons.chevron_right_rounded),
                    ),
                    if (index < players.length - 1)
                      const Divider(indent: 56, endIndent: 4),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityTab extends StatelessWidget {
  final bool keepLoggedIn;
  final VoidCallback onLogout;

  const _SecurityTab({
    required this.keepLoggedIn,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PrototypeScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeCard(
            child: Row(
              children: [
                const PrototypeIconBox(
                  icon: Icon(Icons.verified_user_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    keepLoggedIn
                        ? 'Esta conta permanece conectada neste dispositivo.'
                        : 'A sessão termina ao fechar o aplicativo.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
  }
}
