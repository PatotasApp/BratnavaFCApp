import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';

class Step2AceitacaoPage extends ConsumerStatefulWidget {
  const Step2AceitacaoPage({super.key});

  @override
  ConsumerState<Step2AceitacaoPage> createState() => _Step2State();
}

class _Step2State extends ConsumerState<Step2AceitacaoPage> {

  Future<void> _goNext() async {
    await ref.read(matchNotifierProvider.notifier).goToMatchmaking();
  }

  @override
  Widget build(BuildContext context) {
    final s           = ref.watch(matchNotifierProvider);
    final account     = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final accepted    = s.acceptedPlayers;
    final rejected    = s.rejectedPlayers;
    final pending     = s.pendingPlayers;
    final myId        = account?.activePlayerId ?? activePlayer?.playerId ?? '';
    final gid         = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isGroupAdmin = gid.isNotEmpty && (account?.isGroupAdmin(gid) ?? false);
    final isAdmin     = (account?.isAdmin ?? false) || isGroupAdmin;
    final pct         = s.maxPlayers > 0 ? accepted.length / s.maxPlayers : 0.0;

    return Column(
        children: [

          // ── Barra de progresso ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.slate200,
                      color: pct >= 1.0 ? AppColors.emerald500 : AppColors.blue500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${accepted.length}/${s.maxPlayers}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // ── Cards de aceitação ───────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InviteCard(
                      title:   'Aceitos',
                      count:   accepted.length,
                      items:   accepted,
                      variant: _InviteVariant.accepted,
                      myId:    myId,
                      isAdmin: isAdmin,
                      mutating: s.mutating,
                      onAccept: (pid) => ref.read(matchNotifierProvider.notifier).acceptInvite(pid),
                      onReject: (pid) => ref.read(matchNotifierProvider.notifier).rejectInvite(pid),
                      onSetRole: (mpId, gk) => ref.read(matchNotifierProvider.notifier).setPlayerRole(mpId, gk),
                    ),
                    const SizedBox(height: 12),
                    _InviteCard(
                      title:   'Não Aceitos',
                      count:   rejected.length,
                      items:   rejected,
                      variant: _InviteVariant.rejected,
                      myId:    myId,
                      isAdmin: isAdmin,
                      mutating: s.mutating,
                      onAccept: (pid) => ref.read(matchNotifierProvider.notifier).acceptInvite(pid),
                      onReject: (pid) => ref.read(matchNotifierProvider.notifier).rejectInvite(pid),
                      onSetRole: (mpId, gk) => ref.read(matchNotifierProvider.notifier).setPlayerRole(mpId, gk),
                    ),
                    const SizedBox(height: 12),
                    _InviteCard(
                      title:   'Pendentes',
                      count:   pending.length,
                      items:   pending,
                      variant: _InviteVariant.pending,
                      myId:    myId,
                      isAdmin: isAdmin,
                      mutating: s.mutating,
                      onAccept: (pid) => ref.read(matchNotifierProvider.notifier).acceptInvite(pid),
                      onReject: (pid) => ref.read(matchNotifierProvider.notifier).rejectInvite(pid),
                      onSetRole: (mpId, gk) => ref.read(matchNotifierProvider.notifier).setPlayerRole(mpId, gk),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          // ── Botão Ir para MatchMaking (admin do grupo) ───────────────────
          if (isGroupAdmin)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (s.mutating || !s.canAdvanceToMatchmaking)
                        ? null
                        : _goNext,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Ir para MatchMaking'),
                  ),
                ),
              ),
            ),
        ],
    );
  }
}

// ── Variante do card ──────────────────────────────────────────────────────────

enum _InviteVariant { accepted, rejected, pending }

extension _InviteVariantX on _InviteVariant {
  Color get topBorder {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald500;
      case _InviteVariant.rejected: return AppColors.rose500;
      case _InviteVariant.pending:  return AppColors.slate300;
    }
  }

  Color get headerColor {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald700;
      case _InviteVariant.rejected: return AppColors.rose500;
      case _InviteVariant.pending:  return AppColors.slate500;
    }
  }

  Color get countBg {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald200;
      case _InviteVariant.rejected: return AppColors.rose200;
      case _InviteVariant.pending:  return AppColors.slate200;
    }
  }

  Color get countFg {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald700;
      case _InviteVariant.rejected: return AppColors.rose600;
      case _InviteVariant.pending:  return AppColors.slate600;
    }
  }

  Color get avatarBg {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald200;
      case _InviteVariant.rejected: return AppColors.rose200;
      case _InviteVariant.pending:  return AppColors.slate200;
    }
  }

  Color get avatarFg {
    switch (this) {
      case _InviteVariant.accepted: return AppColors.emerald700;
      case _InviteVariant.rejected: return AppColors.rose600;
      case _InviteVariant.pending:  return AppColors.slate500;
    }
  }

  bool get showAcceptBtn {
    return this == _InviteVariant.pending || this == _InviteVariant.rejected;
  }

  bool get showRejectBtn {
    return this == _InviteVariant.pending || this == _InviteVariant.accepted;
  }
}

// ── Card de convite pessoal (para quem é admin e também jogador) ──────────────

