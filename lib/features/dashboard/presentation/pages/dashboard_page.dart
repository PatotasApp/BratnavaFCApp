import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/realtime/realtime_provider.dart';
import '../../../../shared/presentation/widgets/horizontal_team_field.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../calendar/domain/entities/calendar_event.dart';
import '../../../matches/domain/entities/match_models.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/recent_match_card.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../../core/errors/app_exception.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _refreshingRecent = false;

  Future<void> _refreshRecent(String groupId, String playerId) async {
    if (_refreshingRecent) return;
    setState(() => _refreshingRecent = true);
    ref.invalidate(
        recentMatchesProvider((groupId: groupId, playerId: playerId)));
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _refreshingRecent = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // Fallback: usa o groupId do player ativo se activeGroupId ainda não foi
    // persistido (race condition logo após login com múltiplos grupos)
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';

    if (groupId.isNotEmpty) {
      ref.listen<AsyncValue<BratnavaRealtimeEvent>>(
        realtimeEventsProvider(groupId),
        (_, next) {
          next.whenData((event) {
            if (event.type == 'match.changed') {
              ref.invalidate(upcomingMatchesProvider(groupId));
              ref.invalidate(upcomingMatchesFullProvider(groupId));
              ref.invalidate(currentMatchProvider(groupId));
              if (activePlayer != null) {
                ref.invalidate(recentMatchesProvider(
                    (groupId: groupId, playerId: activePlayer.playerId)));
              }
            }
            if (event.type == 'poll.changed') {
              ref.invalidate(upcomingEventsProvider(groupId));
            }
          });
        },
      );
    }

    final recentAsync = (activePlayer != null && groupId.isNotEmpty)
        ? ref.watch(recentMatchesProvider(
            (groupId: groupId, playerId: activePlayer.playerId)))
        : null;

    // Subtítulo do header — igual ao site
    final headerSubtitle = activePlayer != null
        ? activePlayer.playerName
        : groupId.isNotEmpty
            ? 'Selecione um jogador'
            : 'Crie ou entre em um grupo';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myPlayersProvider);
          if (groupId.isNotEmpty) {
            ref.invalidate(upcomingMatchesFullProvider(groupId));
            ref.invalidate(upcomingEventsProvider(groupId));
            if (activePlayer != null) {
              ref.invalidate(recentMatchesProvider(
                  (groupId: groupId, playerId: activePlayer.playerId)));
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Header gradiente ────────────────────────────────────────────
            _DashboardHeader(subtitle: headerSubtitle),
            const SizedBox(height: 16),

            // ── Próximas partidas ─────────────────────────────────────────────
            if (groupId.isNotEmpty) ...[
              _SectionCard(
                isDark: isDark,
                iconData: Icons.sports_soccer_rounded,
                title: 'Próximas Partidas',
                trailing: _SectionLink(
                  label: 'Ver tudo',
                  color: AppColors.blue600,
                  onTap: () => context.go('/app/matches'),
                ),
                child:
                    _UpcomingMatchesCarousel(groupId: groupId, isDark: isDark),
              ),
              const SizedBox(height: 16),
            ],

            // ── Últimas partidas ─────────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              iconData: Icons.history_rounded,
              title: activePlayer != null
                  ? 'Minhas últimas partidas · ${activePlayer.playerName}'
                  : 'Minhas últimas partidas',
              trailing: (activePlayer != null && groupId.isNotEmpty)
                  ? _RefreshBtn(
                      isLoading: _refreshingRecent,
                      onTap: () =>
                          _refreshRecent(groupId, activePlayer.playerId),
                    )
                  : null,
              child: _buildRecentContent(
                  context, isDark, activePlayer, recentAsync, groupId),
            ),
            const SizedBox(height: 16),

            // ── Situação financeira ───────────────────────────────────────────
            _SectionCard(
              isDark: isDark,
              iconData: Icons.payments_outlined,
              title: 'Financeiro',
              trailing: _SectionLink(
                label: 'Ver',
                color: AppColors.green600,
                onTap: () => context.go('/app/payments'),
              ),
              child: _buildPaymentSummaryContent(context, isDark, groupId),
            ),
            const SizedBox(height: 16),

            // ── Próximos eventos ─────────────────────────────────────────────
            if (groupId.isNotEmpty) ...[
              _SectionCard(
                isDark: isDark,
                iconData: Icons.calendar_month_outlined,
                title: 'Próximos Eventos',
                trailing: _SectionLink(
                  label: 'Calendário',
                  color: AppColors.violet600,
                  onTap: () => context.go('/app/calendar'),
                ),
                child:
                    _UpcomingEventsCarousel(groupId: groupId, isDark: isDark),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Situação financeira — conteúdo ─────────────────────────────────────────
  Widget _buildPaymentSummaryContent(
      BuildContext context, bool isDark, String groupId) {
    if (groupId.isEmpty) {
      return _CenteredMsg(msg: 'Crie ou entre em um grupo', isDark: isDark);
    }
    final summaryAsync = ref.watch(myPaymentSummaryProvider(groupId));
    return summaryAsync.when(
      loading: () => const _Skeleton(height: 60),
      error: (_, __) => _CenteredMsg(
          msg: 'Não foi possível carregar situação financeira.',
          isDark: isDark),
      data: (summary) {
        if (summary == null) {
          return _CenteredMsg(
              msg: 'Nenhuma informação de pagamento disponível.',
              isDark: isDark);
        }
        final hasPending =
            summary.pendingMonthlyCount > 0 || summary.pendingExtraCount > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasPending)
              Row(children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 15, color: AppColors.green600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Em dia',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                      )),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.green600.withValues(alpha: .2)
                        : AppColors.green50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.green600.withValues(alpha: .4)
                          : AppColors.green200,
                    ),
                  ),
                  child: Text('Sem pendências',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.green400 : AppColors.green700,
                      )),
                ),
              ])
            else ...[
              Row(children: [
                Icon(Icons.error_outline_rounded,
                    size: 15,
                    color: isDark ? AppColors.amber400 : AppColors.amber500),
                const SizedBox(width: 8),
                Text('Pendências',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate300 : AppColors.slate600,
                    )),
              ]),
              const SizedBox(height: 6),
              if (summary.pendingMonthlyCount > 0)
                _PaymentSummaryRow(
                  icon: Icons.calendar_month_outlined,
                  label:
                      '${summary.pendingMonthlyCount} mensalidade${summary.pendingMonthlyCount != 1 ? 's' : ''} pendente${summary.pendingMonthlyCount != 1 ? 's' : ''}',
                  isDark: isDark,
                  isAlert: true,
                ),
              if (summary.pendingExtraCount > 0)
                _PaymentSummaryRow(
                  icon: Icons.receipt_outlined,
                  label:
                      '${summary.pendingExtraCount} cobrança${summary.pendingExtraCount != 1 ? 's' : ''} extra pendente${summary.pendingExtraCount != 1 ? 's' : ''}',
                  isDark: isDark,
                  isAlert: true,
                ),
              if (summary.totalPendingAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Total: R\$ ${summary.totalPendingAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.amber400 : AppColors.amber500,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/app/payments'),
              child: Text(
                'Ver pagamentos →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Últimas partidas — conteúdo ─────────────────────────────────────────────
  Widget _buildRecentContent(BuildContext context, bool isDark,
      dynamic activePlayer, AsyncValue? async, String groupId) {
    if (activePlayer == null) {
      return _CenteredMsg(
          msg: 'Selecione um jogador para ver suas últimas partidas.',
          isDark: isDark);
    }
    if (async == null) return const SizedBox.shrink();

    return async.when(
      loading: () => Column(
        children:
            List.generate(3, (_) => const _Skeleton(height: 76, bottom: 8)),
      ),
      error: (e, _) => _CenteredMsg(
          msg: extractDioError(e, 'Não foi possível carregar as partidas.'),
          isDark: isDark),
      data: (matches) {
        if (matches.isEmpty) {
          return _DashedEmpty(
            icon: Icons.calendar_today_outlined,
            title: 'Nenhuma partida encontrada',
            sub: 'As últimas partidas do jogador aparecerão aqui.',
            isDark: isDark,
          );
        }
        return Column(
          children: [
            for (int i = 0; i < matches.length; i++) ...[
              RecentMatchCard(
                match: matches[i],
                groupId: groupId,
              ),
              if (i < matches.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

// ── Helpers compartilhados ────────────────────────────────────────────────────

const _kMonths = [
  'JAN',
  'FEV',
  'MAR',
  'ABR',
  'MAI',
  'JUN',
  'JUL',
  'AGO',
  'SET',
  'OUT',
  'NOV',
  'DEZ',
];

Color? _hexColor(String? hex) {
  if (hex == null) return null;
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

// ── Dots indicator ────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  final bool isDark;
  const _DotsIndicator(
      {required this.count, required this.current, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.blue600
                  : (isDark ? AppColors.slate600 : AppColors.slate300),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );
}

// ── Carrossel: Próximas Partidas (sem header — header fica no SectionCard) ────

class _UpcomingMatchesCarousel extends ConsumerStatefulWidget {
  final String groupId;
  final bool isDark;
  const _UpcomingMatchesCarousel({required this.groupId, required this.isDark});

  @override
  ConsumerState<_UpcomingMatchesCarousel> createState() =>
      _UpcomingMatchesCarouselState();
}

class _UpcomingMatchesCarouselState
    extends ConsumerState<_UpcomingMatchesCarousel> {
  final _ctrl = PageController();
  int _page = 0;
  int _count = 0;
  bool _showField = false;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients || _showField) return;
      final next = (_page + 1) % _count;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  static Color _stepColor(String? key) => switch (key?.toLowerCase()) {
        'playing' || 'live' => AppColors.blue600,
        'post' || 'post_game' => AppColors.orange700,
        'teams' || 'matchmaking' => AppColors.violet600,
        'accept' || 'acceptation' => AppColors.amber500,
        'ended' => AppColors.slate400,
        'done' || 'finished' || 'finalized' => AppColors.slate400,
        _ => AppColors.slate400,
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(upcomingMatchesFullProvider(widget.groupId));
    final myPlayerId = ref.watch(activePlayerProvider)?.playerId ?? '';
    final isDark = widget.isDark;

    return async.when(
      loading: () => const _Skeleton(height: 138),
      error: (_, __) => _DashedEmpty(
        icon: Icons.sports_soccer_rounded,
        title: 'Sem partidas em andamento',
        sub: 'Inicie uma partida na seção Partidas.',
        isDark: isDark,
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return _DashedEmpty(
            icon: Icons.sports_soccer_rounded,
            title: 'Sem partidas em andamento',
            sub: 'Inicie uma partida na seção Partidas.',
            isDark: isDark,
          );
        }
        if (_count != matches.length) {
          _count = matches.length;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }
        // Computa se a partida atual pode mostrar o campo
        final cur = matches[_page.clamp(0, matches.length - 1)];
        final curStep = cur.header.stepKey.toLowerCase();
        final canField = (curStep == 'teams' ||
                curStep == 'matchmaking' ||
                curStep == 'playing' ||
                curStep == 'live') &&
            cur.allPlayers.any((p) => p.team == 1 || p.team == 2);

        // Altura fixa para todos os cards — footer oculto mas com tamanho mantido
        const cardH = 138.0;

        // Monta as listas de jogadores para o campo do carrossel
        Color? parsedA, parsedB;
        try {
          parsedA = cur.teamAColor != null
              ? Color(int.parse(
                  '0xFF${cur.teamAColor!.hexValue.replaceAll('#', '')}'))
              : null;
        } catch (_) {}
        try {
          parsedB = cur.teamBColor != null
              ? Color(int.parse(
                  '0xFF${cur.teamBColor!.hexValue.replaceAll('#', '')}'))
              : null;
        } catch (_) {}
        final fieldAColor = parsedA ?? AppColors.blue500;
        final fieldBColor = parsedB ?? AppColors.slate400;
        final fieldA = cur.allPlayers
            .where((p) => p.team == 1)
            .map((p) => FieldPlayer(
                id: p.playerId,
                name: p.playerName,
                isGoalkeeper: p.isGoalkeeper))
            .toList();
        final fieldB = cur.allPlayers
            .where((p) => p.team == 2)
            .map((p) => FieldPlayer(
                id: p.playerId,
                name: p.playerName,
                isGoalkeeper: p.isGoalkeeper))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              height: cardH,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: matches.length,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _page = i;
                  _showField = false;
                }),
                itemBuilder: (_, i) {
                  final m = matches[i];
                  final sk = m.header.stepKey.toLowerCase();
                  final hasTeams = (sk == 'teams' ||
                          sk == 'matchmaking' ||
                          sk == 'playing' ||
                          sk == 'live') &&
                      m.allPlayers.any((p) => p.team == 1 || p.team == 2);
                  return _MatchCard(
                    match: m,
                    myPlayerId: myPlayerId,
                    isDark: isDark,
                    canShowField: hasTeams,
                    showField: i == _page && _showField,
                    onShowFieldChange: (v) => setState(() => _showField = v),
                    onTap: () =>
                        context.go('/app/matches?matchId=${m.header.matchId}'),
                  );
                },
              ),
            ),

            // Campo expandido — fora do PageView para não quebrar o layout
            if (canField && _showField) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: HorizontalTeamField(
                  teamA: fieldA,
                  teamB: fieldB,
                  teamAColor: fieldAColor,
                  teamBColor: fieldBColor,
                ),
              ),
            ],

            if (matches.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      final next =
                          (_page - 1 + matches.length) % matches.length;
                      _ctrl.animateToPage(next,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                    child: const Icon(Icons.chevron_left_rounded,
                        size: 20, color: AppColors.slate400),
                  ),
                  _DotsIndicator(
                      count: matches.length, current: _page, isDark: isDark),
                  GestureDetector(
                    onTap: () {
                      final next = (_page + 1) % matches.length;
                      _ctrl.animateToPage(next,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.slate400),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Card de partida upcoming ──────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final UpcomingMatchDetails match;
  final String myPlayerId;
  final bool isDark;
  final bool canShowField;
  final bool showField;
  final ValueChanged<bool> onShowFieldChange;
  final VoidCallback onTap;

  const _MatchCard({
    required this.match,
    required this.myPlayerId,
    required this.isDark,
    required this.canShowField,
    required this.showField,
    required this.onShowFieldChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = match.header;
    final stepKey = h.stepKey.toLowerCase();
    final stepColor = _UpcomingMatchesCarouselState._stepColor(stepKey);
    final d = h.playedAt;
    final me = match.findPlayer(myPlayerId);

    // Após aceitação fechada, quem não respondeu é exibido como recusado
    final acceptOpen = stepKey == 'accept' || stepKey == 'acceptation';
    final effectiveInvite =
        (me?.inviteResponse == InviteResponse.pending && !acceptOpen)
            ? InviteResponse.declined
            : me?.inviteResponse;

    final (statusLabel, statusColor) = me == null
        ? ('', AppColors.slate400)
        : switch (effectiveInvite) {
            InviteResponse.accepted => ('✓ Confirmado', AppColors.emerald500),
            InviteResponse.declined => ('✗ Não aceitou', AppColors.rose500),
            _ => ('Pendente', AppColors.amber500),
          };

    final myTeamColor = me == null
        ? null
        : me.team == 1
            ? match.teamAColor
            : me.team == 2
                ? match.teamBColor
                : null;

    final isLive = stepKey == 'playing' || stepKey == 'live';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: stepColor),
            // ── Coluna data — estica até o fim do card ────────────────────
            Container(
              width: 54,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.slate800.withValues(alpha: .5)
                    : AppColors.slate50,
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate100,
                  ),
                ),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_kMonths[d.month - 1],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400,
                            letterSpacing: 0.5)),
                    Text(d.day.toString().padLeft(2, '0'),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: isDark
                                ? AppColors.slate100
                                : AppColors.slate900)),
                    Text(
                        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500)),
                  ]),
            ),

            // ── Lado direito: conteúdo principal + footer ─────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha principal
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Conteúdo central ──────────────────────────────
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Row(children: [
                                  if (isLive) ...[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.blue600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'AO VIVO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.blue600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stepColor.withValues(alpha: .10),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color:
                                              stepColor.withValues(alpha: .28),
                                        ),
                                      ),
                                      child: Text(
                                        matchStepLabel(h.statusName.isNotEmpty
                                            ? h.statusName
                                            : stepKey),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: stepColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (h.canRewind) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.replay_rounded,
                                        size: 11, color: AppColors.slate400),
                                  ],
                                ]),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 11,
                                      color: isDark
                                          ? AppColors.slate600
                                          : AppColors.slate300,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        h.placeName.isNotEmpty
                                            ? h.placeName
                                            : 'Partida',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? AppColors.slate400
                                                : AppColors.slate500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                Container(
                                  height: 20,
                                  padding: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                                .withValues(alpha: .5)
                                            : AppColors.slate100,
                                      ),
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: me != null ? 1 : 0,
                                    child: Row(children: [
                                      Text('VOCÊ',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.slate500
                                                  : AppColors.slate400)),
                                      if (myTeamColor != null) ...[
                                        const SizedBox(width: 4),
                                        _ColorCircle(
                                            hex: myTeamColor.hexValue, size: 9),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(myTeamColor.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark
                                                      ? AppColors.slate400
                                                      : AppColors.slate500)),
                                        ),
                                      ],
                                      if (statusLabel.isNotEmpty) ...[
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(statusLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor)),
                                        ),
                                      ],
                                    ]),
                                  ),
                                ),

                                // Linha do poll/evento vinculado
                                Container(
                                  height: 22,
                                  padding: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: isDark
                                            ? AppColors.slate700
                                                .withValues(alpha: .5)
                                            : AppColors.slate100,
                                      ),
                                    ),
                                  ),
                                  child: match.linkedEventTitle == null
                                      ? const SizedBox.shrink()
                                      : Row(children: [
                                          Icon(
                                            match.linkedIsEvent
                                                ? Icons.how_to_vote_outlined
                                                : Icons.poll_rounded,
                                            size: 11,
                                            color: isDark
                                                ? AppColors.slate500
                                                : AppColors.slate400,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${match.linkedEventIcon != null && match.linkedEventIcon!.isNotEmpty ? '${match.linkedEventIcon} ' : ''}${match.linkedEventTitle!}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark
                                                      ? AppColors.slate400
                                                      : AppColors.slate500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (match.myVoteText != null) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.emerald500
                                                    .withValues(alpha: .1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                  '✓ ${match.myVoteText}',
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors
                                                          .emerald500)),
                                            ),
                                          ] else ...[
                                            const SizedBox(width: 4),
                                            const Text('PENDENTE',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.amber500)),
                                          ],
                                        ]),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Container(
                          width: 84,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate100,
                              ),
                            ),
                          ),
                          child: _UpcomingRightPanel(
                            match: match,
                            myPlayer: me,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Footer: Ver times ─────────────────────────────────
                  Visibility(
                    visible: canShowField,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.slate800
                                : AppColors.slate100),
                        GestureDetector(
                          onTap: () => onShowFieldChange(!showField),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  showField
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  showField ? 'OCULTAR TIMES' : 'VER TIMES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Chip de contador (✓2 / ⏰20 / ✗0) ────────────────────────────────────────

class _UpcomingRightPanel extends StatelessWidget {
  final UpcomingMatchDetails match;
  final MatchPlayerInfo? myPlayer;
  final bool isDark;

  const _UpcomingRightPanel({
    required this.match,
    required this.myPlayer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final h = match.header;
    final step = h.stepKey.toLowerCase();
    final hasScore = h.teamAGoals != null && h.teamBGoals != null;
    final score = hasScore
        ? _ScoreBox(a: h.teamAGoals ?? 0, b: h.teamBGoals ?? 0, isDark: isDark)
        : null;

    if (step == 'accept' || step == 'acceptation') {
      if (match.allPlayers.isEmpty) return _Chevron(isDark: isDark);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CountChip(
            icon: Icons.check_circle_rounded,
            count: match.acceptedCount,
            color: AppColors.emerald500,
          ),
          const SizedBox(height: 4),
          _CountChip(
            icon: Icons.access_time_rounded,
            count: match.pendingCount,
            color: AppColors.amber500,
          ),
          if (match.refusedCount > 0) ...[
            const SizedBox(height: 4),
            _CountChip(
              icon: Icons.cancel_rounded,
              count: match.refusedCount,
              color: AppColors.rose500,
            ),
          ],
        ],
      );
    }

    if (step == 'teams' || step == 'matchmaking') {
      final myTeam = myPlayer?.team ?? 0;
      final myColor = myTeam == 1
          ? match.teamAColor
          : myTeam == 2
              ? match.teamBColor
              : null;
      if (myTeam != 0 && myColor != null) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ColorCircle(hex: myColor.hexValue, size: 10),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    myColor.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.slate200 : AppColors.slate700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'seu time',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ],
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _TeamCountLine(
            color: match.teamAColor,
            fallback: 'Time A',
            count: match.allPlayers.where((p) => p.team == 1).length,
            isDark: isDark,
          ),
          const SizedBox(height: 5),
          _TeamCountLine(
            color: match.teamBColor,
            fallback: 'Time B',
            count: match.allPlayers.where((p) => p.team == 2).length,
            isDark: isDark,
          ),
        ],
      );
    }

    if (step == 'playing' || step == 'live') {
      return score ??
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue600,
                ),
                child: SizedBox(width: 12, height: 12),
              ),
              SizedBox(height: 4),
              Text(
                'vivo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue600,
                ),
              ),
            ],
          );
    }

    if (step == 'post' || step == 'post_game') {
      final isMvp = myPlayer?.isMvp == true;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          score ?? const Text('-', style: TextStyle(color: AppColors.slate400)),
          if (isMvp) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.amber500.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.amber500.withValues(alpha: .3)),
              ),
              child: const Text(
                'MVP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber500,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return score ?? _Chevron(isDark: isDark);
  }
}

