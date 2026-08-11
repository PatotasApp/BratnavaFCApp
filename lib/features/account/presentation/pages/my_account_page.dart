import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../widgets/editable_profile_avatar.dart';
import '../widgets/edit_account_profile_sheet.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../auth/domain/entities/account.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';

class MyAccountPage extends ConsumerWidget {
  const MyAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(accountStoreProvider).activeAccount;
    final playersAsync = ref.watch(myPlayersProvider);
    final players = playersAsync.valueOrNull ?? const <MyPlayer>[];
    final activePlayer = ref.watch(activePlayerProvider);

    if (active == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            const AppPageHeader(
              title: 'Minha conta',
              subtitle: 'Seus dados, patotas e privacidade',
              icon: Icons.manage_accounts_outlined,
              footer: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Perfil'),
                  Tab(text: 'Patotas'),
                  Tab(text: 'Segurança'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ProfileTab(account: active, activePlayer: activePlayer),
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
          ],
        ),
      ),
    );
  }

  Future<void> _switchPlayer(
    BuildContext context,
    WidgetRef ref,
    MyPlayer player,
  ) async {
    await ref.read(authNotifierProvider.notifier).selectActiveGroup(
          groupId: player.groupId,
          playerId: player.playerId,
        );
    ref.read(activePlayerIdProvider.notifier).state = player.playerId;
    if (context.mounted) context.go('/app');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _ProfileTab extends ConsumerWidget {
  final Account account;
  final MyPlayer? activePlayer;

  const _ProfileTab({required this.account, required this.activePlayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayName = activePlayer?.playerName.isNotEmpty == true
        ? activePlayer!.playerName
        : account.name;
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return PrototypeScrollView(
      child: PrototypeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                EditableProfileAvatar(
                  userId: account.userId,
                  name: displayName,
                  photoUrl: profile?.photoUrl ?? activePlayer?.photoUrl,
                ),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: profile == null
                  ? null
                  : () async {
                      final changed = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => EditAccountProfileSheet(user: profile),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dados atualizados com sucesso.'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar meus dados'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/app/profile/${account.userId}'),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver meu perfil público'),
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
                      leading: AvatarWidget(
                        name: players[index].groupName,
                        photoUrl: players[index].groupLogoUrl,
                        size: 40,
                        fit: BoxFit.cover,
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
