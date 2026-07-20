import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';

class Step2AceitacaoPage extends ConsumerStatefulWidget {
  final Widget? linkedPollStrip;
  const Step2AceitacaoPage({super.key, this.linkedPollStrip});

  @override
  ConsumerState<Step2AceitacaoPage> createState() => _Step2State();
}

class _Step2State extends ConsumerState<Step2AceitacaoPage> {
  Future<void> _goNext() async {
    await ref.read(matchNotifierProvider.notifier).goToMatchmaking();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final accepted = s.acceptedPlayers;
    final rejected = s.rejectedPlayers;
    final pending = s.pendingPlayers;
    final myId = account?.activePlayerId ?? activePlayer?.playerId ?? '';
    final gid = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isGroupAdmin =
        gid.isNotEmpty && (account?.isGroupAdmin(gid) ?? false);
    final isAdmin = (account?.isAdmin ?? false) || isGroupAdmin;
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);
    final pct = s.maxPlayers > 0 ? accepted.length / s.maxPlayers : 0.0;

    return Column(
      children: [
        // ── Barra de progresso ───────────────────────────────────────────
        // ── Cards de aceitação ───────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _AcceptanceSummaryCard(
                    playedAt: s.playedAt,
                    placeName: s.placeName,
                    acceptedCount: accepted.length,
                    maxPlayers: s.maxPlayers,
                    pendingCount: pending.length,
                    acceptedOverLimit: s.acceptedOverLimit,
                    progress: pct,
                  ),
                  if (widget.linkedPollStrip != null) ...[
                    const SizedBox(height: 10),
                    widget.linkedPollStrip!,
                  ],
                  const SizedBox(height: 12),
                  _InviteCard(
                    title: 'Aceitos',
                    count: accepted.length,
                    items: accepted,
                    variant: _InviteVariant.accepted,
                    myId: myId,
                    isAdmin: isAdmin,
                    icons: icons,
                    mutating: s.mutating,
                    onAccept: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .acceptInvite(pid),
                    onReject: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .rejectInvite(pid),
                    onSetRole: (mpId, gk) => ref
                        .read(matchNotifierProvider.notifier)
                        .setPlayerRole(mpId, gk),
                  ),
                  const SizedBox(height: 12),
                  _InviteCard(
                    title: 'Não Aceitos',
                    count: rejected.length,
                    items: rejected,
                    variant: _InviteVariant.rejected,
                    myId: myId,
                    isAdmin: isAdmin,
                    icons: icons,
                    mutating: s.mutating,
                    onAccept: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .acceptInvite(pid),
                    onReject: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .rejectInvite(pid),
                    onSetRole: (mpId, gk) => ref
                        .read(matchNotifierProvider.notifier)
                        .setPlayerRole(mpId, gk),
                  ),
                  const SizedBox(height: 12),
                  _InviteCard(
                    title: 'Pendentes',
                    count: pending.length,
                    items: pending,
                    variant: _InviteVariant.pending,
                    myId: myId,
                    isAdmin: isAdmin,
                    icons: icons,
                    mutating: s.mutating,
                    onAccept: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .acceptInvite(pid),
                    onReject: (pid) => ref
                        .read(matchNotifierProvider.notifier)
                        .rejectInvite(pid),
                    onSetRole: (mpId, gk) => ref
                        .read(matchNotifierProvider.notifier)
                        .setPlayerRole(mpId, gk),
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
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
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

class _AcceptanceSummaryCard extends StatelessWidget {
  final DateTime? playedAt;
  final String? placeName;
  final int acceptedCount;
  final int maxPlayers;
  final int pendingCount;
  final bool acceptedOverLimit;
  final double progress;

  const _AcceptanceSummaryCard({
    required this.playedAt,
    required this.placeName,
    required this.acceptedCount,
    required this.maxPlayers,
    required this.pendingCount,
    required this.acceptedOverLimit,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = maxPlayers > 0
        ? ((acceptedCount / maxPlayers) * 100).clamp(0, 100).round()
        : 0;
    final dateText = playedAt == null
        ? null
        : DateFormat('dd/MM/yyyy, HH:mm', 'pt_BR').format(playedAt!);
    final place = placeName?.trim();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900.withValues(alpha: .6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 3, color: AppColors.blue500),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Aceitação',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 14,
                            runSpacing: 5,
                            children: [
                              if (dateText != null)
                                _SummaryMeta(
                                  icon: Icons.access_time_rounded,
                                  text: dateText,
                                  isDark: isDark,
                                ),
                              if (place != null && place.isNotEmpty)
                                _SummaryMeta(
                                  icon: Icons.location_on_outlined,
                                  text: place,
                                  isDark: isDark,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_outlined,
                                size: 15, color: AppColors.slate400),
                            const SizedBox(width: 5),
                            Text(
                              maxPlayers > 0
                                  ? '$acceptedCount/$maxPlayers'
                                  : '$acceptedCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.slate100
                                    : AppColors.slate800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pendentes: $pendingCount',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Confirmados',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor:
                        isDark ? AppColors.slate700 : AppColors.slate100,
                    color: AppColors.blue500,
                  ),
                ),
                if (acceptedOverLimit) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.rose50,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.rose200),
                    ),
                    child: Text(
                      maxPlayers > 0
                          ? 'Passou do limite: $acceptedCount / $maxPlayers. Recuse alguns para avançar.'
                          : 'Passou do limite. Recuse alguns para avançar.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.rose600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _SummaryMeta({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.slate400),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            ),
          ),
        ],
      );
}

enum _InviteVariant { accepted, rejected, pending }

String? _formatInviteRespondedAt(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = parseApiInstantOrNull(value);
  if (parsed == null) return null;
  return DateFormat('dd/MM/yy HH:mm', 'pt_BR').format(parsed);
}

extension _InviteVariantX on _InviteVariant {
  Color get topBorder {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald500;
      case _InviteVariant.rejected:
        return AppColors.rose500;
      case _InviteVariant.pending:
        return AppColors.slate300;
    }
  }

