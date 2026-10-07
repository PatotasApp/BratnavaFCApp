import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';

import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../widgets/editable_profile_avatar.dart';
import '../widgets/change_email_sheet.dart';
import '../widgets/edit_account_profile_sheet.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
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
                    email: active.email,
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
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/app/groups?create=true'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova patota'),
          ),
        ],
      ),
    );
  }
}

class _SecurityTab extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const _SecurityTab({
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PrototypeScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PrototypeCard(
            child: Row(
              children: [
                PrototypeIconBox(
                  icon: Icon(Icons.verified_user_outlined),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // O Firebase persiste a sessão no aparelho e renova o token
                    // sozinho; não há opção de "não manter logado" no mobile.
                    'Esta conta permanece conectada neste dispositivo até você '
                    'sair.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => ChangeEmailSheet(currentEmail: email),
            ),
            icon: const Icon(Icons.alternate_email_rounded),
            label: const Text('Alterar e-mail'),
          ),
          const SizedBox(height: 8),

          // Trocar senha é o mesmo fluxo de "esqueci minha senha": a senha vive
          // no Firebase e a API não tem endpoint para ela. Redefinir por e-mail
          // também marca o endereço como verificado, o que é justamente o que o
          // provisionamento do backend exige para vincular contas antigas.
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/forgot-password?email=${Uri.encodeQueryComponent(email)}',
            ),
            icon: const Icon(Icons.key_outlined),
            label: const Text('Alterar senha'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
          const SizedBox(height: 8),

          // Exigência da Google Play: a política precisa estar na ficha da loja
          // E acessível de dentro do app. Abrir no navegador satisfaz as duas —
          // não é necessário renderizar o conteúdo aqui.
          OutlinedButton.icon(
            onPressed: () => _abrirPoliticaDePrivacidade(context),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Política de privacidade'),
          ),
          const SizedBox(height: 24),
          const _DeleteAccountSection(),
        ],
      ),
    );
  }
}

/// Exclusão definitiva da conta.
///
/// Fica no fim da aba e atrás de um divisor porque é irreversível: o que
/// sobrevive à exclusão (o histórico nas patotas) precisa estar visível ANTES
/// do clique, não só dentro do diálogo de confirmação.
/// Abre a política de privacidade no navegador do aparelho.
///
/// Em navegador externo e não numa WebView embutida: a Play quer que a pessoa
/// consiga ler, salvar e compartilhar a política como qualquer página, e uma
/// WebView sem barra de endereço esconde de onde o conteúdo veio.
///
/// Falhar aqui é raro (aparelho sem navegador), mas silenciar seria pior que o
/// erro: a pessoa tocaria no botão e nada aconteceria.
Future<void> _abrirPoliticaDePrivacidade(BuildContext context) async {
  final url = Uri.parse(AppConstants.privacyPolicyUrl);
  final abriu = await launchUrl(url, mode: LaunchMode.externalApplication);

  if (!abriu && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Não foi possível abrir ${AppConstants.privacyPolicyUrl}'),
      ),
    );
  }
}

class _DeleteAccountSection extends ConsumerStatefulWidget {
  const _DeleteAccountSection();

  @override
  ConsumerState<_DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<_DeleteAccountSection> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    if (_deleting) return;

    final confirmed = await showConfirmDialog(
      context: context,
      danger: true,
      title: 'Excluir sua conta?',
      confirmLabel: 'Excluir conta',
      message: 'Esta ação é irreversível.\n\n'
          'Sua conta e seus dados pessoais serão apagados e você perderá o '
          'acesso ao aplicativo.\n\n'
          'O histórico nas patotas permanece: seu jogador continua nas '
          'estatísticas e nas partidas, convertido em convidado.',
    );

    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);

    try {
      await ref.read(authDataSourceProvider).deleteMyAccount();

      // Mesmo caminho do "Sair da conta": o logout também remove o token de
      // push, cancela notificações e limpa o widget da home — resíduos que não
      // podem sobreviver a uma conta que deixou de existir.
      await ref.read(authNotifierProvider.notifier).logout();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta excluída com sucesso.')),
      );
      context.go('/login');
    } on SoleAdminGroupsException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _SoleAdminGroupsDialog(error: error),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extractDioError(error, 'Não foi possível excluir sua conta.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 12),
        const PrototypeSectionTitle(title: 'Excluir conta'),
        const SizedBox(height: 10),
        PrototypeCard(
          borderColor: colors.error,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrototypeIconBox(
                icon: const Icon(Icons.delete_forever_outlined),
                backgroundColor: colors.errorContainer,
                foregroundColor: colors.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sua conta e seus dados pessoais são apagados e não há '
                      'como desfazer.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'O histórico nas patotas permanece: seu jogador continua '
                      'nas partidas e nas estatísticas, convertido em '
                      'convidado.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _deleting ? null : _confirmAndDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error),
          ),
          icon: _deleting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.error,
                  ),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: Text(_deleting ? 'Excluindo...' : 'Excluir minha conta'),
        ),
      ],
    );
  }
}

/// Recusa 409: a pessoa é a única administradora das patotas listadas.
///
/// A lista é o conteúdo principal do diálogo — a mensagem do servidor só diz
/// quantas patotas bloqueiam, e sem os nomes a pessoa não saberia onde agir.
class _SoleAdminGroupsDialog extends StatelessWidget {
  final SoleAdminGroupsException error;

  const _SoleAdminGroupsDialog({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrototypeIconBox(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            size: 40,
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Não foi possível excluir',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message, style: theme.textTheme.bodyMedium),
            if (error.groups.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Promova outro administrador em cada patota abaixo e tente '
                'novamente:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              for (final group in error.groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: colors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.groupName,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
