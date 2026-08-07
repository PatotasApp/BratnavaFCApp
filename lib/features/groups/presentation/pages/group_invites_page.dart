import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group_invite.dart';
import '../providers/group_invites_provider.dart';

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
            _InvitesHeader(onRefresh: _refresh),
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
  final Future<void> Function() onRefresh;

  const _InvitesHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/app'),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.slate800 : AppColors.slate50,
              foregroundColor: isDark ? AppColors.onDark : AppColors.slate800,
              side: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentOf(
                isDark ? Brightness.dark : Brightness.light,
              ).withAlpha(24),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              color: AppColors.accentOf(
                isDark ? Brightness.dark : Brightness.light,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convites',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                ),
                Text(
                  'Entre em uma nova patota',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group,
                    color: AppColors.emerald500, size: 22),
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