class _ScoreBox extends StatelessWidget {
  final int a;
  final int b;
  final bool isDark;

  const _ScoreBox({required this.a, required this.b, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700 : AppColors.slate900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$a × $b',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TeamCountLine extends StatelessWidget {
  final TeamColorInfo? color;
  final String fallback;
  final int count;
  final bool isDark;

  const _TeamCountLine({
    required this.color,
    required this.fallback,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorCircle(hex: color?.hexValue ?? '', size: 10),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            color?.name ?? fallback,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.slate500 : AppColors.slate400,
          ),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  final bool isDark;
  const _Chevron({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: isDark ? AppColors.slate600 : AppColors.slate300,
        ),
      );
}

class _CountChip extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final int count;

  const _CountChip({
    this.icon,
    this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 13, child: Icon(icon, size: 11, color: color)),
        SizedBox(
          width: 22,
          child: Text('$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

// ── Bolinha colorida de time ──────────────────────────────────────────────────

class _ColorCircle extends StatelessWidget {
  final String hex;
  final double size;
  const _ColorCircle({required this.hex, this.size = 12});

  static bool _isLight(Color c) => c.computeLuminance() > 0.7;

  @override
  Widget build(BuildContext context) {
    Color? c;
    try {
      c = Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {}
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final light = c != null && _isLight(c);
    final borderColor = c == null
        ? Colors.transparent
        : light
            ? (isDark ? AppColors.slate500 : AppColors.slate300)
            : Colors.white.withValues(alpha: .35);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c ?? (isDark ? AppColors.slate700 : AppColors.slate200),
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}

// ── Carrossel: Próximos Eventos (sem header) ─────────────────────────────────

class _UpcomingEventsCarousel extends ConsumerStatefulWidget {
  final String groupId;
  final bool isDark;
  const _UpcomingEventsCarousel({required this.groupId, required this.isDark});

  @override
  ConsumerState<_UpcomingEventsCarousel> createState() =>
      _UpcomingEventsCarouselState();
}

class _UpcomingEventsCarouselState
    extends ConsumerState<_UpcomingEventsCarousel> {
  final _ctrl = PageController();
  int _page = 0;
  int _count = 0;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    if (_count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) % _count;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(upcomingEventsProvider(widget.groupId));
    return async.when(
      loading: () => const _Skeleton(height: 86),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) {
          return _DashedEmpty(
            icon: Icons.event_rounded,
            title: 'Nenhum evento próximo',
            sub: 'Eventos dos próximos meses aparecerão aqui.',
            isDark: widget.isDark,
          );
        }
        final visible = events.take(5).toList();
        if (_count != visible.length) {
          _count = visible.length;
          if (_page >= _count) _page = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 86,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: visible.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) =>
                    _UpcomingEventTile(ev: visible[i], isDark: widget.isDark),
              ),
            ),
            if (visible.length > 1) ...[
              const SizedBox(height: 8),
              _DotsIndicator(
                  count: visible.length, current: _page, isDark: widget.isDark),
            ],
          ],
        );
      },
    );
  }
}

class _UpcomingEventTile extends StatelessWidget {
  final CalendarEvent ev;
  final bool isDark;
  const _UpcomingEventTile({required this.ev, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final catColor = _hexColor(ev.categoryColor) ?? AppColors.violet600;
    DateTime? d;
    try {
      d = DateTime.parse(ev.date);
    } catch (_) {}

    return SizedBox(
      height: 86,
      child: GestureDetector(
        onTap: () => context.go('/app/calendar'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 64,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: .08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                border: Border(
                  right: BorderSide(color: catColor.withValues(alpha: .2)),
                ),
              ),
              child: d == null
                  ? Center(
                      child:
                          Icon(Icons.event_rounded, size: 20, color: catColor))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_kMonths[d.month - 1],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                              letterSpacing: 0.5,
                            )),
                        Text(d.day.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: isDark
                                  ? AppColors.slate100
                                  : AppColors.slate900,
                            )),
                      ],
                    ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(ev.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.slate100 : AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (!ev.timeTBD &&
                          ev.time != null &&
                          ev.time!.isNotEmpty) ...[
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
                        const SizedBox(width: 3),
                        Text(
                          ev.time!.length >= 5
                              ? ev.time!.substring(0, 5)
                              : ev.time!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (ev.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ev.categoryName!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: catColor,
                              )),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? AppColors.slate600 : AppColors.slate300),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Link de ação na header da SectionCard ─────────────────────────────────────

class _SectionLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SectionLink(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          Icon(Icons.chevron_right_rounded, size: 14, color: color),
        ]),
      );
}