// ── Card de lista de convites ─────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final String               title;
  final int                  count;
  final List<MatchPlayerInfo> items;
  final _InviteVariant       variant;
  final String               myId;
  final bool                 isAdmin;
  final bool                 mutating;
  final void Function(String pid)  onAccept;
  final void Function(String pid)  onReject;
  final void Function(String mpId, bool isGk) onSetRole;

  const _InviteCard({
    required this.title,
    required this.count,
    required this.items,
    required this.variant,
    required this.myId,
    required this.isAdmin,
    required this.mutating,
    required this.onAccept,
    required this.onReject,
    required this.onSetRole,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final regular = items.where((p) => !p.isGuest).toList();
    final guests  = items.where((p) => p.isGuest).toList();
    // Sort: current user first
    regular.sort((a, b) {
      if (a.playerId == myId) return -1;
      if (b.playerId == myId) return 1;
      return 0;
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900.withValues(alpha: 0.6) : Colors.white,
          border:       Border.all(color: isDark ? AppColors.slate700.withValues(alpha: 0.6) : AppColors.slate200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top accent bar ────────────────────────────────────────────
            Container(height: 3, color: variant.topBorder),

            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate700.withValues(alpha: 0.6) : AppColors.slate100,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: variant.headerColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: variant.countBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: variant.countFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  if (regular.isEmpty && guests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Icons.group_outlined, size: 20, color: AppColors.slate400),
                          SizedBox(height: 6),
                          Text('Nenhum jogador', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                        ],
                      ),
                    )
                  else ...[
                    ...regular.map((p) => _PlayerRow(
                      player:   p,
                      isMe:     p.playerId == myId,
                      isGuest:  false,
                      isAdmin:  isAdmin,
                      variant:  variant,
                      mutating: mutating,
                      onAccept: onAccept,
                      onReject: onReject,
                      onSetRole: onSetRole,
                    )),
                    if (guests.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'CONVIDADOS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                                color: isDark ? AppColors.slate500 : AppColors.slate400,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                      ),
                      ...guests.map((p) => _PlayerRow(
                        player:   p,
                        isMe:     p.playerId == myId,
                        isGuest:  true,
                        isAdmin:  isAdmin,
                        variant:  variant,
                        mutating: mutating,
                        onAccept: onAccept,
                        onReject: onReject,
                        onSetRole: onSetRole,
                      )),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Linha de jogador ──────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final MatchPlayerInfo player;
  final bool isMe;
  final bool isGuest;
  final bool isAdmin;
  final _InviteVariant variant;
  final bool mutating;
  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(String, bool) onSetRole;

  const _PlayerRow({
    required this.player,
    required this.isMe,
    required this.isGuest,
    required this.isAdmin,
    required this.variant,
    required this.mutating,
    required this.onAccept,
    required this.onReject,
    required this.onSetRole,
  });

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  // Quem pode agir: admin ou o próprio jogador
  bool get _canAct => isAdmin || isMe;

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final avatarBg  = isGuest
        ? (isDark ? AppColors.amber500.withValues(alpha: 0.3) : AppColors.amber200)
        : variant.avatarBg;
    final avatarFg  = isGuest
        ? AppColors.orange700
        : variant.avatarFg;

    final showAccept = _canAct && variant.showAcceptBtn;
    final showReject = _canAct && variant.showRejectBtn;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.slate800.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? AppColors.blue500.withValues(alpha: 0.4)
              : isDark ? AppColors.slate700.withValues(alpha: 0.6) : AppColors.slate100,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
            child: Center(
              child: Text(
                _initials(player.playerName),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: avatarFg),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nome + badges
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                Text(
                  player.playerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                    color: isDark ? AppColors.slate100 : AppColors.slate900,
                  ),
                ),
                // Goleiro toggle (admin) ou ícone (não-admin)
                if (isAdmin)
                  GestureDetector(
                    onTap: mutating ? null : () => onSetRole(player.matchPlayerId, !player.isGoalkeeper),
                    child: Opacity(
                      opacity: mutating ? 0.5 : 1,
                      child: Tooltip(
                        message: player.isGoalkeeper ? 'Goleiro – toque para mudar para linha' : 'Linha – toque para mudar para goleiro',
                        child: Icon(
                          player.isGoalkeeper ? Icons.sports_handball : Icons.sports_soccer,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                      ),
                    ),
                  )
                else if (player.isGoalkeeper)
                  const Icon(Icons.sports_handball, size: 14, color: AppColors.slate400),

                if (isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blue500.withValues(alpha: 0.3) : AppColors.blue200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Você', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.blue200 : AppColors.blue600)),
                  ),
                if (isGuest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.amber500.withValues(alpha: 0.25) : AppColors.amber200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber400.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Convidado', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.orange700)),
                  ),
              ],
            ),
          ),

          // Botões
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showReject)
                _ActionBtn(
                  icon: Icons.close,
                  color: AppColors.rose500,
                  bgColor: isDark ? AppColors.rose500.withValues(alpha: 0.15) : AppColors.rose50,
                  borderColor: isDark ? AppColors.rose500.withValues(alpha: 0.4) : AppColors.rose200,
                  tooltip: 'Recusar',
                  enabled: !mutating,
                  onTap: () => onReject(player.playerId),
                ),
              if (showAccept) ...[
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.check,
                  color: AppColors.emerald500,
                  bgColor: isDark ? AppColors.emerald500.withValues(alpha: 0.15) : AppColors.emerald50,
                  borderColor: isDark ? AppColors.emerald500.withValues(alpha: 0.4) : AppColors.emerald200,
                  tooltip: 'Aceitar',
                  enabled: !mutating,
                  onTap: () => onAccept(player.playerId),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bgColor, borderColor;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: borderColor),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    ),
  );
}
