import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../../shared/presentation/widgets/user_profile_link.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';

class Step2AceitacaoPage extends ConsumerStatefulWidget {
  final Widget? linkedPollStrip;
  const Step2AceitacaoPage({super.key, this.linkedPollStrip});

  @override
  ConsumerState<Step2AceitacaoPage> createState() => _Step2State();
}

class _Step2State extends ConsumerState<Step2AceitacaoPage> {
  static const _tabAccepted = 'Aceitos';
  static const _tabRejected = 'Não aceitos';
  static const _tabPending = 'Pendentes';
  static const _tabs = [_tabAccepted, _tabRejected, _tabPending];

  /// O protótipo separa as três respostas em abas, com uma lista só embaixo.
  /// Empilhar os três cards obrigava a rolar a tela inteira para chegar nos
  /// pendentes, que é justamente onde há trabalho a fazer.
  String _tab = _tabAccepted;

  Future<void> _goNext() async {
    await ref.read(matchNotifierProvider.notifier).goToMatchmaking();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(matchNotifierProvider);
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final activePlayerPhoto = activePlayer?.photoUrl?.trim();
    final myPhotoUrl = activePlayerPhoto?.isNotEmpty == true
        ? activePlayerPhoto
        : myProfile?.photoUrl;
    final accepted = s.acceptedPlayers;
    final rejected = s.rejectedPlayers;
    final pending = s.pendingPlayers;
    final myId = account?.activePlayerId ?? activePlayer?.playerId ?? '';
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final gid = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final isGroupAdmin =
        gid.isNotEmpty && (account?.isGroupAdmin(gid) ?? false);
    final isAdmin = isGroupAdmin;
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
                  PrototypeSegmented(
                    items: _tabs,
                    value: _tab,
                    semanticLabel: 'Filtrar por resposta',
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: 12),
                  _InviteCard(
                    title: _tab,
                    count: switch (_tab) {
                      _tabRejected => rejected.length,
                      _tabPending => pending.length,
                      _ => accepted.length,
                    },
                    items: switch (_tab) {
                      _tabRejected => rejected,
                      _tabPending => pending,
                      _ => accepted,
                    },
                    variant: switch (_tab) {
                      _tabRejected => _InviteVariant.rejected,
                      _tabPending => _InviteVariant.pending,
                      _ => _InviteVariant.accepted,
                    },
                    myId: myId,
                    myPhotoUrl: myPhotoUrl,
                    isAdmin: isAdmin,
                    icons: icons,
                    pendingPlayerIds: s.pendingPlayerIds,
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
                              strokeWidth: 2, color: AppColors.onDark))
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = AppColors.accentOf(theme.brightness);

    final dateText = playedAt == null
        ? null
        : DateFormat("EEEE, dd/MM/yyyy", "pt_BR").format(playedAt!);
    final place = placeName?.trim();
    final meta = [
      if (dateText != null) dateText[0].toUpperCase() + dateText.substring(1),
      if (place != null && place.isNotEmpty) place,
    ].join(' \u00b7 ');

    // Espelha `.proto-acceptance-summary`: borda esquerda de 3px no accent,
    // \u00edcone circular de 40px e a contagem em destaque (17px). A vers\u00e3o anterior
    // usava azul \u2014 cor que n\u00e3o existe na paleta do prot\u00f3tipo \u2014 e escondia o
    // n\u00famero num canto, atr\u00e1s de uma barra de porcentagem.
    final borderColor = isDark ? AppColors.darkElevated : AppColors.lightBorder;

    // A faixa lateral do accent é desenhada como filha, não como
    // `Border(left: ... width: 3)`. Um `Border` não-uniforme junto de
    // `borderRadius` é proibido pelo Flutter ("A borderRadius can only be
    // given for a uniform Border"): o BoxDecoration falha ao pintar e o card
    // inteiro sai vazio — sem ícone, sem texto, sem borda. Era esse o card em
    // branco na tela, não dado faltando.
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSubtle : AppColors.lightCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: AppColors.shadow08,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Faixa do accent: `Positioned` com top/bottom esticando na
            // altura que o conteúdo definir. `Row` com stretch não serviria
            // aqui — a altura chega sem limite, vindo de um scroll.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: accent),
            ),
            Padding(
              // 14 do protótipo + 3 da faixa.
              padding: const EdgeInsets.fromLTRB(17, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentBgOf(theme.brightness),
                    ),
                    child: Icon(Icons.groups_rounded,
                        size: 20,
                        color: AppColors.accentTextOf(theme.brightness)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          maxPlayers > 0
                              ? "$acceptedCount / $maxPlayers confirmados"
                              : "$acceptedCount confirmados",
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? AppColors.onDark : AppColors.lightText,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                        if (pendingCount > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            "$pendingCount aguardando resposta",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                        if (acceptedOverLimit) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBgOf(theme.brightness),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: AppColors.dangerOf(theme.brightness)),
                            ),
                            child: Text(
                              maxPlayers > 0
                                  ? 'Passou do limite: $acceptedCount / $maxPlayers. Recuse alguns para avan\u00e7ar.'
                                  : 'Passou do limite. Recuse alguns para avan\u00e7ar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.dangerOf(theme.brightness),
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
            ),
          ],
        ),
      ),
    );
  }
}