// ── Header gradiente ──────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String subtitle;
  const _DashboardHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .2)),
            ),
            child: const Icon(Icons.dashboard_rounded,
                size: 26, color: Colors.white),
          ),
          const SizedBox(width: 16),
          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .5),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData iconData;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.iconData,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.slate900 : Colors.white;
    final headerBg = isDark
        ? AppColors.slate800.withValues(alpha: .8)
        : AppColors.slate50.withValues(alpha: .9);
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final divColor = isDark ? AppColors.slate800 : AppColors.slate100;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: divColor)),
            ),
            child: Row(
              children: [
                Icon(iconData,
                    size: 14,
                    color: isDark ? AppColors.slate500 : AppColors.slate400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Botão atualizar ────────────────────────────────────────────────────────────

class _RefreshBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _RefreshBtn({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? .6 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .04), blurRadius: 2),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
              const SizedBox(width: 4),
              Text(
                'Atualizar',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  final double height;
  final double bottom;
  const _Skeleton({required this.height, this.bottom = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ── Empty state com borda tracejada ───────────────────────────────────────────

class _DashedEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool isDark;
  const _DashedEmpty({
    required this.icon,
    required this.title,
    required this.sub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 32,
              color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              sub,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mensagem centrada simples ──────────────────────────────────────────────────

class _CenteredMsg extends StatelessWidget {
  final String msg;
  final bool isDark;
  const _CenteredMsg({required this.msg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.slate500 : AppColors.slate400,
        ),
      ),
    );
  }
}

// ── Payment summary row ───────────────────────────────────────────────────────

class _PaymentSummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isAlert;

  const _PaymentSummaryRow({
    required this.icon,
    required this.label,
    required this.isDark,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon,
              size: 15,
              color: isAlert
                  ? (isDark ? AppColors.amber400 : AppColors.amber500)
                  : AppColors.green600),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              )),
        ]),
      );
}
