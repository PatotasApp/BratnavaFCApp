import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../replays/domain/entities/replay_clip.dart';
import '../../../replays/presentation/providers/replay_access_provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/avatar_widget.dart';
import '../../../../shared/presentation/widgets/user_profile_link.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../../matches/presentation/providers/match_provider.dart';
import '../../domain/entities/match_details.dart';
import '../widgets/match_goals_panel.dart';
import '../widgets/match_replays_section.dart';
import '../providers/history_provider.dart';
import '../../../../core/share/share_links.dart';

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
  int _detailsTab = 0;
  List<ReplayClip> _replays = [];
  bool _sharingCard = false;
  final Set<String> _togglingNoShow = {};

  Future<void> _showGoalSheet(MatchDetails data, {MatchGoal? editing}) async {
    final allPlayers = [...data.teamAPlayers, ...data.teamBPlayers]
        .where((p) => p.playerId != null && p.playerId!.isNotEmpty)
        .toList();
    final icons = GroupIcons.from(
      ref.read(groupSettingsProvider(widget.groupId)).valueOrNull,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => GoalFormSheet(
        players: allPlayers,
        icons: icons,
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
    ref.listenManual(
      activeGroupReplayUiProvider,
      (_, canSeeReplays) {
        if (canSeeReplays) {
          _loadReplays();
        } else if (_replays.isNotEmpty && mounted) {
          setState(() => _replays = []);
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _loadReplays() async {
    if (!ref.read(activeGroupReplayUiProvider)) return;
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
    final accessToken = ref.watch(idTokenProvider).valueOrNull;
    final async = ref.watch(matchDetailsProvider(
      (groupId: widget.groupId, matchId: widget.matchId),
    ));
    final settings =
        ref.watch(groupSettingsProvider(widget.groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);
    final canSeeReplays = ref.watch(activeGroupReplayUiProvider);

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
        showReplays: canSeeReplays,
        goalsTab: _goalsTab,
        activeTab: _detailsTab,
        icons: icons,
        replays: _replays,
        groupId: widget.groupId,
        accessToken: accessToken,
        sharingCard: _sharingCard,
        onGoalsTab: (t) => setState(() => _goalsTab = t),
        onTabChanged: (t) => setState(() => _detailsTab = t),
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
  final bool showReplays;
  final int goalsTab;
  final int activeTab;
  final void Function(int) onGoalsTab;
  final void Function(int) onTabChanged;
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
    required this.showReplays,
    required this.goalsTab,
    required this.activeTab,
    required this.onGoalsTab,
    required this.onTabChanged,
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
      _hexColor(data.teamAColor?.hexValue) ?? AppColors.slate900;
  Color get bColor =>
      _hexColor(data.teamBColor?.hexValue) ?? AppColors.slate900;
  String get aName => data.teamAColor?.name ?? 'Time A';
  String get bName => data.teamBColor?.name ?? 'Time B';

  @override
  Widget build(BuildContext context) {
    final hasGoals = data.goals.isNotEmpty;
    final selectedTab = switch (activeTab) {
      0 when !hasGoals => 1,
      2 when !canSeeStats => hasGoals ? 0 : 1,
      3 when !showReplays => hasGoals ? 0 : 1,
      _ => activeTab,
    };
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
      return GoalWithTeam(goal: g, team: team);
    }).toList();

    // Build goal events for simulation (enrich with tSec)
    final goalEvents = _buildGoalEvents(goals);

    // MVP
    final mvpPlayers = [
      ...data.teamAPlayers,
      ...data.teamBPlayers,
    ].where((p) => p.isMvp && !p.didNotPlay).toList();
    final goalkeeperByName = <String, bool>{
      for (final player in [...data.teamAPlayers, ...data.teamBPlayers])
        player.playerName: player.isGoalkeeper,
    };

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Detalhes da partida',
                subtitle: [
                  if (data.playedAt != null)
                    DateFormat('dd/MM/yyyy', 'pt_BR').format(data.playedAt!),
                  if (data.placeName?.isNotEmpty == true) data.placeName!,
                ].join(' · '),
                icon: Icons.sports_soccer_outlined,
                onBack: onBack,
                actions: [
                  Builder(
                    builder: (ctx) => AppPageHeaderAction(
                      icon: Icons.share_outlined,
                      tooltip: 'Compartilhar partida',
                      onPressed: () => shareLink(
                          ctx, ShareLinks.match(data.matchId),
                          text: 'Partida no PatotasApp'),
                    ),
                  ),
                ],
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

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _MatchDetailsTabs(
                  activeTab: selectedTab,
                  onChanged: onTabChanged,
                  isDark: isDark,
                  canSeeStats: canSeeStats,
                  showReplays: showReplays,
                  hasGoals: hasGoals,
                ),
              ),
              const SizedBox(height: 12),

              // Simulação minuto a minuto
              if (selectedTab == 0) ...[
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
              ],

              const SizedBox(height: 12),

              // Gols — visível apenas para admin ou quando showPlayerStats=true
              if (selectedTab == 2 && canSeeStats) ...[
                _SectionHeader(
                  title: 'Gols (${goals.length})',
                  isDark: isDark,
                ),
                MatchGoalsSection(
                  goals: goals,
                  tab: goalsTab,
                  onTab: onGoalsTab,
                  aColor: aColor,
                  bColor: bColor,
                  aName: aName,
                  bName: bName,
                  isDark: isDark,
                  icons: icons,
                  goalkeeperByName: goalkeeperByName,
                  isAdmin: isAdmin,
                  onAddGoal: onAddGoal,
                  onEditGoal: onEditGoal,
                  onDeleteGoal: onDeleteGoal,
                ),
              ],

              const SizedBox(height: 12),

              // ── Jogadores ─────────────────────────────────────────
              if (selectedTab == 1) ...[
                _SectionHeader(title: 'Escalação', isDark: isDark),
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
              ],

              // Replays section (only when replays exist)
              if (selectedTab == 3 && replays.isNotEmpty) ...[
                const SizedBox(height: 12),
                MatchReplaysSection(
                  replays: replays,
                  groupId: groupId,
                  accessToken: accessToken,
                  isDark: isDark,
                ),
              ],

              if (selectedTab == 4 &&
                  (mvpPlayers.isNotEmpty || data.voteCounts.isNotEmpty)) ...[
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
                    goalkeeperByName: goalkeeperByName,
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

class _MatchDetailsTabs extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onChanged;
  final bool isDark;
  final bool canSeeStats;
  final bool showReplays;
  final bool hasGoals;

  const _MatchDetailsTabs({
    required this.activeTab,
    required this.onChanged,
    required this.isDark,
    required this.canSeeStats,
    required this.showReplays,
    required this.hasGoals,
  });

  List<(String, int)> get _tabs => [
        if (hasGoals) ('Resumo', 0),
        ('Escalação', 1),
        if (canSeeStats) ('Gols', 2),
        if (showReplays) ('Replays', 3),
        ('MVP', 4),
      ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) {
              final tab = _tabs[index];
              final selected = activeTab == tab.$2;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(tab.$2),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark ? AppColors.slate700 : AppColors.onDark)
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                  color: AppColors.shadow08, blurRadius: 4)
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      child: Text(
                        tab.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: isDark
                              ? (selected
                                  ? AppColors.onDark
                                  : AppColors.slate400)
                              : (selected
                                  ? AppColors.slate900
                                  : AppColors.slate500),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

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
          border: Border.all(
              color: AppColors.darkApp.withValues(alpha: 0.25), width: 1),
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
                        color: AppColors.slate900,
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
                                          color: AppColors.lightPlaceholder,
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
                                      color: AppColors.lightTextSecondary,
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
                                          color: AppColors.lightPlaceholder,
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
                                    color: AppColors.onDark,
                                    height: 1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '×',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${data.teamBGoals ?? '–'}',
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.onDark,
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
                                          size: 12,
                                          color: AppColors.lightTextSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        data.placeName!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (playedStr != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 12,
                                          color: AppColors.lightTextSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        playedStr,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            _HeroMvpBadge(
                              mvpPlayers: mvpPlayers,
                              voteCounts: voteCounts,
                              icons: icons,
                              goalkeeperByName: {
                                for (final player in [
                                  ...data.teamAPlayers,
                                  ...data.teamBPlayers,
                                ])
                                  player.playerName: player.isGoalkeeper,
                              },
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
  final Map<String, bool> goalkeeperByName;

  const _HeroMvpBadge({
    required this.mvpPlayers,
    required this.voteCounts,
    required this.icons,
    required this.goalkeeperByName,
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

    final label = hasMvp
        ? (mvpPlayers.length > 1 ? 'MVPs:' : 'MVP:')
        : isVoteTie
            ? 'Empate — sem MVP:'
            : 'Liderando:';
    final names = hasMvp
        ? mvpPlayers.map((player) => player.playerName).toList()
        : topPlayers.map((player) => player.playerName).toList();
    final isTieWithoutMvp = !hasMvp && isVoteTie;
    final accent = isTieWithoutMvp ? AppColors.warning : AppColors.warning;
    final textColor = isTieWithoutMvp ? AppColors.amber200 : AppColors.amber200;

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
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 4,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    names.join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
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

class _MvpResultSection extends StatelessWidget {
  final List<MatchPlayer> mvpPlayers;
  final List<MvpVoteResult> voteCounts;
  final bool isAdmin;
  final bool isDark;
  final GroupIcons icons;
  final Map<String, bool> goalkeeperByName;

  const _MvpResultSection({
    required this.mvpPlayers,
    required this.voteCounts,
    required this.isAdmin,
    required this.isDark,
    required this.icons,
    required this.goalkeeperByName,
  });

  @override
  Widget build(BuildContext context) {
    final hasMvp = mvpPlayers.isNotEmpty;
    final maxVotes = voteCounts.isEmpty ? 0 : voteCounts.first.votes;
    final topPlayers =
        voteCounts.where((v) => v.votes == maxVotes && maxVotes > 0).toList();
    final totalVotes =
        voteCounts.fold<int>(0, (total, vote) => total + vote.votes);
    final winnerVotes = mvpPlayers.fold<int>(
      0,
      (total, player) =>
          total +
          voteCounts
              .where((vote) => vote.playerName == player.playerName)
              .fold<int>(0, (sum, vote) => sum + vote.votes),
    );
    final voteTie = !hasMvp && topPlayers.length > 1;
    final voteLeading = !hasMvp && topPlayers.length == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.onDark,
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
              iconColor: AppColors.warning,
              bgColor: AppColors.warning.withValues(alpha: 0.10),
              borderColor: AppColors.warning.withValues(alpha: 0.24),
              title: mvpPlayers.length > 1 ? 'MVPs do jogo' : 'Melhor do jogo',
              names: mvpPlayers.map((p) => p.playerName).toList(),
              voteSummary:
                  totalVotes > 0 ? '$winnerVotes de $totalVotes votos' : null,
              isDark: isDark,
              icons: icons,
              goalkeeperByName: goalkeeperByName,
            )
          else if (voteTie)
            _MvpMainResult(
              iconColor: AppColors.warning,
              bgColor: AppColors.warning.withValues(alpha: 0.10),
              borderColor: AppColors.warning.withValues(alpha: 0.24),
              title: 'Empate — nenhum MVP eleito',
              subtitle: 'Mais votados:',
              names: topPlayers.map((p) => p.playerName).toList(),
              isDark: isDark,
              icons: icons,
              goalkeeperByName: goalkeeperByName,
            )
          else if (voteLeading)
            _MvpMainResult(
              iconColor: AppColors.warning,
              bgColor: AppColors.warning.withValues(alpha: 0.08),
              borderColor: AppColors.warning.withValues(alpha: 0.18),
              title: 'Liderando a votação',
              names: [topPlayers.first.playerName],
              isDark: isDark,
              icons: icons,
              goalkeeperByName: goalkeeperByName,
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
                        goalkeeperByName: goalkeeperByName,
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
  final String? voteSummary;
  final bool isDark;
  final GroupIcons icons;
  final Map<String, bool> goalkeeperByName;

  const _MvpMainResult({
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    this.subtitle,
    required this.names,
    this.voteSummary,
    required this.isDark,
    required this.icons,
    required this.goalkeeperByName,
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
                if (voteSummary != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    voteSummary!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
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

class _MvpVoteRow extends StatelessWidget {
  final MvpVoteResult vote;
  final int maxVotes;
  final bool highlight;
  final bool isTie;
  final bool isDark;
  final GroupIcons icons;
  final Map<String, bool> goalkeeperByName;

  const _MvpVoteRow({
    required this.vote,
    required this.maxVotes,
    required this.highlight,
    required this.isTie,
    required this.isDark,
    required this.icons,
    required this.goalkeeperByName,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxVotes <= 0 ? 0.0 : vote.votes / maxVotes;
    final accent = isTie ? AppColors.warning : AppColors.warning;
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
            child: _PrototypeTeamColumn(
              players: teamAPlayers,
              color: aColor,
              name: aName,
              isDark: isDark,
              icons: icons,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PrototypeTeamColumn(
              players: teamBPlayers,
              color: bColor,
              name: bName,
              isDark: isDark,
              icons: icons,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeTeamColumn extends StatelessWidget {
  final List<MatchPlayer> players;
  final Color color;
  final String name;
  final bool isDark;
  final GroupIcons icons;

  const _PrototypeTeamColumn({
    required this.players,
    required this.color,
    required this.name,
    required this.isDark,
    required this.icons,
  });

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .28),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .45,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (players.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Nenhum jogador',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
          )
        else
          ...players.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Opacity(
                opacity: player.didNotPlay ? .5 : 1,
                child: Container(
                  height: 53,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.slate800 : AppColors.slate200,
                    ),
                  ),
                  child: Row(
                    children: [
                      UserProfileLink(
                        userId: player.userId,
                        child: player.photoUrl?.trim().isNotEmpty == true
                            ? AvatarWidget(
                                name: player.playerName,
                                photoUrl: player.photoUrl,
                                size: 32,
                                fit: BoxFit.cover,
                                borderRadius: 10,
                              )
                            : Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.amber50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _initials(player.playerName),
                                  style: const TextStyle(
                                    color: AppColors.primaryPressed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: UserProfileLink(
                                    userId: player.userId,
                                    child: Text(
                                      player.playerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.slate100
                                            : AppColors.slate900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                renderGroupIcon(
                                  player.isGoalkeeper
                                      ? icons.goalkeeper
                                      : icons.player,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              player.isGoalkeeper ? 'Goleiro' : 'Jogador',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
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
          ),
      ],
    );
  }
}

class TeamCard extends StatelessWidget {
  final List<MatchPlayer> players;
  final Color color;
  final String name;
  final bool isDark;
  final GroupIcons icons;
  final bool isAdmin;
  final Set<String> togglingNoShow;
  final void Function(String, bool) onToggleNoShow;

  const TeamCard({
    super.key,
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
        color: isDark ? AppColors.slate900 : AppColors.onDark,
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
                      renderGroupIcon(
                        p.isGoalkeeper ? icons.goalkeeper : icons.player,
                        size: 14,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                      const SizedBox(width: 4),
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
                          color: AppColors.warning,
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
          color: isDark ? AppColors.onDark : AppColors.slate900,
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
    final isWhite = color == AppColors.darkText;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isWhite ? AppColors.slate300 : AppColors.onDark.withAlpha(80),
          width: 1,
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
  final GoalWithTeam goalWithTeam;
  final int tSec; // seconds from game start, clamped 0..3600
  final int minute; // game minute

  const _GoalEvent(
      {required this.goalWithTeam, required this.tSec, required this.minute});
}

List<_GoalEvent> _buildGoalEvents(List<GoalWithTeam> goals) {
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
        color: isDark ? AppColors.slate900 : AppColors.onDark,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                  TextSpan(
                    text: '/$_totalMinutes',
                    style: TextStyle(
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
            color: isDark ? AppColors.slate900 : AppColors.onDark,
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
              color:
                  isWhite ? AppColors.slate300 : AppColors.onDark.withAlpha(60),
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
              color: isDark ? AppColors.onDark : AppColors.slate900,
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
        color: AppColors.onDark,
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