enum _InviteVariant { accepted, rejected, pending }

/// Restaram só as duas regras de comportamento. Os seis getters de cor
/// (`topBorder`, `headerColor`, `countBg`, `countFg`, `avatarBg`, `avatarFg`)
/// saíram junto com a repaginação: no protótipo a resposta não pinta card,
/// cabeçalho nem avatar — quem indica o filtro é a aba selecionada.
extension _InviteVariantX on _InviteVariant {
  bool get showAcceptBtn {
    return this == _InviteVariant.pending || this == _InviteVariant.rejected;
  }

  bool get showRejectBtn {
    return this == _InviteVariant.pending || this == _InviteVariant.accepted;
  }
}

// ── Card de convite pessoal (para quem é admin e também jogador) ──────────────

class _InviteCard extends StatelessWidget {
  final String title;
  final int count;
  final List<MatchPlayerInfo> items;
  final _InviteVariant variant;
  final String myId;
  final String? myPhotoUrl;
  final bool isAdmin;
  final GroupIcons icons;

  /// playerIds com aceite/recusa em voo. Antes isto era um `bool mutating`
  /// único, que desabilitava a tela inteira a cada toque.
  final Set<String> pendingPlayerIds;

  final void Function(String pid) onAccept;
  final void Function(String pid) onReject;
  final void Function(String mpId, bool isGk) onSetRole;