  Color get headerColor {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald700;
      case _InviteVariant.rejected:
        return AppColors.rose500;
      case _InviteVariant.pending:
        return AppColors.slate500;
    }
  }

  Color get countBg {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald200;
      case _InviteVariant.rejected:
        return AppColors.rose200;
      case _InviteVariant.pending:
        return AppColors.slate200;
    }
  }

  Color get countFg {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald700;
      case _InviteVariant.rejected:
        return AppColors.rose600;
      case _InviteVariant.pending:
        return AppColors.slate600;
    }
  }

  Color get avatarBg {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald200;
      case _InviteVariant.rejected:
        return AppColors.rose200;
      case _InviteVariant.pending:
        return AppColors.slate200;
    }
  }

  Color get avatarFg {
    switch (this) {
      case _InviteVariant.accepted:
        return AppColors.emerald700;
      case _InviteVariant.rejected:
        return AppColors.rose600;
      case _InviteVariant.pending:
        return AppColors.slate500;
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
  final String title;
  final int count;
  final List<MatchPlayerInfo> items;
  final _InviteVariant variant;
  final String myId;
  final bool isAdmin;
  final GroupIcons icons;
  final bool mutating;
  final void Function(String pid) onAccept;
  final void Function(String pid) onReject;
  final void Function(String mpId, bool isGk) onSetRole;

  const _InviteCard({
    required this.title,
    required this.count,
    required this.items,
    required this.variant,
    required this.myId,
    required this.isAdmin,
    this.icons = GroupIcons.defaults,
    required this.mutating,
    required this.onAccept,
    required this.onReject,
    required this.onSetRole,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final regular = items.where((p) => !p.isGuest).toList();
    final guests = items.where((p) => p.isGuest).toList();
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
          color:
              isDark ? AppColors.slate900.withValues(alpha: 0.6) : Colors.white,
          border: Border.all(
              color: isDark
                  ? AppColors.slate700.withValues(alpha: 0.6)
                  : AppColors.slate200),
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
                    color: isDark
                        ? AppColors.slate700.withValues(alpha: 0.6)
                        : AppColors.slate100,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                          Icon(Icons.group_outlined,
                              size: 20, color: AppColors.slate400),
                          SizedBox(height: 6),
                          Text('Nenhum jogador',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.slate400)),
                        ],
                      ),
                    )
                  else ...[
                    ...regular.map((p) => _PlayerRow(
                          player: p,
                          isMe: p.playerId == myId,
                          isGuest: false,
                          isAdmin: isAdmin,
                          icons: icons,
                          variant: variant,
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
                                color: isDark
                                    ? AppColors.slate500
                                    : AppColors.slate400,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ]),
                      ),
                      ...guests.map((p) => _PlayerRow(
                            player: p,
                            isMe: p.playerId == myId,
                            isGuest: true,
                            isAdmin: isAdmin,
                            icons: icons,
                            variant: variant,
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
  final GroupIcons icons;
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
    this.icons = GroupIcons.defaults,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = isGuest
        ? (isDark
            ? AppColors.amber500.withValues(alpha: 0.3)
            : AppColors.amber200)
        : variant.avatarBg;
    final avatarFg = isGuest ? AppColors.orange700 : variant.avatarFg;

    final showAccept = _canAct && variant.showAcceptBtn;
    final showReject = _canAct && variant.showRejectBtn;
    final respondedAt = variant == _InviteVariant.pending
        ? null
        : _formatInviteRespondedAt(player.inviteRespondedAt);
    final respondedLabel =
        variant == _InviteVariant.accepted ? 'Aceitou' : 'Recusou';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.slate800.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? AppColors.blue500.withValues(alpha: 0.4)
              : isDark
                  ? AppColors.slate700.withValues(alpha: 0.6)
                  : AppColors.slate100,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
            child: Center(
              child: Text(
                _initials(player.playerName),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: avatarFg),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nome + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                        onTap: mutating
                            ? null
                            : () => onSetRole(
                                player.matchPlayerId, !player.isGoalkeeper),
                        child: Opacity(
                          opacity: mutating ? 0.5 : 1,
                          child: Tooltip(
                            message: player.isGoalkeeper
                                ? 'Goleiro – toque para mudar para linha'
                                : 'Linha – toque para mudar para goleiro',
                            child: renderGroupIcon(
                              player.isGoalkeeper
                                  ? icons.goalkeeper
                                  : icons.player,
                              size: 14,
                              color: AppColors.slate400,
                            ),
                          ),
                        ),
                      )
                    else if (player.isGoalkeeper)
                      renderGroupIcon(icons.goalkeeper,
                          size: 14, color: AppColors.slate400),

                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.blue500.withValues(alpha: 0.3)
                              : AppColors.blue200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Você',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.blue200
                                    : AppColors.blue600)),
                      ),
                    if (isGuest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.amber500.withValues(alpha: 0.25)
                              : AppColors.amber200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.amber400.withValues(alpha: 0.5)),
                        ),
                        child: const Text('Convidado',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.orange700)),
                      ),
                  ],
                ),
                if (respondedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$respondedLabel em $respondedAt',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.slate500 : AppColors.slate400,
                      ),
                    ),
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
                  bgColor: isDark
                      ? AppColors.rose500.withValues(alpha: 0.15)
                      : AppColors.rose50,
                  borderColor: isDark
                      ? AppColors.rose500.withValues(alpha: 0.4)
                      : AppColors.rose200,
                  tooltip: 'Recusar',
                  enabled: !mutating,
                  onTap: () => onReject(player.playerId),
                ),
              if (showAccept) ...[
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.check,
                  color: AppColors.emerald500,
                  bgColor: isDark
                      ? AppColors.emerald500.withValues(alpha: 0.15)
                      : AppColors.emerald50,
                  borderColor: isDark
                      ? AppColors.emerald500.withValues(alpha: 0.4)
                      : AppColors.emerald200,
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
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      );
}
