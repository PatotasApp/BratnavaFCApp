import 'package:flutter/material.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../domain/entities/group_invite.dart';
import '../providers/group_invites_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class GroupInvitesPage extends ConsumerStatefulWidget {
  const GroupInvitesPage({super.key});

  @override
  ConsumerState<GroupInvitesPage> createState() => _GroupInvitesPageState();
}

class _GroupInvitesPageState extends ConsumerState<GroupInvitesPage> {
  final Set<String> _loading = {};

  Future<void> _refresh() async {
    ref.invalidate(myGroupInvitesProvider);
    await ref.read(myGroupInvitesProvider.future);
  }

  Future<void> _accept(GroupInvite invite) async {
    setState(() => _loading.add(invite.id));
    try {
      await ref.read(groupInvitesDsProvider).acceptInvite(invite.id);
      ref.invalidate(myGroupInvitesProvider);
      ref.invalidate(myGroupInviteCountProvider);
      // A nova patota precisa aparecer em "Suas patotas" e habilitar as roles
      // do grupo — sem isso a lista de players e as permissões ficam defasadas.
      ref.invalidate(myPlayersProvider);
      await ref.read(authNotifierProvider.notifier).refreshGroupMembership();
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
    final invitesAsync = ref.watch(myGroupInvitesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _InvitesHeader(),
            Expanded(
                child: invitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _InvitesError(onRetry: _refresh),
              data: (invites) {
                if (invites.isEmpty) {
                  return _InvitesEmpty(onRefresh: _refresh);
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: invites.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Text(
                          '${invites.length} convite${invites.length != 1 ? 's' : ''} aguardando sua resposta',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
                          ),
                        );
                      }
                      final invite = invites[i - 1];
                      return _InviteCard(
                        invite: invite,
                        acceptLoading: _loading.contains(invite.id),
                        rejectLoading: _loading.contains('reject_${invite.id}'),
                        onAccept: () => _accept(invite),
                        onReject: () => _reject(invite),
                      );
                    },
                  ),
                );
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _InvitesHeader extends StatelessWidget {
  const _InvitesHeader();

  @override
  Widget build(BuildContext context) => const AppPageHeader(
        title: 'Convites',
        subtitle: 'Entre em uma nova patota',
        icon: Icons.mail_outline_rounded,
      );
}

class _InvitesEmpty extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _InvitesEmpty({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentOf(
                  isDark ? Brightness.dark : Brightness.light,
                ).withAlpha(22),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 34,
                color: AppColors.accentOf(
                  isDark ? Brightness.dark : Brightness.light,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tudo em dia por aqui',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.onDark : AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Você não possui convites pendentes no momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitesError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _InvitesError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      );
}

class _InviteCard extends StatelessWidget {
  final GroupInvite invite;
  final bool acceptLoading;
  final bool rejectLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InviteCard({
    required this.invite,
    required this.acceptLoading,
    required this.rejectLoading,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                name: invite.groupName,
                photoUrl: invite.groupLogoUrl,
                size: 40,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
          const SizedBox(height: 14),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
                            strokeWidth: 2,
                            color: AppColors.onDark,
                          ),
                        )
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
