import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/realtime/realtime_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/football_pitch.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../calendar/domain/entities/calendar_event.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../matches/domain/entities/match_models.dart';
import '../../../matches/presentation/providers/match_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../payments/presentation/providers/payments_provider.dart';
import '../../../player_history/domain/entities/player_history_models.dart';
import '../../../player_history/presentation/providers/player_history_provider.dart'
    as player_history;
import '../../../polls/presentation/providers/polls_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final Set<String> _respondingMatches = {};

  Future<void> _refresh(String groupId, String? playerId) async {
    ref.invalidate(myPlayersProvider);
    if (groupId.isEmpty) return;

    ref.invalidate(upcomingMatchesFullProvider(groupId));
    ref.invalidate(upcomingEventsProvider(groupId));
    ref.invalidate(pollsListProvider(groupId));
    ref.invalidate(myPaymentSummaryProvider(groupId));
    ref.invalidate(pendingPollsCountProvider(groupId));
    if (playerId != null) {
      ref.invalidate(
        player_history.playerHistoryProvider(
          (
            groupId: groupId,
            playerId: playerId,
            // Sem ano: o card mostra o total da carreira e precisa da
            // primeira temporada, que só aparece no histórico completo.
            year: null,
          ),
        ),
      );
    }
  }

  Future<void> _respondToMatch({
    required UpcomingMatchDetails match,
    required String playerId,
    required bool accept,
  }) async {
    if (_respondingMatches.contains(match.header.matchId)) return;
    setState(() => _respondingMatches.add(match.header.matchId));

    try {
      final datasource = ref.read(matchDsProvider);
      if (accept) {
        await datasource.acceptInvite(
          match.header.groupId,
          match.header.matchId,
          playerId,
        );
      } else {
        await datasource.rejectInvite(
          match.header.groupId,
          match.header.matchId,
          playerId,
        );
      }
      ref.invalidate(upcomingMatchesFullProvider(match.header.groupId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Presença confirmada.' : 'Ausência informada.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível atualizar: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingMatches.remove(match.header.matchId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final playersAsync = ref.watch(myPlayersProvider);
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo, não o `activeGroupId` da conta.
    //
    // O log mostrou o estrago da ordem antiga: a conta apontava para
    // `3f401edf…` enquanto `/players/mine` devolvia o jogador em
    // `26d42510…`. Todas as rotas por grupo respondiam **403 Forbidden**
    // (`/upcoming`, `/player-history`, `/TeamColor`), porque o usuário não é
    // membro daquela patota — daí os zeros e o "não foi possível carregar".
    //
    // `activePlayerProvider` já escolhe o jogador do grupo da conta quando
    // existe um; nesse caso os dois valores coincidem e nada muda. Quando não
    // existe, é o jogador que está certo: é dele que vêm as permissões.
    final groupId = activePlayer?.groupId ?? account?.activeGroupId ?? '';
    final playerId = activePlayer?.playerId;

    if (groupId.isNotEmpty) {
      ref.listen<AsyncValue<BratnavaRealtimeEvent>>(
        realtimeEventsProvider(groupId),
        (_, next) {
          next.whenData((event) {
            if (event.type == 'match.changed') {
              ref.invalidate(upcomingMatchesFullProvider(groupId));
              if (playerId != null) {
                ref.invalidate(
                  player_history.playerHistoryProvider(
                    (
                      groupId: groupId,
                      playerId: playerId,
                      // Sem ano: o card mostra o total da carreira e precisa da
                      // primeira temporada, que só aparece no histórico completo.
                      year: null,
                    ),
                  ),
                );
              }
            } else if (event.type == 'poll.changed') {
              ref.invalidate(pendingPollsCountProvider(groupId));
              ref.invalidate(upcomingEventsProvider(groupId));
              ref.invalidate(pollsListProvider(groupId));
            }
          });
        },
      );
    }

    if (activePlayer == null) {
      if (playersAsync.isLoading) {
        return PrototypeScrollView(
          onRefresh: () => _refresh(groupId, playerId),
          child: const _DashboardLoadingState(),
        );
      }

      if (playersAsync.hasError) {
        return PrototypeScrollView(
          onRefresh: () => _refresh(groupId, playerId),
          child: _DashboardLoadErrorState(
            onRetry: () => ref.invalidate(myPlayersProvider),
          ),
        );
      }

      if (groupId.isNotEmpty) {
        return PrototypeScrollView(
          onRefresh: () => _refresh(groupId, playerId),
          child: _DashboardPlayerMissingState(
            onRetry: () => ref.invalidate(myPlayersProvider),
          ),
        );
      }

      return PrototypeScrollView(
        onRefresh: () => _refresh(groupId, playerId),
        child: const _DashboardEmptyState(),
      );
    }

    if (groupId.isEmpty) {
      return PrototypeScrollView(
        onRefresh: () => _refresh(groupId, playerId),
        child: const _DashboardEmptyState(),
      );
    }

    final profile = ref.watch(myProfileProvider).valueOrNull;
    final profileUsername = profile?.userName.trim() ?? '';
    final accountUsername = account?.email.split('@').first.trim() ?? '';
    final username = (profileUsername.isNotEmpty
            ? profileUsername
            : accountUsername.isNotEmpty
                ? accountUsername
                : activePlayer.playerName)
        .replaceFirst(RegExp(r'^@+'), '')
        .toLowerCase();

    final historyAsync = ref.watch(
      player_history.playerHistoryProvider(
        (
          groupId: groupId,
          playerId: activePlayer.playerId,
          // Sem ano: o card mostra o total da carreira e precisa da
          // primeira temporada, que só aparece no histórico completo.
          year: null,
        ),
      ),
    );
    final matchesAsync = ref.watch(upcomingMatchesFullProvider(groupId));
    final paymentAsync = ref.watch(myPaymentSummaryProvider(groupId));
    final pollsAsync = ref.watch(pendingPollsCountProvider(groupId));
    final eventsAsync = ref.watch(upcomingEventsProvider(groupId));
    final registeredEventsAsync = ref.watch(pollsListProvider(groupId));

    final summary = historyAsync.valueOrNull == null
        ? null
        : PlayerHistorySummary.from(historyAsync.valueOrNull!);
    final nextMatch = matchesAsync.valueOrNull?.firstOrNull;
    final pendingPayments = paymentAsync.valueOrNull == null
        ? null
        : paymentAsync.valueOrNull!.pendingMonthlyCount +
            paymentAsync.valueOrNull!.pendingExtraCount;

    return PrototypeScrollView(
      onRefresh: () => _refresh(groupId, activePlayer.playerId),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerIdentityCard(
            groupId: groupId,
            groupName: activePlayer.groupName,
            playerName: activePlayer.playerName,
            username: username,
            isGoalkeeper: activePlayer.isGoalkeeper,
            summary: summary,
            loading: historyAsync.isLoading,
            onOpen: () => context.go('/app/player-history'),
          ),
          const SizedBox(height: 12),
          _NextMatchBand(
            match: nextMatch,
            loading: matchesAsync.isLoading,
            error: matchesAsync.hasError,
            playerId: activePlayer.playerId,
            responding: nextMatch != null &&
                _respondingMatches.contains(nextMatch.header.matchId),
            onAccept: nextMatch == null
                ? null
                : () => _respondToMatch(
                      match: nextMatch,
                      playerId: activePlayer.playerId,
                      accept: true,
                    ),
            onDecline: nextMatch == null
                ? null
                : () => _respondToMatch(
                      match: nextMatch,
                      playerId: activePlayer.playerId,
                      accept: false,
                    ),
            onOpen: () => context.go(
              nextMatch == null
                  ? '/app/matches'
                  : '/app/matches?matchId=${nextMatch.header.matchId}',
            ),
          ),
          const SizedBox(height: 12),
          _ActionGrid(
            pendingPayments: pendingPayments,
            pendingPolls: pollsAsync.valueOrNull,
            registeredEvents: registeredEventsAsync.valueOrNull
                ?.where((poll) => poll.isEvent && poll.isOpen)
                .length,
            upcomingEvents: eventsAsync.valueOrNull?.length,
            onPayments: () => context.go('/app/payments'),
            onPolls: () => context.go('/app/polls/votes'),
            onEvents: () => context.go('/app/polls/events'),
            onCalendar: () => context.go('/app/calendar'),
            onStats: () => context.go('/app/visual-stats'),
          ),
          const SizedBox(height: 12),
          _UpcomingEventsCard(
            events: eventsAsync.valueOrNull ?? const [],
            loading: eventsAsync.isLoading,
            error: eventsAsync.hasError,
            onOpenCalendar: () => context.go('/app/calendar'),
          ),
          const SizedBox(height: 12),
          PrototypeCard(
            onTap: () => context.go('/app/matches'),
            child: Row(
              children: [
                const PrototypeIconBox(
                  icon: Icon(Icons.sports_soccer_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acompanhar partidas',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aceitação, formação, jogo e pós-jogo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerIdentityCard extends ConsumerWidget {
  final String groupId;
  final String groupName;
  final String playerName;
  final String username;
  final bool isGoalkeeper;
  final PlayerHistorySummary? summary;
  final bool loading;
  final VoidCallback onOpen;

  const _PlayerIdentityCard({
    required this.groupId,
    required this.groupName,
    required this.playerName,
    required this.username,
    required this.isGoalkeeper,
    required this.summary,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(groupSettingsProvider(groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // O protótipo troca este card no tema claro:
    //   [data-theme="white"] .proto-player-identity:not(.share-view){
    //     background:var(--bg-card); color:var(--text-primary); ... }
    // Aqui a cor era fixa (#12151C), então o card ficava escuro sobre fundo
    // branco — a única peça escura no meio de uma tela clara.
    final cardColor = isDark ? AppColors.darkSubtle : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkElevated : AppColors.lightBorder;
    final nameColor = isDark ? AppColors.onDark : AppColors.lightText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: cardBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadow20 : AppColors.shadow08,
            blurRadius: isDark ? 30 : 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 82,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.darkSubtle : AppColors.lightSubtle,
                      border: Border.all(
                          color: AppColors.accentOf(theme.brightness)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: renderGroupIcon(
                      isGoalkeeper ? icons.goalkeeper : icons.player,
                      size: 34,
                      color: AppColors.darkTextMuted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isGoalkeeper ? 'GOLEIRO' : 'JOGADOR',
                    style: const TextStyle(
                      color: AppColors.darkTextMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConfiguredPlayerName(
                          groupId: groupId,
                          name: playerName,
                          isGoalkeeper: isGoalkeeper,
                          iconSize: 16,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            // O fundo estava fixo num marrom escuro enquanto a
                            // cor do texto seguia o tema. No tema claro dava
                            // #96390F sobre #341B0E — 2.2:1, escuro sobre
                            // escuro. `accentBgOf` é o par desenhado para
                            // `accentTextOf`: 6.3:1 no claro, 7.8:1 no escuro.
                            color: AppColors.accentBgOf(theme.brightness),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          // Protótipo: "3ª temporada". A contagem sai da
                          // primeira partida disputada — não existe data de
                          // entrada na patota, e a primeira partida é na
                          // prática quando a pessoa começou.
                          child: Text(
                            '${summary?.seasonNumber ?? 1}ª temporada',
                            style: TextStyle(
                              color: AppColors.accentTextOf(theme.brightness),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '@',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: username),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // No protótipo o destaque é o PRIMEIRO stat (gols), não o MVP —
              // `PLAYER_CARD_STATS[0].featured`. Gol é o número que a pessoa
              // procura primeiro; MVP costuma ser 0 e destacar um zero é ruim.
              Expanded(
                child: _PlayerStat(
                  icon: renderGroupIcon(icons.goal, size: 19),
                  value: summary?.totalGoals,
                  label: 'gols',
                  loading: loading,
                  featured: true,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PlayerStat(
                  icon: renderGroupIcon(icons.assist, size: 19),
                  value: summary?.totalAssists,
                  label: 'assist.',
                  loading: loading,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PlayerStat(
                  icon: renderGroupIcon(icons.mvp, size: 19),
                  value: summary?.totalMvps,
                  label: 'MVP',
                  loading: loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onOpen,
              child: const Text('Ver meu histórico'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerStat extends StatelessWidget {
  final Widget icon;
  final int? value;
  final String label;
  final bool loading;
  final bool featured;

  const _PlayerStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.loading,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    // Acompanha o tema, igual ao `.proto-player-stat` do protótipo, que ganha
    // override em [data-theme="white"]. Antes ficava escuro sobre card claro.
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final background = featured
        ? AppColors.accentBgOf(brightness)
        : (isDark ? AppColors.darkCard : AppColors.lightSubtle);
    final iconColor = featured
        ? AppColors.accentTextOf(brightness)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final valueColor = isDark ? AppColors.onDark : AppColors.lightText;
    final labelColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(color: iconColor),
            child: icon,
          ),
          const SizedBox(height: 5),
          Text(
            loading ? '—' : '${value ?? 0}',
            style: TextStyle(
              color: featured ? AppColors.accentTextOf(brightness) : valueColor,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            // .proto-player-stat span — 10px é o piso do protótipo aqui, mas
            // 11 é o mínimo legível que adotamos no textTheme.
            style: TextStyle(color: labelColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NextMatchBand extends StatefulWidget {
  final UpcomingMatchDetails? match;
  final bool loading;
  final bool error;
  final String playerId;
  final bool responding;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onOpen;

  const _NextMatchBand({
    required this.match,
    required this.loading,
    required this.error,
    required this.playerId,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  @override
  State<_NextMatchBand> createState() => _NextMatchBandState();
}

class _NextMatchBandState extends State<_NextMatchBand> {
  /// Começa fechado: o card mora no topo do dashboard e um campo aberto por
  /// padrão empurraria todo o resto para fora da tela.
  bool _showTeams = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final loading = widget.loading;
    final playerId = widget.playerId;
    final responding = widget.responding;
    final onAccept = widget.onAccept;
    final onDecline = widget.onDecline;
    final onOpen = widget.onOpen;
    if (loading) {
      return const PrototypeHeaderBand(
        child: SizedBox(
          height: 126,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      );
    }

    if (match == null) {
      return PrototypeHeaderBand(
        child: InkWell(
          onTap: onOpen,
          child: SizedBox(
            height: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'AGENDA DA PATOTA',
                  style: TextStyle(
                    color: AppColors.primaryHover,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.error
                      ? 'Não foi possível carregar'
                      : 'Nenhuma partida agendada',
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toque para abrir Partidas',
                  style: TextStyle(
                      color: AppColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final header = match!.header;
    final player = match!.findPlayer(playerId);
    final response = player?.inviteResponse;
    final step = header.step;
    final canRespond = step == MatchStep.create || step == MatchStep.accept;

    // `team`: 0 = sem time, 1 = A, 2 = B.
    // Usa `match!` e não o promovido: a promoção de tipo não atravessa o corpo
    // de uma função local de forma confiável.
    List<PitchPlayer> squad(int team) => match!.allPlayers
        .where((p) => p.team == team)
        .map((p) =>
            PitchPlayer(name: p.playerName, isGoalkeeper: p.isGoalkeeper))
        .toList();
    final teamA = squad(1);
    final teamB = squad(2);
    final teamsInFormation = step == MatchStep.teams &&
        teamA.isEmpty &&
        teamB.isEmpty &&
        match!.teamAColor == null &&
        match!.teamBColor == null;
    final date = DateFormat('EEE, dd/MM', 'pt_BR').format(header.playedAt);
    final time = DateFormat('HH:mm').format(header.playedAt);

    return PrototypeHeaderBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            // O protótipo usa `.proto-between`, que é align-items:center — o
            // número do dia fica centrado contra o bloco inteiro, não colado no
            // topo junto da eyebrow.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HOJE NA PATOTA',
                        style: TextStyle(
                          color: AppColors.primaryHover,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Próxima pelada',
                        style: TextStyle(
                          color: AppColors.onDark,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$date · $time · ${header.placeName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      // Evento/votação vinculado. Os dados nunca deixaram de
                      // ser carregados pelo provider — só a exibição saiu na
                      // repaginação do card.
                      if (match!.linkedEventTitle != null)
                        _LinkedEventLine(match: match!),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // O canto acompanha a etapa. Antes era só o dia do mês, que a
                // linha acima já informa por extenso.
                //
                // Na aceitação o que importa é quem topou. Depois dela a
                // pergunta muda para os times — insistir nos confirmados vira
                // informação morta, já que ninguém mais responde.
                if (canRespond)
                  _InviteTally(
                    accepted: match!.acceptedCount,
                    pending: match!.pendingCount,
                    refused: match!.refusedCount,
                  )
                else
                  _TeamsSummary(
                    match: match!,
                    teamsInFormation: teamsInFormation,
                    isLive: step == MatchStep.playing,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (canRespond)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: responding ? null : onAccept,
                    icon: responding
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      response == InviteResponse.accepted
                          ? 'Presença confirmada'
                          : 'Confirmar presença',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // O protótipo dá menos peso ao "Não vou": grid 2.3fr / .85fr.
                // Confirmar é a ação principal e ocupa quase o triplo.
                Expanded(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: OutlinedButton(
                      onPressed: responding ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        // No tema claro o protótipo troca este botão para o
                        // fundo do card — sobre a faixa escura ele fica claro:
                        //   [data-theme="white"] .proto-presence-decline{
                        //     background:var(--bg-card); color:var(--text-secondary) }
                        foregroundColor: response == InviteResponse.declined
                            ? AppColors.dangerOf(Theme.of(context).brightness)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        backgroundColor: response == InviteResponse.declined
                            ? AppColors.dangerBgOf(Theme.of(context).brightness)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSubtle
                                : AppColors.lightCard),
                      ),
                      child: const Text('Não vou'),
                    ),
                  ),
                ),
              ],
            ),
          // Depois da aceitação não há botão de abrir: o cabeçalho do card já
          // é tocável e leva para a partida, então o botão só repetia a ação
          // ocupando uma faixa inteira.

          // Escalação. Só aparece quando há times montados — antes disso o
          // botão abriria um campo sem nada para mostrar. Fica atrás de um
          // toque porque o card abre o dashboard: expandido por padrão,
          // empurraria todo o resto para fora da tela.
          if (!canRespond && (teamA.isNotEmpty || teamB.isNotEmpty)) ...[
            const SizedBox(height: 4),
            _TeamsExpander(
              expanded: _showTeams,
              onToggle: () => setState(() => _showTeams = !_showTeams),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: MatchPitch(
                  teamA: teamA,
                  teamB: teamB,
                  teamAColor: match.teamAColor?.color ?? AppColors.teamBlue,
                  teamBColor:
                      match.teamBColor?.color ?? AppColors.prototypeDanger,
                  teamALabel: match.teamAColor?.name ?? 'Time A',
                  teamBLabel: match.teamBColor?.name ?? 'Time B',
                  // Deitado: dentro do card a largura sobra e a altura é cara.
                  horizontal: true,
                ),
              ),
              crossFadeState: _showTeams
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra de toque que abre e fecha a escalação.
class _TeamsExpander extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _TeamsExpander({
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Ocultar escalação' : 'Ver escalação';

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.darkTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumo dos times no canto do card, depois que a aceitação fecha.
///
/// Mostra as duas cores escolhidas e quantos jogadores há para dividir. As
/// cores costumam ser definidas antes da escalação, então já dão sinal de que
/// a partida avançou mesmo sem times montados.
class _TeamsSummary extends StatelessWidget {
  final UpcomingMatchDetails match;
  final bool teamsInFormation;
  final bool isLive;

  const _TeamsSummary({
    required this.match,
    required this.teamsInFormation,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final a = match.teamAColor;
    final b = match.teamBColor;
    final total = match.acceptedCount;

    if (isLive) {
      return _LiveMatchIndicator(
        teamAGoals: match.header.teamAGoals ?? 0,
        teamBGoals: match.header.teamBGoals ?? 0,
      );
    }

    if (match.header.step == MatchStep.ended &&
        match.header.teamAGoals != null &&
        match.header.teamBGoals != null) {
      return _FinishedMatchScore(
        teamAGoals: match.header.teamAGoals!,
        teamBGoals: match.header.teamBGoals!,
      );
    }

    if (match.header.step == MatchStep.post) {
      return const _PostMatchIndicator();
    }

    if (teamsInFormation) {
      return Semantics(
        label: 'Times em formação',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded,
                    size: 15, color: AppColors.primaryHover),
                SizedBox(width: 5),
                Text(
                  'Times',
                  style: TextStyle(
                    color: AppColors.onDark,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3),
            Text(
              'em formação',
              style: TextStyle(
                color: AppColors.primaryHover,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (a != null || b != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a != null) _ColorDot(color: a.color, label: a.name),
              if (a != null && b != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('×',
                      style: TextStyle(
                          color: AppColors.darkTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              if (b != null) _ColorDot(color: b.color, label: b.name),
            ],
          ),
        const SizedBox(height: 5),
        Semantics(
          label: '$total jogadores',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded,
                  size: 14, color: AppColors.darkTextMuted),
              const SizedBox(width: 5),
              Text(
                '$total',
                style: const TextStyle(
                  color: AppColors.onDark,
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveMatchIndicator extends StatefulWidget {
  final int teamAGoals;
  final int teamBGoals;

  const _LiveMatchIndicator({
    required this.teamAGoals,
    required this.teamBGoals,
  });

  @override
  State<_LiveMatchIndicator> createState() => _LiveMatchIndicatorState();
}

class _LiveMatchIndicatorState extends State<_LiveMatchIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Partida ao vivo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity:
                    Tween<double>(begin: .35, end: 1).animate(_pulseController),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.prototypeDanger,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'AO VIVO',
                style: TextStyle(
                  color: AppColors.prototypeDanger,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.teamAGoals} × ${widget.teamBGoals}',
            style: TextStyle(
              color: AppColors.onDark,
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedMatchScore extends StatelessWidget {
  final int teamAGoals;
  final int teamBGoals;

  const _FinishedMatchScore({
    required this.teamAGoals,
    required this.teamBGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Placar final: $teamAGoals a $teamBGoals',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'FINAL',
            style: TextStyle(
              color: AppColors.darkTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$teamAGoals × $teamBGoals',
            style: const TextStyle(
              color: AppColors.onDark,
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMatchIndicator extends StatelessWidget {
  const _PostMatchIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pós-jogo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined,
                  size: 14, color: AppColors.warning),
              SizedBox(width: 5),
              Text(
                'PÓS-JOGO',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    // O nome da cor vai só no rótulo acessível: no espaço do canto ele não
    // caberia sem espremer o resto.
    return Semantics(
      label: label,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.onDark.withValues(alpha: .5)),
        ),
      ),
    );
  }
}

/// Evento ou votação vinculado à partida, numa linha discreta abaixo da data.
///
/// Fica em tom apagado de propósito: é contexto, não chamada para ação. O card
/// já tem dois botões disputando atenção e a contagem no canto — mais um
/// elemento com peso brigaria com eles.
class _LinkedEventLine extends StatelessWidget {
  final UpcomingMatchDetails match;

  const _LinkedEventLine({required this.match});

  @override
  Widget build(BuildContext context) {
    final icon = match.linkedEventIcon;
    final hasEmoji = icon != null && icon.isNotEmpty;
    final vote = match.myVoteText?.trim();
    final normalizedVote = vote?.toLowerCase();
    final didNotVote = vote == null || vote.isEmpty;
    final votedYes = normalizedVote == 'sim' || normalizedVote == 'yes';
    final votedNo = normalizedVote == 'não' ||
        normalizedVote == 'nao' ||
        normalizedVote == 'no';
    final votedMaybe = normalizedVote == 'talvez' || normalizedVote == 'maybe';
    final voteLabel = didNotVote
        ? 'Não votou'
        : votedYes
            ? 'Votou sim'
            : votedNo
                ? 'Votou não'
                : votedMaybe
                    ? 'Votou talvez'
                    : 'Votou: $vote';
    final voteColor = didNotVote
        ? AppColors.warning
        : votedYes
            ? AppColors.primaryHover
            : votedNo
                ? AppColors.prototypeDanger
                : votedMaybe
                    ? AppColors.warning
                    : AppColors.blue200;
    final voteSymbol = didNotVote
        ? '−'
        : votedYes
            ? '✓'
            : votedNo
                ? '×'
                : votedMaybe
                    ? '?'
                    : '•';

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          if (hasEmoji)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text(icon, style: const TextStyle(fontSize: 11)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(
                match.linkedIsEvent
                    ? Icons.event_rounded
                    : Icons.how_to_vote_rounded,
                size: 12,
                color: AppColors.darkTextMuted,
              ),
            ),
          Flexible(
            child: Text(
              match.linkedEventTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Você:',
            style: TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Semantics(
            label: voteLabel,
            child: SizedBox(
              width: 16,
              height: 16,
              child: Center(
                child: Text(
                  voteSymbol,
                  style: TextStyle(
                    color: voteColor,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmados / pendentes / recusados, empilhados no canto do card da próxima
/// pelada. Ocupa o lugar onde antes ficava o dia do mês.
///
/// Some as linhas zeradas em vez de mostrar "0": depois que a aceitação fecha,
/// `pendingCount` é sempre 0 por definição, e um zero fixo ali só vira ruído.
/// Confirmados aparece sempre — é o número que dá sentido ao card.
class _InviteTally extends StatelessWidget {
  final int accepted;
  final int pending;
  final int refused;

  const _InviteTally({
    required this.accepted,
    required this.pending,
    required this.refused,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _TallyRow(
          icon: Icons.check_circle_rounded,
          count: accepted,
          color: AppColors.emerald500,
          semantic: 'confirmados',
        ),
        if (pending > 0) ...[
          const SizedBox(height: 5),
          _TallyRow(
            icon: Icons.schedule_rounded,
            count: pending,
            color: AppColors.warning,
            semantic: 'pendentes',
          ),
        ],
        if (refused > 0) ...[
          const SizedBox(height: 5),
          _TallyRow(
            icon: Icons.cancel_rounded,
            count: refused,
            color: AppColors.rose400,
            semantic: 'recusados',
          ),
        ],
      ],
    );
  }
}

class _TallyRow extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final String semantic;

  const _TallyRow({
    required this.icon,
    required this.count,
    required this.color,
    required this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $semantic',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          // Largura fixa para os números alinharem à direita entre si — sem
          // isso, um "11" empurra a linha e as três ficam desencontradas.
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.onDark,
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final int? pendingPayments;
  final int? pendingPolls;
  final int? registeredEvents;
  final int? upcomingEvents;
  final VoidCallback onPayments;
  final VoidCallback onPolls;
  final VoidCallback onEvents;
  final VoidCallback onCalendar;
  final VoidCallback onStats;

  const _ActionGrid({
    required this.pendingPayments,
    required this.pendingPolls,
    required this.registeredEvents,
    required this.upcomingEvents,
    required this.onPayments,
    required this.onPolls,
    required this.onEvents,
    required this.onCalendar,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.account_balance_wallet_outlined,
        'Pagamentos',
        pendingPayments == null
            ? 'Carregando'
            : pendingPayments == 0
                ? 'Tudo em dia'
                : '$pendingPayments pendência${pendingPayments == 1 ? '' : 's'}',
        onPayments,
      ),
      (
        Icons.calendar_today_outlined,
        'Eventos',
        registeredEvents == null
            ? 'Carregando'
            : registeredEvents == 0
                ? 'Nenhum cadastrado'
                : '$registeredEvents cadastrado${registeredEvents == 1 ? '' : 's'}',
        onEvents,
      ),
      (
        Icons.how_to_vote_outlined,
        'Votações',
        pendingPolls == null
            ? 'Carregando'
            : pendingPolls == 0
                ? 'Nenhuma pendente'
                : '$pendingPolls para responder',
        onPolls,
      ),
      (
        Icons.calendar_month_outlined,
        'Calendário',
        upcomingEvents == null
            ? 'Carregando'
            : '$upcomingEvents próximo${upcomingEvents == 1 ? '' : 's'}',
        onCalendar,
      ),
      (
        Icons.bar_chart_outlined,
        'Estatísticas',
        'Temporada ${DateTime.now().year}',
        onStats,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 9.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: PrototypeCard(
                  onTap: item.$4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.$1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(item.$2,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  final List<CalendarEvent> events;
  final bool loading;
  final bool error;
  final VoidCallback onOpenCalendar;

  const _UpcomingEventsCard({
    required this.events,
    required this.loading,
    required this.error,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return PrototypeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrototypeSectionTitle(
            title: 'Próximos eventos',
            count: loading ? '—' : '${events.length}',
            actionLabel: 'Calendário',
            onAction: onOpenCalendar,
          ),
          const SizedBox(height: 10),
          if (loading)
            const SizedBox(
              height: 86,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (events.isEmpty)
            SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  error
                      ? 'Não foi possível carregar os eventos.'
                      : 'Nenhum evento próximo.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _EventTile(
                    event: event,
                    onTap: onOpenCalendar,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    try {
      date = DateTime.parse(event.date);
    } catch (_) {}
    final day = date == null ? '--' : DateFormat('dd').format(date);
    final month =
        date == null ? '---' : DateFormat('MMM', 'pt_BR').format(date);

    return SizedBox(
      width: 210,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        month.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.timeTBD
                            ? 'Horário a definir'
                            : event.time ?? event.categoryName ?? 'Evento',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const PrototypeIconBox(
            size: 52,
            icon: Icon(Icons.groups_outlined, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhuma patota ativa',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Crie uma patota ou aceite um convite para começar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 96),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
          Text('Carregando sua patota...'),
        ],
      ),
    );
  }
}

class _DashboardLoadErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardLoadErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _DashboardMessageState(
      icon: Icons.cloud_off_outlined,
      title: 'Não foi possível carregar sua patota',
      message: 'Verifique sua conexão e tente novamente.',
      onRetry: onRetry,
    );
  }
}

class _DashboardPlayerMissingState extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardPlayerMissingState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _DashboardMessageState(
      icon: Icons.person_search_outlined,
      title: 'Patota encontrada',
      message: 'Não encontramos o jogador vinculado à sua conta.',
      onRetry: onRetry,
    );
  }
}

class _DashboardMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _DashboardMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          PrototypeIconBox(
            size: 52,
            icon: Icon(icon, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
