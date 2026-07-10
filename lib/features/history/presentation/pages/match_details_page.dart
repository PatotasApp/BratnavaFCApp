import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../replays/domain/entities/replay_clip.dart';
import '../../../replays/presentation/pages/replay_video_player_page.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../matches/presentation/providers/match_provider.dart';
import '../../domain/entities/match_details.dart';
import '../providers/history_provider.dart';

class MatchDetailsPage extends ConsumerStatefulWidget {
  final String groupId;
  final String matchId;

  const MatchDetailsPage({
    super.key,
    required this.groupId,
    required this.matchId,
  });

  @override
  ConsumerState<MatchDetailsPage> createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends ConsumerState<MatchDetailsPage> {
  // 0 = Todos, 1 = Time A, 2 = Time B
  int _goalsTab = 0;
  List<ReplayClip> _replays = [];
  bool _sharingCard = false;
  final Set<String> _togglingNoShow = {};

  Future<void> _showGoalSheet(MatchDetails data, {MatchGoal? editing}) async {
    final allPlayers = [...data.teamAPlayers, ...data.teamBPlayers]
        .where((p) => p.playerId != null && p.playerId!.isNotEmpty)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GoalFormSheet(
        players: allPlayers,
        editing: editing,
        onSave: (scorerId, assistId, time, isOwnGoal) async {
          final ds = ref.read(matchDsProvider);
          if (editing != null) {
            await ds.updateGoal(
              widget.groupId,
              widget.matchId,
              editing.goalId,
              {
                'scorerPlayerId': scorerId,
                if (assistId != null && assistId.isNotEmpty)
                  'assistPlayerId': assistId,
                'time': time,
                'isOwnGoal': isOwnGoal,
              },
            );
          } else {
            await ds.addGoal(
              widget.groupId,
              widget.matchId,
              scorerPlayerId: scorerId,
              assistPlayerId: assistId?.isNotEmpty == true ? assistId : null,
              time: time,
              isOwnGoal: isOwnGoal,
            );
          }
          ref.invalidate(matchDetailsProvider(
              (groupId: widget.groupId, matchId: widget.matchId)));
        },
      ),
    );
  }