  const _InviteCard({
    required this.title,
    required this.count,
    required this.items,
    required this.variant,
    required this.myId,
    this.myPhotoUrl,
    required this.isAdmin,
    this.icons = GroupIcons.defaults,
    required this.pendingPlayerIds,
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

    // `.proto-card`: raio 16, padding 14, borda neutra — sem barra colorida no
    // topo e sem cabeçalho tingido pela variante. No protótipo a cor da
    // resposta não pinta o card; quem diferencia é a aba selecionada.
    return Container(
      padding: const EdgeInsets.all(PrototypeLayout.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.lightCard,
        border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(PrototypeLayout.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `SectionTitle`: título em caixa normal + contagem num chip neutro.
          PrototypeSectionTitle(title: title, count: '$count'),
          const SizedBox(height: 10),
          Column(
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
                ..._withDividers(
                  regular.map(_row).toList(),
                  isDark: isDark,
                ),
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
                  ..._withDividers(
                    guests.map(_row).toList(),
                    isDark: isDark,
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(MatchPlayerInfo p) => _PlayerRow(
        player: p,
        isMe: p.playerId == myId,
        photoUrlOverride: p.playerId == myId ? myPhotoUrl : null,
        isGuest: p.isGuest,
        isAdmin: isAdmin,
        icons: icons,
        variant: variant,
        // Aceite/recusa entram no conjunto pelo playerId; o toggle de goleiro,
        // pelo matchPlayerId.
        busy: pendingPlayerIds.contains(p.playerId) ||
            pendingPlayerIds.contains(p.matchPlayerId),
        onAccept: onAccept,
        onReject: onReject,
        onSetRole: onSetRole,
      );

  /// `.proto-card>.proto-list-row+.proto-list-row{border-top-color:…}` — o
  /// protótipo separa as linhas de dentro de um card por um fio, não por
  /// espaçamento com cada linha virando um cartão próprio.
  static List<Widget> _withDividers(List<Widget> rows, {required bool isDark}) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        out.add(Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppColors.slate800 : AppColors.lightBorder,
        ));
      }
      out.add(rows[i]);
    }
    return out;
  }
}

// ── Linha de jogador ──────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  static const double _avatarSize = 44;

  final MatchPlayerInfo player;
  final bool isMe;
  final String? photoUrlOverride;
  final bool isGuest;
  final bool isAdmin;
  final GroupIcons icons;
  final _InviteVariant variant;

  /// Só esta linha tem uma ação em voo. As outras seguem clicáveis, para o
  /// admin conseguir aceitar vários jogadores em sequência.
  final bool busy;

  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(String, bool) onSetRole;

  const _PlayerRow({
    required this.player,
    required this.isMe,
    this.photoUrlOverride,
    required this.isGuest,
    required this.isAdmin,
    this.icons = GroupIcons.defaults,
    required this.variant,
    required this.busy,
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
    final theme = Theme.of(context);

    // `.proto-avatar`: quadrado arredondado de 34 com raio 12, em accent-bg
    // sobre accent-text — não um círculo colorido pela resposta. No protótipo
    // o avatar não muda de cor conforme aceito/recusado/pendente.
    final avatarBg = isGuest
        ? (isDark
            ? AppColors.amber500.withValues(alpha: 0.3)
            : AppColors.amber200)
        : AppColors.accentBgOf(theme.brightness);
    final avatarFg = isGuest
        ? AppColors.warningLight
        : AppColors.accentTextOf(theme.brightness);

    final showAccept = _canAct && variant.showAcceptBtn;
    final showReject = _canAct && variant.showRejectBtn;
    final photoUrl = player.photoUrl?.trim().isNotEmpty == true
        ? player.photoUrl
        : photoUrlOverride;
    final hasPhoto = photoUrl?.trim().isNotEmpty == true;

    // `.proto-card>.proto-list-row`: fundo e borda transparentes. A linha só
    // vira um cartão próprio quando está solta fora de um card.
    return Container(
      constraints:
          const BoxConstraints(minHeight: PrototypeLayout.listRowMinHeight),
      padding: PrototypeLayout.listRowPadding,
      child: Row(
        children: [
          UserProfileLink(
            userId: player.userId,
            child: (!isGuest || hasPhoto)
                ? AvatarWidget(
                    name: player.playerName,
                    photoUrl: photoUrl,
                    size: _avatarSize,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      borderRadius:
                          BorderRadius.circular(PrototypeLayout.avatarRadius),
                    ),
                    child: Center(
                      child: Text(
                        _initials(player.playerName),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: avatarFg),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: PrototypeLayout.rowGap),

          // Nome + badges
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: [
                UserProfileLink(
                  userId: player.userId,
                  child: Text(
                    player.playerName,
                    style: TextStyle(
                      // `.proto-list-row` usa 12/700 no nome, não 13/500.
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.onDark : AppColors.lightText,
                    ),
                  ),
                ),
                // Goleiro toggle (admin) ou ícone (não-admin)
                if (isAdmin)
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () => onSetRole(
                            player.matchPlayerId, !player.isGoalkeeper),
                    child: Opacity(
                      opacity: busy ? 0.5 : 1,
                      child: Tooltip(
                        message: player.isGoalkeeper
                            ? 'Goleiro – toque para mudar para linha'
                            : 'Linha – toque para mudar para goleiro',
                        child: renderGroupIcon(
                          player.isGoalkeeper ? icons.goalkeeper : icons.player,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                      ),
                    ),
                  )
                else
                  renderGroupIcon(
                    player.isGoalkeeper ? icons.goalkeeper : icons.player,
                    size: 14,
                    color: AppColors.slate400,
                  ),

                // `Badge tone="accent"` = `.proto-chip.active`: preenchido no
                // accent com texto sobre ele. O azul não existe na paleta do
                // protótipo.
                if (isMe)
                  Container(
                    // Sem `alignment` e sem `height`: dentro de um `Wrap` o
                    // filho recebe a largura máxima da linha, e um `Container`
                    // com alignment vira um `Align` que a preenche inteira —
                    // era isso que esticava o badge de ponta a ponta. Só com
                    // padding ele encolhe para o texto.
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentOf(theme.brightness),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    // `--on-accent` no tema claro é #17191e, quase preto — não
                    // branco. Conferido com tools/resolve-style.mjs.
                    child: Text('Você',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppColors.onAccentOf(theme.brightness))),
                  ),
                if (isGuest)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.amber500.withValues(alpha: 0.25)
                          : AppColors.amber200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Convidado',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningLight)),
                  ),
              ],
            ),
          ),

          // `.proto-icon-btn`: 44×44, raio 12, borda e fundo neutros, ícone em
          // text-secondary. O protótipo não tinge esses botões de verde e
          // vermelho — a ação já é clara pelo ícone e pela aba.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showReject)
                _ActionBtn(
                  icon: Icons.close,
                  isDark: isDark,
                  tooltip: 'Recusar',
                  enabled: !busy,
                  onTap: () => onReject(player.playerId),
                ),
              if (showAccept) ...[
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.check,
                  isDark: isDark,
                  tooltip: 'Aceitar',
                  enabled: !busy,
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

/// `.proto-icon-btn`: 44×44, raio 12, borda de card sobre fundo de card e
/// ícone de 15 em text-secondary. Antes eram quadrados de 28 tingidos de verde
/// ou vermelho — fora da paleta e abaixo do alvo de toque mínimo do protótipo.
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.isDark,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: tooltip,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(PrototypeLayout.controlRadius),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: Container(
                width: PrototypeLayout.minimumTouchTarget,
                height: PrototypeLayout.minimumTouchTarget,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate900 : AppColors.lightCard,
                  borderRadius:
                      BorderRadius.circular(PrototypeLayout.controlRadius),
                  border: Border.all(
                      color:
                          isDark ? AppColors.slate700 : AppColors.lightBorder),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ),
      );
}