  Future<void> _deleteGoal(MatchGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover gol'),
        content: Text('Remover o gol de ${goal.scorerName ?? "?"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose500),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(matchDsProvider)
          .removeGoal(widget.groupId, widget.matchId, goal.goalId);
      if (mounted) {
        ref.invalidate(matchDetailsProvider(
            (groupId: widget.groupId, matchId: widget.matchId)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractDioError(e, 'Erro ao remover gol')),
          backgroundColor: AppColors.rose500,
        ));
      }
    }
  }

  Future<void> _toggleNoShow(
      String matchPlayerId, bool currentDidNotPlay) async {
    if (_togglingNoShow.contains(matchPlayerId)) return;
    setState(() => _togglingNoShow.add(matchPlayerId));
    try {
      final ds = ref.read(matchDsProvider);
      await ds.setNoShow(
          widget.groupId, widget.matchId, matchPlayerId, !currentDidNotPlay);
      if (mounted) {
        ref.invalidate(matchDetailsProvider(
            (groupId: widget.groupId, matchId: widget.matchId)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractDioError(e, 'Erro ao atualizar presença')),
          backgroundColor: AppColors.rose500,
        ));
      }
    } finally {
      if (mounted) setState(() => _togglingNoShow.remove(matchPlayerId));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReplays();
  }

  Future<void> _loadReplays() async {
    try {
      final ds = ref.read(historyDsProvider);
      final replays = await ds.fetchMatchReplays(
        widget.groupId,
        widget.matchId,
      );
      if (mounted) setState(() => _replays = replays);
    } catch (_) {
      // Silently ignore — replays section is hidden when empty
    }
  }

  Future<void> _shareMatchCard() async {
    setState(() => _sharingCard = true);
    try {
      final ds = ref.read(historyDsProvider);
      await ds.generateMatchCard(
        widget.groupId,
        {'matchId': widget.matchId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card gerado! Você pode salvá-lo ou compartilhá-lo'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(extractDioError(e, 'Não foi possível gerar o card'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingCard = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final isAdmin = account != null && account.isGroupAdmin(widget.groupId);
    final accessToken = account?.accessToken;
    final async = ref.watch(matchDetailsProvider(
      (groupId: widget.groupId, matchId: widget.matchId),
    ));
    final settings =
        ref.watch(groupSettingsProvider(widget.groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);

    return async.when(
      loading: () => _LoadingSkeleton(isDark: isDark),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 40,
                  color: isDark ? AppColors.slate500 : AppColors.slate400),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar partida.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/app/history'),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
      data: (data) => _DetailsBody(
        data: data,
        isDark: isDark,
        isAdmin: isAdmin,
        canSeeStats: isAdmin || (settings?.showPlayerStats ?? false),
        goalsTab: _goalsTab,
        icons: icons,
        replays: _replays,
        groupId: widget.groupId,
        accessToken: accessToken,
        sharingCard: _sharingCard,
        onGoalsTab: (t) => setState(() => _goalsTab = t),
        onBack: () => context.go('/app/history'),
        onShare: _shareMatchCard,
        togglingNoShow: _togglingNoShow,
        onToggleNoShow: _toggleNoShow,
        onAddGoal: isAdmin ? () => _showGoalSheet(data) : null,
        onEditGoal:
            isAdmin ? (goal) => _showGoalSheet(data, editing: goal) : null,
        onDeleteGoal: isAdmin ? _deleteGoal : null,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DetailsBody extends StatelessWidget {
  final MatchDetails data;
  final bool isDark;
  final bool isAdmin;
  final bool canSeeStats;
  final int goalsTab;
  final void Function(int) onGoalsTab;
  final VoidCallback onBack;
  final GroupIcons icons;
  final List<ReplayClip> replays;
  final String groupId;
  final String? accessToken;
  final bool sharingCard;
  final VoidCallback onShare;
  final Set<String> togglingNoShow;
  final void Function(String, bool) onToggleNoShow;
  final VoidCallback? onAddGoal;
  final void Function(MatchGoal)? onEditGoal;
  final void Function(MatchGoal)? onDeleteGoal;

  const _DetailsBody({
    required this.data,
    required this.isDark,
    required this.isAdmin,
    required this.canSeeStats,
    required this.goalsTab,
    required this.onGoalsTab,
    required this.onBack,
    required this.icons,
    required this.replays,
    required this.groupId,
    required this.accessToken,
    required this.sharingCard,
    required this.onShare,
    this.togglingNoShow = const {},
    required this.onToggleNoShow,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
  });

  Color get aColor =>
      _hexColor(data.teamAColor?.hexValue) ?? const Color(0xFF0f172a);
  Color get bColor =>
      _hexColor(data.teamBColor?.hexValue) ?? const Color(0xFF0f172a);
  String get aName => data.teamAColor?.name ?? 'Time A';
  String get bName => data.teamBColor?.name ?? 'Time B';

  @override
  Widget build(BuildContext context) {
    // Build sorted goals with team info
    final byMatchPlayerId = <String, String>{};
    final byPlayerId = <String, String>{};
    for (final p in data.teamAPlayers) {
      byMatchPlayerId[p.matchPlayerId] = 'A';
      if (p.playerId != null) byPlayerId[p.playerId!] = 'A';
    }
    for (final p in data.teamBPlayers) {
      byMatchPlayerId[p.matchPlayerId] = 'B';
      if (p.playerId != null) byPlayerId[p.playerId!] = 'B';
    }

    final goals = data.goals.map((g) {
      final scorerTeam = (g.scorerMatchPlayerId != null
              ? byMatchPlayerId[g.scorerMatchPlayerId]
              : null) ??
          (g.scorerPlayerId != null ? byPlayerId[g.scorerPlayerId] : null) ??
          '?';
      final team = g.isOwnGoal
          ? (scorerTeam == 'A'
              ? 'B'
              : scorerTeam == 'B'
                  ? 'A'
                  : '?')
          : scorerTeam;
      return _GoalWithTeam(goal: g, team: team);
    }).toList();

    // Build goal events for simulation (enrich with tSec)
    final goalEvents = _buildGoalEvents(goals);

    // MVP
    final mvpPlayers = [
      ...data.teamAPlayers,
      ...data.teamBPlayers,
    ].where((p) => p.isMvp && !p.didNotPlay).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button + share icon
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: const Text('Voltar ao histórico'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sharingCard ? null : onShare,
                      tooltip: 'Compartilhar',
                      icon: sharingCard
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.share_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                    ),
                  ],
                ),
              ),

              // Hero score card
              _HeroCard(
                data: data,
                aColor: aColor,
                bColor: bColor,
                aName: aName,
                bName: bName,
                mvpPlayers: mvpPlayers,
                voteCounts: data.voteCounts,
                isDark: isDark,
                icons: icons,
              ),

              const SizedBox(height: 12),

              // Simulação minuto a minuto
              _SectionHeader(title: 'Simulação', isDark: isDark),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SimulationTimeline(
                  goalEvents: goalEvents,
                  aColor: aColor,
                  bColor: bColor,
                  aName: aName,
                  bName: bName,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 12),

              // Gols — visível apenas para admin ou quando showPlayerStats=true
              if (canSeeStats) ...[
                _SectionHeader(
                  title: 'Gols (${goals.length})',
                  isDark: isDark,
                ),
                _GoalsSection(
                  goals: goals,
                  tab: goalsTab,
                  onTab: onGoalsTab,
                  aColor: aColor,
                  bColor: bColor,
                  aName: aName,
                  bName: bName,
                  isDark: isDark,
                  icons: icons,
                  isAdmin: isAdmin,
                  onAddGoal: onAddGoal,
                  onEditGoal: onEditGoal,
                  onDeleteGoal: onDeleteGoal,
                ),
              ],

              const SizedBox(height: 12),

              // ── Jogadores ─────────────────────────────────────────
              _TeamCards(
                teamAPlayers: data.teamAPlayers,
                teamBPlayers: data.teamBPlayers,
                aColor: aColor,
                bColor: bColor,
                aName: aName,
                bName: bName,
                isDark: isDark,
                icons: icons,
                isAdmin: isAdmin,
                togglingNoShow: togglingNoShow,
                onToggleNoShow: onToggleNoShow,
              ),

              // Replays section (only when replays exist)
              if (replays.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ReplaysSection(
                  replays: replays,
                  groupId: groupId,
                  accessToken: accessToken,
                  isDark: isDark,
                ),
              ],

              if (mvpPlayers.isNotEmpty || data.voteCounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHeader(title: 'MVP', isDark: isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MvpResultSection(
                    mvpPlayers: mvpPlayers,
                    voteCounts: data.voteCounts,
                    isAdmin: isAdmin,
                    isDark: isDark,
                    icons: icons,
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final MatchDetails data;
  final Color aColor, bColor;
  final String aName, bName;
  final List<MatchPlayer> mvpPlayers;
  final List<MvpVoteResult> voteCounts;
  final bool isDark;
  final GroupIcons icons;

  const _HeroCard({
    required this.data,
    required this.aColor,
    required this.bColor,
    required this.aName,
    required this.bName,
    required this.mvpPlayers,
    required this.voteCounts,
    required this.isDark,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final playedStr = data.playedAt != null
        ? DateFormat("EEE, dd 'de' MMM 'de' yyyy • HH:mm", 'pt_BR')
            .format(data.playedAt!)
        : null;

    // Determina cor da borda: cor do vencedor ou split no empate
    final aGoals = data.teamAGoals ?? 0;
    final bGoals = data.teamBGoals ?? 0;
    final winColor = aGoals > bGoals
        ? aColor
        : bGoals > aGoals
            ? bColor
            : null;

    // Strips: vitória = toda a borda na cor do vencedor
    //         empate  = esquerda/topo-esquerdo/base-esquerdo em aColor,
    //                   direita/topo-direito/base-direito em bColor
    const double thickness = 4;

    Widget hStrip() => winColor != null
        ? Container(height: thickness, color: winColor)
        : Row(children: [
            Expanded(child: Container(height: thickness, color: aColor)),
            Expanded(child: Container(height: thickness, color: bColor)),
          ]);

    Widget vStrip(Color color) =>
        Container(width: thickness, color: winColor ?? color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.black.withValues(alpha: 0.25), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Lateral esquerda (Time A) ─────────────────────────
                vStrip(aColor),

                // ── Conteúdo central ──────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Top strip
                      hStrip(),

                      // Dark background body
                      Container(
                        color: const Color(0xFF0f172a),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Column(
                          children: [
                            // Team names row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      _ColorSwatch(color: aColor, size: 22),
                                      const SizedBox(height: 6),
                                      Text(
                                        aName.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: Color(0xFF94a3b8),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'vs',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _ColorSwatch(color: bColor, size: 22),
                                      const SizedBox(height: 6),
                                      Text(
                                        bName.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: Color(0xFF94a3b8),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Score
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${data.teamAGoals ?? '–'}',
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '×',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${data.teamBGoals ?? '–'}',
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Match info
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (data.placeName != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 12, color: Color(0xFF64748b)),
                                      const SizedBox(width: 4),
                                      Text(
                                        data.placeName!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748b),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (playedStr != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 12, color: Color(0xFF64748b)),
                                      const SizedBox(width: 4),
                                      Text(
                                        playedStr,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748b),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (data.statusName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(15),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                          color: Colors.white.withAlpha(25)),
                                    ),
                                    child: Text(
                                      data.statusName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFcbd5e1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            _HeroMvpBadge(
                              mvpPlayers: mvpPlayers,
                              voteCounts: voteCounts,
                              icons: icons,
                            ),
                          ],
                        ),
                      ),

                      // Bottom strip
                      hStrip(),
                    ],
                  ),
                ),

                // ── Lateral direita (Time B) ──────────────────────────
                vStrip(bColor),
              ],
            ),
          ),
        ), // ClipRRect
      ), // Container (outer border)
    );
  }
}

class _HeroMvpBadge extends StatelessWidget {
  final List<MatchPlayer> mvpPlayers;
  final List<MvpVoteResult> voteCounts;
  final GroupIcons icons;

  const _HeroMvpBadge({
    required this.mvpPlayers,
    required this.voteCounts,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final hasMvp = mvpPlayers.isNotEmpty;
    final topVotes = voteCounts.isEmpty ? 0 : voteCounts.first.votes;
    final topPlayers =
        voteCounts.where((v) => v.votes == topVotes && topVotes > 0).toList();
    final isVoteTie = !hasMvp && topPlayers.length > 1;
    final isLeading = !hasMvp && topPlayers.length == 1;

    if (!hasMvp && !isVoteTie && !isLeading) {
      return const SizedBox.shrink();
    }

    final text = hasMvp
        ? '${mvpPlayers.length > 1 ? 'MVPs' : 'MVP'}: ${mvpPlayers.map((p) => p.playerName).join(' & ')}'
        : isVoteTie
            ? 'Empate — sem MVP: ${topPlayers.map((p) => p.playerName).join(' & ')}'
            : 'Liderando: ${topPlayers.first.playerName}';
    final isTieWithoutMvp = !hasMvp && isVoteTie;
    final accent =
        isTieWithoutMvp ? const Color(0xFFfb923c) : const Color(0xFFfbbf24);
    final textColor =
        isTieWithoutMvp ? const Color(0xFFfdba74) : const Color(0xFFfde68a);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            renderGroupIcon(icons.mvp, size: 16, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MvpResultSection extends StatelessWidget {
  final List<MatchPlayer> mvpPlayers;
  final List<MvpVoteResult> voteCounts;
  final bool isAdmin;
  final bool isDark;
  final GroupIcons icons;

  const _MvpResultSection({
    required this.mvpPlayers,
    required this.voteCounts,
    required this.isAdmin,
    required this.isDark,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final hasMvp = mvpPlayers.isNotEmpty;
    final maxVotes = voteCounts.isEmpty ? 0 : voteCounts.first.votes;
    final topPlayers =
        voteCounts.where((v) => v.votes == maxVotes && maxVotes > 0).toList();
    final voteTie = !hasMvp && topPlayers.length > 1;
    final voteLeading = !hasMvp && topPlayers.length == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasMvp)
            _MvpMainResult(
              iconColor: const Color(0xFFf59e0b),
              bgColor: const Color(0xFFf59e0b).withValues(alpha: 0.10),
              borderColor: const Color(0xFFf59e0b).withValues(alpha: 0.24),
              title: mvpPlayers.length > 1 ? 'MVPs do jogo' : 'Melhor do jogo',
              names: mvpPlayers.map((p) => p.playerName).toList(),
              isDark: isDark,
              icons: icons,
            )
          else if (voteTie)
            _MvpMainResult(
              iconColor: const Color(0xFFf97316),
              bgColor: const Color(0xFFf97316).withValues(alpha: 0.10),
              borderColor: const Color(0xFFf97316).withValues(alpha: 0.24),
              title: 'Empate — nenhum MVP eleito',
              subtitle: 'Mais votados:',
              names: topPlayers.map((p) => p.playerName).toList(),
              isDark: isDark,
              icons: icons,
            )
          else if (voteLeading)
            _MvpMainResult(
              iconColor: const Color(0xFFf59e0b),
              bgColor: const Color(0xFFf59e0b).withValues(alpha: 0.08),
              borderColor: const Color(0xFFf59e0b).withValues(alpha: 0.18),
              title: 'Liderando a votação',
              names: [topPlayers.first.playerName],
              isDark: isDark,
              icons: icons,
            )
          else
            Text(
              'MVP não definido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          if (isAdmin && voteCounts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate950 : AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'APURAÇÃO DE VOTOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...voteCounts.map(
                    (vote) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _MvpVoteRow(
                        vote: vote,
                        maxVotes: maxVotes,
                        highlight: _isHighlightedVote(
                          vote,
                          mvpPlayers,
                          topPlayers,
                          hasMvp,
                          voteTie,
                          voteLeading,
                        ),
                        isTie: voteTie &&
                            topPlayers
                                .any((p) => p.playerName == vote.playerName),
                        isDark: isDark,
                        icons: icons,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isHighlightedVote(
    MvpVoteResult vote,
    List<MatchPlayer> mvpPlayers,
    List<MvpVoteResult> topPlayers,
    bool hasMvp,
    bool voteTie,
    bool voteLeading,
  ) {
    if (hasMvp) {
      return mvpPlayers.any((p) => p.playerName == vote.playerName);
    }
    if (voteTie || voteLeading) {
      return topPlayers.any((p) => p.playerName == vote.playerName);
    }
    return false;
  }
}

class _MvpMainResult extends StatelessWidget {
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final String? subtitle;
  final List<String> names;
  final bool isDark;
  final GroupIcons icons;

  const _MvpMainResult({
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    this.subtitle,
    required this.names,
    required this.isDark,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
              border: Border.all(color: iconColor.withValues(alpha: 0.28)),
            ),
            child: renderGroupIcon(icons.mvp, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: iconColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate300 : AppColors.slate600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: names
                      .map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MvpVoteRow extends StatelessWidget {
  final MvpVoteResult vote;
  final int maxVotes;
  final bool highlight;
  final bool isTie;
  final bool isDark;
  final GroupIcons icons;

  const _MvpVoteRow({
    required this.vote,
    required this.maxVotes,
    required this.highlight,
    required this.isTie,
    required this.isDark,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxVotes <= 0 ? 0.0 : vote.votes / maxVotes;
    final accent = isTie ? const Color(0xFFfb923c) : const Color(0xFFf59e0b);
    final barColor =
        highlight ? accent : (isDark ? AppColors.slate600 : AppColors.slate300);

    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Row(
            children: [
              if (highlight) ...[
                renderGroupIcon(icons.mvp, size: 12, color: accent),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  vote.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.slate100 : AppColors.slate800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.slate800 : AppColors.slate200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: Text(
            '${vote.votes}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.slate200 : AppColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Team cards ────────────────────────────────────────────────────────────────

class _TeamCards extends StatelessWidget {
  final List<MatchPlayer> teamAPlayers;
  final List<MatchPlayer> teamBPlayers;
  final Color aColor, bColor;
  final bool isAdmin;
  final Set<String> togglingNoShow;
  final void Function(String, bool) onToggleNoShow;
  final String aName, bName;
  final bool isDark;
  final GroupIcons icons;

  const _TeamCards({
    required this.teamAPlayers,
    required this.teamBPlayers,
    required this.aColor,
    required this.bColor,
    required this.aName,
    required this.bName,
    required this.isDark,
    required this.icons,
    this.isAdmin = false,
    this.togglingNoShow = const {},
    required this.onToggleNoShow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TeamCard(
              players: teamAPlayers,
              color: aColor,
              name: aName,
              isDark: isDark,
              icons: icons,
              isAdmin: isAdmin,
              togglingNoShow: togglingNoShow,
              onToggleNoShow: onToggleNoShow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TeamCard(
              players: teamBPlayers,
              color: bColor,
              name: bName,
              isDark: isDark,
              icons: icons,
              isAdmin: isAdmin,
              togglingNoShow: togglingNoShow,
              onToggleNoShow: onToggleNoShow,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final List<MatchPlayer> players;
  final Color color;
  final String name;
  final bool isDark;
  final GroupIcons icons;
  final bool isAdmin;
  final Set<String> togglingNoShow;
  final void Function(String, bool) onToggleNoShow;

  const _TeamCard({
    required this.players,
    required this.color,
    required this.name,
    required this.isDark,
    required this.icons,
    this.isAdmin = false,
    this.togglingNoShow = const {},
    required this.onToggleNoShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.slate800.withAlpha(120)
                  : AppColors.slate50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                ),
              ),
            ),
            child: Row(
              children: [
                _ColorSwatch(color: color, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _teamTextColor(color, isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${players.length} jog.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),

          // Players
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Nenhum jogador.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            )
          else
            ...players.map((p) {
              final absent = p.didNotPlay;
              final toggling = togglingNoShow.contains(p.matchPlayerId);
              final nameColor = absent
                  ? (isDark ? AppColors.slate600 : AppColors.slate400)
                  : (isDark ? AppColors.slate100 : AppColors.slate800);

              return Opacity(
                opacity: absent ? 0.55 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: absent
                              ? (isDark
                                  ? AppColors.slate700
                                  : AppColors.slate300)
                              : color,
                          width: 3),
                      bottom: BorderSide(
                        color: isDark ? AppColors.slate800 : AppColors.slate100,
                      ),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    children: [
                      if (p.isGoalkeeper) ...[
                        renderGroupIcon(
                          icons.goalkeeper,
                          size: 14,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          p.playerName,
                          style: TextStyle(
                            fontSize: 12,
                            color: nameColor,
                            decoration: absent
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: nameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge "não foi"
                      if (absent) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.rose500.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.rose500.withValues(alpha: .3)),
                          ),
                          child: const Text('não foi',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.rose500)),
                        ),
                      ],
                      if (p.isMvp) ...[
                        const SizedBox(width: 4),
                        renderGroupIcon(
                          icons.mvp,
                          size: 13,
                          color: const Color(0xFFfbbf24),
                        ),
                      ],
                      // Botão de toggle no-show (só admin)
                      if (isAdmin) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: toggling
                              ? const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5))
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: absent
                                      ? 'Desfazer: marcar como presente'
                                      : 'Marcar como não veio',
                                  icon: Icon(
                                    absent
                                        ? Icons.person_add_alt_1_rounded
                                        : Icons.person_remove_alt_1_rounded,
                                    size: 15,
                                    color: absent
                                        ? AppColors.emerald500
                                        : AppColors.rose400,
                                  ),
                                  onPressed: () =>
                                      onToggleNoShow(p.matchPlayerId, absent),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Goals section ─────────────────────────────────────────────────────────────

class _GoalWithTeam {
  final MatchGoal goal;
  final String team; // 'A' | 'B' | '?'
  const _GoalWithTeam({required this.goal, required this.team});
}

class _GoalsSection extends StatelessWidget {
  final List<_GoalWithTeam> goals;
  final int tab;
  final void Function(int) onTab;
  final Color aColor, bColor;
  final String aName, bName;
  final bool isDark;
  final GroupIcons icons;
  final bool isAdmin;
  final VoidCallback? onAddGoal;
  final void Function(MatchGoal)? onEditGoal;
  final void Function(MatchGoal)? onDeleteGoal;

  const _GoalsSection({
    required this.goals,
    required this.tab,
    required this.onTab,
    required this.aColor,
    required this.bColor,
    required this.aName,
    required this.bName,
    required this.isDark,
    required this.icons,
    this.isAdmin = false,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
  });

  List<_GoalWithTeam> get _filtered {
    if (tab == 1) return goals.where((g) => g.team == 'A').toList();
    if (tab == 2) return goals.where((g) => g.team == 'B').toList();
    return goals;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tabs + optional add button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TabBtn(
                              label: 'Todos',
                              active: tab == 0,
                              isDark: isDark,
                              onTap: () => onTab(0)),
                          const SizedBox(width: 6),
                          _TabBtn(
                              dotColor: aColor,
                              label: aName,
                              active: tab == 1,
                              isDark: isDark,
                              onTap: () => onTab(1)),
                          const SizedBox(width: 6),
                          _TabBtn(
                              dotColor: bColor,
                              label: bName,
                              active: tab == 2,
                              isDark: isDark,
                              onTap: () => onTab(2)),
                        ],
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      onPressed: onAddGoal,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      tooltip: 'Adicionar gol',
                      iconSize: 22,
                      color: isDark ? AppColors.slate300 : AppColors.slate600,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Nenhum gol registrado.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((g) => _GoalRow(
                    goalWithTeam: g,
                    aColor: aColor,
                    bColor: bColor,
                    isDark: isDark,
                    icons: icons,
                    isAdmin: isAdmin,
                    onEdit:
                        onEditGoal == null ? null : () => onEditGoal!(g.goal),
                    onDelete: onDeleteGoal == null
                        ? null
                        : () => onDeleteGoal!(g.goal),
                  )),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final _GoalWithTeam goalWithTeam;
  final Color aColor, bColor;
  final bool isDark;
  final GroupIcons icons;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GoalRow({
    required this.goalWithTeam,
    required this.aColor,
    required this.bColor,
    required this.isDark,
    required this.icons,
    this.isAdmin = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final g = goalWithTeam.goal;
    final team = goalWithTeam.team;
    final color = team == 'A'
        ? aColor
        : team == 'B'
            ? bColor
            : AppColors.slate400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
          ),
        ),
      ),
      child: Row(
        children: [
          // Team dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          // Scorer + assist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    renderGroupIcon(icons.goal, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        g.scorerName ?? '—',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (g.isOwnGoal)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfff7ed),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GC',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFea580c),
                          ),
                        ),
                      ),
                  ],
                ),
                if (g.assistName != null && g.assistName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        renderGroupIcon(
                          icons.assist,
                          size: 11,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            g.assistName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Time
          if (g.time != null)
            Text(
              g.time!,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          // Admin edit / delete
          if (isAdmin) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 15,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.rose500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final Color? dotColor;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.isDark,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? Colors.white : AppColors.slate900)
              : (isDark ? AppColors.slate900 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? (isDark ? Colors.white : AppColors.slate900)
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? (isDark ? AppColors.slate900 : Colors.white)
                    : (isDark ? AppColors.slate300 : AppColors.slate700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.slate900,
        ),
      ),
    );
  }
}

// ── Color swatch ──────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorSwatch({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final isWhite = color == const Color(0xFFFFFFFF);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isWhite ? AppColors.slate300 : Colors.white.withAlpha(80),
          width: 1,
        ),
      ),
    );
  }
}

// ── Replays section ───────────────────────────────────────────────────────────

// ── Replays section — strip horizontal compacta ───────────────────────────────
//
// Com até 60 clips por jogo, usar uma lista vertical de cards grandes seria
// inviável. A strip horizontal mantém a seção com altura fixa (≈130 px) e
// deixa o usuário fazer scroll lateral para ver todos os clips.

class _ReplaysSection extends StatefulWidget {
  final List<ReplayClip> replays;
  final String groupId;
  final String? accessToken;
  final bool isDark;

  const _ReplaysSection({
    required this.replays,
    required this.groupId,
    required this.accessToken,
    required this.isDark,
  });

  @override
  State<_ReplaysSection> createState() => _ReplaysSectionState();
}

enum _ReplayFilter { all, goals, plays }

class _ReplaysSectionState extends State<_ReplaysSection> {
  static const _pageSize = 12;
  _ReplayFilter _filter = _ReplayFilter.all;
  int _page = 1;

  bool _isGoalClip(ReplayClip clip) {
    final type = (clip.eventType ?? '').toLowerCase();
    return type.contains('gol') || type.contains('goal');
  }

  List<ReplayClip> get _filtered {
    return widget.replays.where((clip) {
      final isGoal = _isGoalClip(clip);
      return switch (_filter) {
        _ReplayFilter.all => true,
        _ReplayFilter.goals => isGoal,
        _ReplayFilter.plays => !isGoal,
      };
    }).toList();
  }

  int get _goalCount => widget.replays.where(_isGoalClip).length;
  int get _playCount => widget.replays.length - _goalCount;

  void _setFilter(_ReplayFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
    });
  }

  void _openPlayer(BuildContext context, ReplayClip clip) {
    final index = widget.replays.indexWhere((r) => r.clipId == clip.clipId);
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReplayVideoPlayerPage(
        clips: widget.replays,
        initialIndex: index < 0 ? 0 : index,
        groupId: widget.groupId,
        accessToken: widget.accessToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();
    final rangeStart = filtered.isEmpty ? 0 : start + 1;
    final rangeEnd = (start + pageItems.length).clamp(0, filtered.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Replays (${widget.replays.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ReplayFilterButton(
                    label: 'Todos',
                    count: widget.replays.length,
                    active: _filter == _ReplayFilter.all,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _ReplayFilterButton(
                    label: 'Gols',
                    count: _goalCount,
                    active: _filter == _ReplayFilter.goals,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.goals),
                  ),
                  const SizedBox(width: 8),
                  _ReplayFilterButton(
                    label: 'Jogadas',
                    count: _playCount,
                    active: _filter == _ReplayFilter.plays,
                    isDark: widget.isDark,
                    onTap: () => _setFilter(_ReplayFilter.plays),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nenhum replay encontrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        widget.isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in pageItems.indexed)
                        SizedBox(
                          width: itemWidth,
                          child: _ReplayTile(
                            clip: entry.$2,
                            index: start + entry.$1 + 1,
                            hasUrl: resolveClipUrl(
                                  entry.$2,
                                  widget.groupId,
                                  widget.accessToken,
                                ) !=
                                null,
                            videoUrl: resolveClipUrl(
                              entry.$2,
                              widget.groupId,
                              widget.accessToken,
                            ),
                            isDark: widget.isDark,
                            onTap: () => _openPlayer(context, entry.$2),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      safePage <= 1 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$rangeStart-$rangeEnd de ${filtered.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? AppColors.slate400
                          : AppColors.slate500,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: safePage >= totalPages
                      ? null
                      : () => setState(() => _page++),
                  label: const Text('Próxima'),
                  icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _ReplayFilterButton({
    required this.label,
    required this.count,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? Colors.white
        : (isDark ? AppColors.slate300 : AppColors.slate600);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.slate900
              : (isDark ? AppColors.slate800 : AppColors.slate50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.slate900
                : (isDark ? AppColors.slate700 : AppColors.slate100),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withAlpha(35)
                    : (isDark ? AppColors.slate700 : AppColors.slate100),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? Colors.white
                      : (isDark ? AppColors.slate300 : AppColors.slate500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayTile extends StatelessWidget {
  final ReplayClip clip;
  final int index;
  final bool hasUrl;
  final String? videoUrl;
  final bool isDark;
  final VoidCallback? onTap;

  const _ReplayTile({
    required this.clip,
    required this.index,
    required this.hasUrl,
    required this.videoUrl,
    required this.isDark,
    this.onTap,
  });

  bool get _isGoal {
    final t = clip.eventType?.toLowerCase() ?? '';
    return t.contains('gol') || t.contains('goal');
  }

  String get _label => _isGoal ? 'GOL' : 'JOGADA';

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        _isGoal ? const Color(0xFF10b981) : const Color(0xFF3b82f6);

    return AspectRatio(
      aspectRatio: 1.65,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasUrl ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(55),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF334155),
                          Color(0xFF1e293b),
                          Color(0xFF020617),
                        ],
                      ),
                    ),
                    child: CustomPaint(painter: _ReplayPitchPainter()),
                  ),
                  if (videoUrl != null) _ReplayVideoThumb(url: videoUrl!),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(18),
                          Colors.transparent,
                          Colors.black.withAlpha(210),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(hasUrl ? 52 : 24),
                        border: Border.all(
                          color: Colors.white.withAlpha(hasUrl ? 88 : 38),
                        ),
                      ),
                      child: Icon(
                        hasUrl
                            ? Icons.play_arrow_rounded
                            : Icons.videocam_off_rounded,
                        size: 25,
                        color: Colors.white.withAlpha(hasUrl ? 230 : 90),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _label,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Text(
                      '#$index',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 7,
                    child: Row(
                      children: [
                        Icon(
                          clip.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                        if (clip.likeCount > 0) ...[
                          const SizedBox(width: 2),
                          Text('${clip.likeCount}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white70)),
                        ],
                        const SizedBox(width: 7),
                        Icon(
                          clip.isFavorited
                              ? Icons.bookmark
                              : Icons.bookmark_border_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const Spacer(),
                        Text(
                          _timeLabel(clip),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const _MiniReplayIcon(icon: Icons.link_rounded),
                        const SizedBox(width: 5),
                        const _MiniReplayIcon(icon: Icons.download_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(ReplayClip clip) {
    if (clip.minute != null) return "${clip.minute}'";
    final date = AppDateUtils.parse(clip.createdAt);
    if (date == null) return '--:--';
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

class _MiniReplayIcon extends StatelessWidget {
  final IconData icon;
  const _MiniReplayIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(130),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 11, color: Colors.white70),
    );
  }
}

class _ReplayVideoThumb extends StatefulWidget {
  final String url;

  const _ReplayVideoThumb({required this.url});

  @override
  State<_ReplayVideoThumb> createState() => _ReplayVideoThumbState();
}

class _ReplayVideoThumbState extends State<_ReplayVideoThumb> {
  static const int _maxLiveControllers = 4;
  static int _liveControllers = 0;

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _reservedControllerSlot = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReplayVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _ready = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (_liveControllers >= _maxLiveControllers) return;
    _liveControllers++;
    _reservedControllerSlot = true;

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      final duration = controller.value.duration;
      final target = duration > const Duration(milliseconds: 700)
          ? const Duration(milliseconds: 500)
          : Duration.zero;
      await controller.seekTo(target);
      await controller.pause();
      if (mounted && identical(_controller, controller)) {
        setState(() => _ready = true);
      }
    } catch (_) {
      await controller.dispose();
      if (mounted && identical(_controller, controller)) {
        _controller = null;
      }
      _releaseControllerSlot();
    }
  }

  void _releaseControllerSlot() {
    if (!_reservedControllerSlot) return;
    _reservedControllerSlot = false;
    if (_liveControllers > 0) _liveControllers--;
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _releaseControllerSlot();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _ReplayPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = const Color(0xFF166534).withAlpha(110)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, fill);
    for (var i = 0; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, size.width / 8, size.height),
        Paint()
          ..color = Colors.white.withAlpha(i.isEven ? 12 : 5)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(6, 8, size.width - 12, size.height - 16),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, 8),
      Offset(size.width / 2, size.height - 8),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OldReplaysSection extends StatelessWidget {
  final List<ReplayClip> replays;
  final String groupId;
  final String? accessToken;
  final bool isDark;

  const OldReplaysSection({
    super.key,
    required this.replays,
    required this.groupId,
    required this.accessToken,
    required this.isDark,
  });

  void _openPlayer(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReplayVideoPlayerPage(
        clips: replays,
        initialIndex: index,
        groupId: groupId,
        accessToken: accessToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replays.length,
        itemBuilder: (ctx, i) {
          final clip = replays[i];
          final hasUrl = resolveClipUrl(clip, groupId, accessToken) != null;
          return _ReplayChip(
            clip: clip,
            index: i + 1,
            hasUrl: hasUrl,
            isDark: isDark,
            onTap: hasUrl ? () => _openPlayer(context, i) : null,
          );
        },
      ),
    );
  }
}

// ── Chip individual (card compacto para strip horizontal) ─────────────────────

class _ReplayChip extends StatelessWidget {
  final ReplayClip clip;
  final int index;
  final bool hasUrl;
  final bool isDark;
  final VoidCallback? onTap;

  const _ReplayChip({
    required this.clip,
    required this.index,
    required this.hasUrl,
    required this.isDark,
    this.onTap,
  });

  String get _eventIcon {
    final t = clip.eventType?.toLowerCase() ?? '';
    if (t.contains('gol') || t.contains('goal')) return '⚽';
    if (t.contains('defesa') || t.contains('save')) return '🧤';
    if (t.contains('falta') || t.contains('foul')) return '🟡';
    return '🎬';
  }

  String get _label {
    if (clip.scorerName?.isNotEmpty == true) return clip.scorerName!;
    if (clip.eventType?.isNotEmpty == true) return clip.eventType!;
    return 'Lance';
  }

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.slate700 : AppColors.slate200;
    final bg = isDark ? AppColors.slate800 : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 92,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Thumbnail area ─────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF0F172A)),

                        Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(hasUrl ? 28 : 14),
                              border: Border.all(
                                color: Colors.white.withAlpha(hasUrl ? 55 : 25),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              hasUrl
                                  ? Icons.play_arrow_rounded
                                  : Icons.videocam_off_rounded,
                              size: 20,
                              color: Colors.white.withAlpha(hasUrl ? 220 : 70),
                            ),
                          ),
                        ),

                        // Badge do índice
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('#$index',
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),

                        // Minuto (canto inferior direito)
                        if (clip.minute != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("${clip.minute}'",
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      color: Colors.white70)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Info area ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Row(
                    children: [
                      Text(_eventIcon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});

  Widget _box({double h = 20, double? w, double r = 8}) => Container(
        height: h,
        width: w,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _box(h: 8, w: 120),
          _box(h: 200, r: 16),
          _box(h: 140, r: 12),
          _box(h: 160, r: 12),
          Row(
            children: [
              Expanded(child: _box(h: 160, r: 12)),
              const SizedBox(width: 10),
              Expanded(child: _box(h: 160, r: 12)),
            ],
          ),
          _box(h: 140, r: 12),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color? _hexColor(String? hex) {
  if (hex == null) return null;
  try {
    final h = hex.replaceAll('#', '').trim();
    if (h.length == 3) {
      final r = h[0] * 2;
      final g = h[1] * 2;
      final b = h[2] * 2;
      return Color(int.parse('FF$r$g$b', radix: 16));
    }
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  } catch (_) {}
  return null;
}

bool _colorIsWhite(Color c) =>
    (c.r * 255).round() > 240 &&
    (c.g * 255).round() > 240 &&
    (c.b * 255).round() > 240;

Color _teamTextColor(Color bg, bool isDark) {
  final isWhite = _colorIsWhite(bg);
  if (isWhite) return isDark ? AppColors.slate900 : AppColors.slate700;
  return bg;
}

// ══════════════════════════════════════════════════════════════════════════════
// SIMULATION TIMELINE
// ══════════════════════════════════════════════════════════════════════════════

// ── Clock / math helpers ──────────────────────────────────────────────────────

class _Clock {
  final int h, m, s, minOfDay;
  const _Clock(
      {required this.h,
      required this.m,
      required this.s,
      required this.minOfDay});
}

_Clock? _parseClock(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final match =
      RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(raw.trim());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final mm = int.parse(match.group(2)!);
  final ss = match.group(3) != null ? int.parse(match.group(3)!) : 0;
  if (h < 0 || h > 23 || mm < 0 || mm > 59 || ss < 0 || ss > 59) return null;
  return _Clock(h: h, m: mm, s: ss, minOfDay: h * 60 + mm);
}

int _diffSecClock(_Clock goal, int startMinOfDay) {
  int diffMin = goal.minOfDay - startMinOfDay;
  if (diffMin < 0) diffMin += 1440;
  return diffMin * 60 + goal.s;
}

/// Infere o minuto do início do jogo (minOfDay) a partir dos horários dos gols.
///
/// Estratégia:
/// 1. Ancora no horário do gol mais cedo.
/// 2. Candidatos: hora cheia e meia-hora dentro de uma janela de até 60 min
///    antes do primeiro gol (máx 4 candidatos).
/// 3. Escolhe o candidato **mais cedo** em que **todos** os gols cabem
///    na faixa 0–3600 s — garante que gols do segundo tempo não "empurram"
///    o início para o meio da partida.
/// 4. Se nenhum candidato encaixa todos, escolhe o que encaixa mais gols.
int? _inferStart(List<String?> times) {
  final clocks = times.map(_parseClock).whereType<_Clock>().toList();
  if (clocks.isEmpty) return null;

  // Gol mais cedo como âncora.
  clocks.sort((a, b) => a.minOfDay.compareTo(b.minOfDay));
  final earliest = clocks.first;

  // Candidatos: hora cheia e meia-hora ≤ earliest e até 60 min antes.
  final candidates = <int>[];
  for (int offset = 0; offset <= 60; offset += 30) {
    int cand = earliest.minOfDay - offset;
    if (cand < 0) cand += 1440; // wrap midnight
    // Normalizar para hora cheia ou meia-hora mais próxima ≤ cand
    final atHour = (cand ~/ 60) * 60;
    final atHalf = atHour + 30;
    if (atHour <= earliest.minOfDay) candidates.add(atHour);
    if (atHalf <= earliest.minOfDay) candidates.add(atHalf);
  }
  // Remove duplicatas e ordena crescente (mais cedo primeiro).
  final sorted = candidates.toSet().toList()..sort();

  // Verifica quais candidatos encaixam TODOS os gols dentro de 0–3600 s.
  for (final start in sorted) {
    final allFit = clocks.every((c) {
      final d = _diffSecClock(c, start);
      return d >= 0 && d <= 3600;
    });
    if (allFit) return start;
  }

  // Fallback: candidato que encaixa o maior número de gols.
  int? bestStart;
  int bestCount = 0;
  for (final start in sorted) {
    final count = clocks.where((c) {
      final d = _diffSecClock(c, start);
      return d >= 0 && d <= 3600;
    }).length;
    if (count > bestCount) {
      bestCount = count;
      bestStart = start;
    }
  }
  return bestStart ?? earliest.h * 60;
}

// ── GoalEvent ─────────────────────────────────────────────────────────────────

class _GoalEvent {
  final _GoalWithTeam goalWithTeam;
  final int tSec; // seconds from game start, clamped 0..3600
  final int minute; // game minute

  const _GoalEvent(
      {required this.goalWithTeam, required this.tSec, required this.minute});
}

List<_GoalEvent> _buildGoalEvents(List<_GoalWithTeam> goals) {
  if (goals.isEmpty) return [];

  final times = goals.map((g) => g.goal.time).toList();
  final startMinOfDay = _inferStart(times);

  return goals.map((g) {
    final clock = _parseClock(g.goal.time);
    int tSec = 3600; // default: end of game if no time
    if (clock != null && startMinOfDay != null) {
      tSec = _diffSecClock(clock, startMinOfDay).clamp(0, 3600);
    }
    final minute = (tSec / 60).floor().clamp(0, 60);
    return _GoalEvent(goalWithTeam: g, tSec: tSec, minute: minute);
  }).toList()
    ..sort((a, b) => a.tSec.compareTo(b.tSec));
}

// ── _SimulationTimeline ────────────────────────────────────────────────────────

class _SimulationTimeline extends StatefulWidget {
  final List<_GoalEvent> goalEvents;
  final Color aColor, bColor;
  final String aName, bName;
  final bool isDark;

  const _SimulationTimeline({
    required this.goalEvents,
    required this.aColor,
    required this.bColor,
    required this.aName,
    required this.bName,
    required this.isDark,
  });

  @override
  State<_SimulationTimeline> createState() => _SimulationTimelineState();
}

class _SimulationTimelineState extends State<_SimulationTimeline>
    with SingleTickerProviderStateMixin {
  static const int _totalMinutes = 60;
  static const int _durationMs = 10000;

  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((_) => setState(() {}))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _simSec =>
      (_ctrl.value * _totalMinutes * 60).clamp(0, _totalMinutes * 60.0);
  int get _simMinute => (_simSec / 60).floor().clamp(0, _totalMinutes);
  double get _progress => _ctrl.value.clamp(0.0, 1.0);
  bool get _running => _ctrl.isAnimating;
  bool get _done => _ctrl.value >= 1.0;

  void _play() {
    if (_done) {
      _ctrl.reset();
    }
    _ctrl.forward();
  }

  void _pause() {
    _ctrl.stop();
  }

  void _restart() {
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final goalsA =
        widget.goalEvents.where((g) => g.goalWithTeam.team == 'A').toList();
    final goalsB =
        widget.goalEvents.where((g) => g.goalWithTeam.team == 'B').toList();

    final scoreA = goalsA.where((g) => g.tSec <= _simSec).length;
    final scoreB = goalsB.where((g) => g.tSec <= _simSec).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        children: [
          // Controls bar
          _buildControlsBar(isDark),

          // Score display
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScoreChip(
                  color: widget.aColor,
                  name: widget.aName,
                  score: scoreA,
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? AppColors.slate600 : AppColors.slate300,
                    ),
                  ),
                ),
                _ScoreChip(
                  color: widget.bColor,
                  name: widget.bName,
                  score: scoreB,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Timeline bars
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              children: [
                _TimelineBar(
                  teamName: widget.aName,
                  teamColor: widget.aColor,
                  goals: goalsA,
                  progress: _progress,
                  simSec: _simSec,
                  totalMinutes: _totalMinutes,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                _TimelineBar(
                  teamName: widget.bName,
                  teamColor: widget.bColor,
                  goals: goalsB,
                  progress: _progress,
                  simSec: _simSec,
                  totalMinutes: _totalMinutes,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800.withAlpha(120) : AppColors.slate50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
          ),
        ),
      ),
      child: Row(
        children: [
          // Minute counter
          SizedBox(
            width: 52,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$_simMinute'",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                  TextSpan(
                    text: '/$_totalMinutes',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? AppColors.slate600 : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overall progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: isDark ? AppColors.slate700 : AppColors.slate200,
                child: FractionallySizedBox(
                  widthFactor: _progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Restart
          _SimCtrlBtn(
            icon: Icons.replay_rounded,
            onTap: _restart,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          // Play
          _SimCtrlBtn(
            icon: Icons.play_arrow_rounded,
            onTap: _running ? null : _play,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          // Pause
          _SimCtrlBtn(
            icon: Icons.pause_rounded,
            onTap: _running ? _pause : null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ── Simulation control button (used only in timeline) ────────────────────────

class _SimCtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  const _SimCtrlBtn({required this.icon, this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1.0,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          child: Icon(icon,
              size: 16,
              color: isDark ? AppColors.slate300 : AppColors.slate600),
        ),
      ),
    );
  }
}

// ── Score chip ────────────────────────────────────────────────────────────────

class _ScoreChip extends StatelessWidget {
  final Color color;
  final String name;
  final int score;
  final bool isDark;

  const _ScoreChip({
    required this.color,
    required this.name,
    required this.score,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = _colorIsWhite(color);
    final labelColor =
        isWhite ? (isDark ? AppColors.slate300 : AppColors.slate600) : color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isWhite ? AppColors.slate300 : Colors.white.withAlpha(60),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Timeline bar ──────────────────────────────────────────────────────────────

class _TimelineBar extends StatelessWidget {
  final String teamName;
  final Color teamColor;
  final List<_GoalEvent> goals; // this team's goals only
  final double progress; // 0..1
  final double simSec; // current sim seconds
  final int totalMinutes;
  final bool isDark;

  const _TimelineBar({
    required this.teamName,
    required this.teamColor,
    required this.goals,
    required this.progress,
    required this.simSec,
    required this.totalMinutes,
    required this.isDark,
  });

  bool get _isWhite => _colorIsWhite(teamColor);

  Color get _safeBorder => _isWhite ? AppColors.slate400 : teamColor;
  Color get _safeLabel =>
      _isWhite ? (isDark ? AppColors.slate300 : AppColors.slate600) : teamColor;

  @override
  Widget build(BuildContext context) {
    final totalGoals = goals.length;
    final currentGoals = goals.where((g) => g.tSec <= simSec).length;

    // Rail geometry constants
    const double railH = 5.0; // rail thickness
    const double ballSz = 30.0; // ball diameter
    const double rowH = ballSz + 16.0; // total row height (glow room)
    const double railTop = (rowH - railH) / 2.0; // vertically centred rail
    const double ballTop = (rowH - ballSz) / 2.0; // ball centred on rail

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row: dot + name + animated score ─────────────────
        Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teamColor,
                border: Border.all(color: _safeBorder, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                teamName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate300 : AppColors.slate600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Animated score: "current / total"
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: RichText(
                key: ValueKey(currentGoals),
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$currentGoals',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentGoals > 0
                            ? _safeLabel
                            : (isDark
                                ? AppColors.slate600
                                : AppColors.slate300),
                      ),
                    ),
                    TextSpan(
                      text: ' / $totalGoals',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate600 : AppColors.slate300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Timeline track ─────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final trackW = constraints.maxWidth;
            final progressPx = (progress * trackW).clamp(0.0, trackW);

            return SizedBox(
              height: rowH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background rail
                  Positioned(
                    left: 0,
                    right: 0,
                    top: railTop,
                    height: railH,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate700 : AppColors.slate200,
                        borderRadius: BorderRadius.circular(railH / 2),
                      ),
                    ),
                  ),

                  // Progress fill — full team color
                  if (progressPx > 0)
                    Positioned(
                      left: 0,
                      top: railTop,
                      width: progressPx,
                      height: railH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isWhite ? AppColors.slate400 : teamColor,
                          borderRadius: BorderRadius.circular(railH / 2),
                        ),
                      ),
                    ),

                  // Tick marks (5 inner ticks at 10, 20, 30, 40, 50 min)
                  ...List.generate(5, (i) {
                    final x = ((i + 1) / 6.0) * trackW - 0.5;
                    return Positioned(
                      left: x,
                      top: railTop - 2,
                      height: railH + 4,
                      child: Container(
                        width: 1,
                        color:
                            (isDark ? AppColors.slate600 : AppColors.slate300)
                                .withAlpha(120),
                      ),
                    );
                  }),

                  // Goal balls — positioned by actual timestamp
                  ...goals.map((g) {
                    final leftPct = g.tSec / (totalMinutes * 60.0);
                    final cx = (leftPct * trackW)
                        .clamp(ballSz / 2, trackW - ballSz / 2);
                    final left = cx - ballSz / 2;
                    final isVisible = g.tSec <= simSec;

                    return Positioned(
                      left: left,
                      top: ballTop,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        opacity: isVisible ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 350),
                          scale: isVisible ? 1.0 : 0.2,
                          alignment: Alignment.center,
                          child: Tooltip(
                            message:
                                '${g.minute}\' • ${g.goalWithTeam.goal.scorerName ?? ""}',
                            child: _GoalBall(
                              teamColor: teamColor,
                              borderColor: _safeBorder,
                              isWhite: _isWhite,
                              size: ballSz,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Goal ball ─────────────────────────────────────────────────────────────────

class _GoalBall extends StatelessWidget {
  final Color teamColor;
  final Color borderColor;
  final bool isWhite;
  final double size;

  const _GoalBall({
    required this.teamColor,
    required this.borderColor,
    required this.isWhite,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = isWhite ? AppColors.slate400 : teamColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          // Inner soft glow
          BoxShadow(
            color: glowColor.withAlpha(isWhite ? 50 : 100),
            blurRadius: 6,
            spreadRadius: 0,
          ),
          // Outer radial glow — matches website cyan halo
          BoxShadow(
            color: glowColor.withAlpha(isWhite ? 30 : 70),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Text('⚽', style: TextStyle(fontSize: size * 0.47, height: 1)),
      ),
    );
  }
}

// ── Goal form sheet ───────────────────────────────────────────────────────────

class _GoalFormSheet extends StatefulWidget {
  final List<MatchPlayer> players;
  final MatchGoal? editing;
  final Future<void> Function(String scorerPlayerId, String? assistPlayerId,
      String time, bool isOwnGoal) onSave;

  const _GoalFormSheet({
    required this.players,
    this.editing,
    required this.onSave,
  });

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  String? _scorerPlayerId;
  String? _assistPlayerId;
  late final TextEditingController _timeCtrl;
  bool _isOwnGoal = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _scorerPlayerId = e?.scorerPlayerId;
    _assistPlayerId = e?.assistPlayerId;
    _timeCtrl = TextEditingController(text: e?.time ?? _defaultTime());
    _isOwnGoal = e?.isOwnGoal ?? false;
  }

  List<MatchPlayer> get _assistCandidates {
    if (_scorerPlayerId == null) return [];
    final scorer =
        widget.players.where((p) => p.playerId == _scorerPlayerId).firstOrNull;
    if (scorer == null) return [];
    return widget.players.where((p) {
      if (p.playerId == _scorerPlayerId) return false;
      return _isOwnGoal ? p.team != scorer.team : p.team == scorer.team;
    }).toList();
  }

  void _setScorer(String? id) {
    setState(() {
      _scorerPlayerId = id;
      _assistPlayerId = null;
    });
  }

  void _setOwnGoal(bool value) {
    setState(() {
      _isOwnGoal = value;
      _assistPlayerId = null;
    });
  }

  String _defaultTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_scorerPlayerId == null) {
      setState(() => _error = 'Selecione o marcador do gol.');
      return;
    }
    final time = _timeCtrl.text.trim();
    if (time.isEmpty) {
      setState(() => _error = 'Informe o horário do gol.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _scorerPlayerId!,
        (_assistPlayerId?.isNotEmpty == true) ? _assistPlayerId : null,
        time,
        _isOwnGoal,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = extractDioError(e, 'Erro ao salvar gol');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : AppColors.slate900;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(children: [
              Text(
                widget.editing != null ? 'Editar gol' : 'Adicionar gol',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: labelColor),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ]),
            const SizedBox(height: 16),

            // Scorer
            _PlayerDropdown(
              label: 'Marcador *',
              players: widget.players,
              selectedId: _scorerPlayerId,
              onChanged: _setScorer,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Time
            TextField(
              controller: _timeCtrl,
              decoration: InputDecoration(
                labelText: 'Horário (HH:mm)',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                labelStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              keyboardType: TextInputType.datetime,
              style: TextStyle(fontSize: 14, color: labelColor),
            ),
            const SizedBox(height: 4),

            // Own goal checkbox
            CheckboxListTile(
              value: _isOwnGoal,
              onChanged: (v) => _setOwnGoal(v ?? false),
              title: const Text('Gol contra', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Assist — só aparece quando um marcador está selecionado e há candidatos
            if (_scorerPlayerId != null && _assistCandidates.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PlayerDropdown(
                label: _isOwnGoal
                    ? 'Quem forçou o gol contra (opcional)'
                    : 'Assistência (opcional)',
                players: _assistCandidates,
                selectedId: _assistPlayerId,
                onChanged: (id) => setState(() => _assistPlayerId = id),
                isDark: isDark,
                nullable: true,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.rose500, fontSize: 12)),
            ],
            const SizedBox(height: 12),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(widget.editing != null
                      ? 'Salvar alterações'
                      : 'Adicionar gol'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDropdown extends StatelessWidget {
  final String label;
  final List<MatchPlayer> players;
  final String? selectedId;
  final void Function(String?) onChanged;
  final bool isDark;
  final bool nullable;

  const _PlayerDropdown({
    required this.label,
    required this.players,
    required this.selectedId,
    required this.onChanged,
    required this.isDark,
    this.nullable = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        labelStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.slate400 : AppColors.slate500),
      ),
      items: [
        if (nullable)
          DropdownMenuItem<String?>(
            value: null,
            child: Text('— Nenhum —',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.slate400 : AppColors.slate500)),
          ),
        ...players.map((p) => DropdownMenuItem<String?>(
              value: p.playerId,
              child: Text(p.playerName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.slate900)),
            )),
      ],
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 14, color: isDark ? Colors.white : AppColors.slate900),
      dropdownColor: isDark ? AppColors.slate800 : Colors.white,
    );
  }
}
