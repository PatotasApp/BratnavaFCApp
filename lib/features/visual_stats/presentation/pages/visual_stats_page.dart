import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/visual_stats_report.dart';
import '../providers/visual_stats_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Mirrors site's normalizeWR: if ≤1 treat as fraction, else clamp to 0–100
double _normalizeWR(double v) {
  if (!v.isFinite) return 0;
  final pct = v <= 1 ? v * 100 : v;
  return pct.clamp(0, 100);
}

/// Green ≥60 · Amber 45–59 · Red <45  (mirrors site's wrColor)
Color _wrColor(double v) {
  if (v >= 60) return const Color(0xFF16A34A);
  if (v >= 45) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

String _pct(double v) => '${v.toStringAsFixed(0)}%';
String _rankText(int? rank) => rank != null && rank > 0 ? '${rank}º' : '—';

/// Deduplicate synergies into unique pairs, sort by WR desc
List<_GlobalSynergyRow> _buildGlobalSynergy(
    List<PlayerVisualStatsItem> players) {
  final map = <String, _GlobalSynergyRow>{};
  for (final p in players) {
    for (final s in p.synergies) {
      if (s.matchesTogether <= 0) continue;
      final aId = p.playerId.compareTo(s.withPlayerId) < 0
          ? p.playerId
          : s.withPlayerId;
      final bId = p.playerId.compareTo(s.withPlayerId) < 0
          ? s.withPlayerId
          : p.playerId;
      final aName =
          p.playerId.compareTo(s.withPlayerId) < 0 ? p.name : s.withPlayerName;
      final bName =
          p.playerId.compareTo(s.withPlayerId) < 0 ? s.withPlayerName : p.name;
      final key = '$aId|$bId';
      final wr = _normalizeWR(s.winRateTogether);
      final cur = map[key];
      if (cur == null || s.matchesTogether > cur.matches) {
        map[key] = _GlobalSynergyRow(
          aId: aId,
          aName: aName,
          bId: bId,
          bName: bName,
          matches: s.matchesTogether,
          wins: s.winsTogether,
          wr: wr,
        );
      }
    }
  }
  final list = map.values.toList();
  list.sort((a, b) =>
      b.wr != a.wr ? b.wr.compareTo(a.wr) : b.matches.compareTo(a.matches));
  return list;
}

class _GlobalSynergyRow {
  final String aId, aName, bId, bName;
  final int matches, wins;
  final double wr;
  const _GlobalSynergyRow({
    required this.aId,
    required this.aName,
    required this.bId,
    required this.bName,
    required this.matches,
    required this.wins,
    required this.wr,
  });
}

// ── Sort key ──────────────────────────────────────────────────────────────────

enum _SortKey {
  points,
  winRate,
  wins,
  games,
  mvps,
  mvpVotes,
  goals,
  assists,
  ownGoals,
  name
}

enum _StatsViewMode { general, perMatch, classification }

extension _SortKeyLabel on _SortKey {
  String get shortLabel => switch (this) {
        _SortKey.points => 'Pontos',
        _SortKey.winRate => 'Win Rate',
        _SortKey.wins => 'Vitórias',
        _SortKey.games => 'Jogos',
        _SortKey.mvps => 'MVPs',
        _SortKey.mvpVotes => 'Votos MVP',
        _SortKey.goals => 'Gols',
        _SortKey.assists => 'Assists',
        _SortKey.ownGoals => 'GC',
        _SortKey.name => 'Nome',
      };
}

// ── Page ──────────────────────────────────────────────────────────────────────

class VisualStatsPage extends ConsumerStatefulWidget {
  const VisualStatsPage({super.key});

  @override
  ConsumerState<VisualStatsPage> createState() => _VisualStatsPageState();
}

class _VisualStatsPageState extends ConsumerState<VisualStatsPage> {
  _StatsViewMode _viewMode = _StatsViewMode.general;
  String _search = '';
  _SortKey _sortKey = _SortKey.winRate;

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PlayerVisualStatsItem> _sorted(List<PlayerVisualStatsItem> players) {
    final q = _search.trim().toLowerCase();
    var list = [...players];
    if (q.isNotEmpty)
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    switch (_sortKey) {
      case _SortKey.points:
        list.sort((a, b) => b.points.compareTo(a.points));
      case _SortKey.winRate:
        list.sort((a, b) =>
            _normalizeWR(b.winRate).compareTo(_normalizeWR(a.winRate)));
      case _SortKey.wins:
        list.sort((a, b) => b.wins.compareTo(a.wins));
      case _SortKey.games:
        list.sort((a, b) => b.gamesPlayed.compareTo(a.gamesPlayed));
      case _SortKey.mvps:
        list.sort((a, b) => b.mvps.compareTo(a.mvps));
      case _SortKey.mvpVotes:
        list.sort((a, b) => b.mvpVotes.compareTo(a.mvpVotes));
      case _SortKey.goals:
        list.sort((a, b) => b.goals.compareTo(a.goals));
      case _SortKey.assists:
        list.sort((a, b) => b.assists.compareTo(a.assists));
      case _SortKey.ownGoals:
        list.sort((a, b) => b.ownGoals.compareTo(a.ownGoals));
      case _SortKey.name:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;

    // Enquanto myPlayersProvider carrega, mostra spinner em vez de "sem grupo"
    if (groupId == null || groupId.isEmpty) {
      final playersAsync = ref.watch(myPlayersProvider);
      if (playersAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const Scaffold(body: _NoGroupState());
    }

    final async = ref.watch(visualStatsProvider(groupId));
    final settings = ref.watch(groupSettingsProvider(groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);
    final showGeneral = settings?.showStatsGeneralTab ?? true;
    final showPerMatch = settings?.showStatsPerMatchTab ?? true;
    final showClassification = settings?.showStatsClassificationTab ?? true;
    final enabledModes = <_StatsViewMode>[
      if (showGeneral) _StatsViewMode.general,
      if (showPerMatch) _StatsViewMode.perMatch,
      if (showClassification) _StatsViewMode.classification,
    ];
    final safeModes =
        enabledModes.isEmpty ? [_StatsViewMode.general] : enabledModes;
    if (!safeModes.contains(_viewMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _viewMode = safeModes.first;
          _sortKey = _viewMode == _StatsViewMode.classification
              ? _SortKey.points
              : _SortKey.winRate;
        });
      });
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(visualStatsProvider(groupId)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header with tab buttons ──────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(
                async,
                icons,
                showGeneral: showGeneral,
                showPerMatch: showPerMatch,
                showClassification: showClassification,
              ),
            ),
            // ── Content ──────────────────────────────────────────────────
            async.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonList()),
              error: (e, _) => SliverToBoxAdapter(
                  child: _ErrorState(message: extractDioError(e))),
              data: (report) {
                final sorted = _sorted(report.players);
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    child: _viewMode != _StatsViewMode.perMatch
                        ? _RankingsContent(
                            report: report,
                            sorted: sorted,
                            sortKey: _sortKey,
                            search: _search,
                            searchCtrl: _searchCtrl,
                            icons: icons,
                            classificationMode:
                                _viewMode == _StatsViewMode.classification,
                            onSort: (k) => setState(() => _sortKey = k),
                            onSearch: (v) => setState(() => _search = v),
                            onPlayerTap: (id) {
                              final player = report.players.firstWhere(
                                (p) => p.playerId == id,
                                orElse: () => sorted.first,
                              );
                              final isDark = Theme.of(context).brightness ==
                                  Brightness.dark;
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _PlayerDetailSheet(
                                  player: player,
                                  icons: icons,
                                  isDark: isDark,
                                ),
                              );
                            },
                          )
                        : _PlayersContent(
                            report: report,
                            sorted: sorted,
                            sortKey: _sortKey,
                            search: _search,
                            searchCtrl: _searchCtrl,
                            icons: icons,
                            onSort: (k) => setState(() => _sortKey = k),
                            onSearch: (v) => setState(() => _search = v),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark gradient header ──────────────────────────────────────────────────

  Widget _buildHeader(
    AsyncValue<PlayerVisualStatsReport> async,
    GroupIcons icons, {
    required bool showGeneral,
    required bool showPerMatch,
    required bool showClassification,
  }) {
    final report = async.valueOrNull;
    final playerCount = report?.players.length ?? 0;
    final finalizedCount = report?.totalFinalizedMatches ?? 0;
    final consideredCount = report?.totalMatchesConsidered ?? 0;

    String subtitle;
    if (async.isLoading) {
      subtitle = 'Carregando...';
    } else {
      subtitle = '$playerCount jogadores';
      if (finalizedCount > 0) subtitle += ' · $finalizedCount finalizadas';
      if (consideredCount > 0) subtitle += ' · $consideredCount consideradas';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estatísticas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withAlpha(128),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Tab buttons
              Row(
                children: [
                  if (showGeneral) ...[
                    _tabBtn('Geral', Icons.bar_chart_rounded,
                        selected: _viewMode == _StatsViewMode.general,
                        onTap: () => setState(() {
                              _viewMode = _StatsViewMode.general;
                              if (_sortKey == _SortKey.points) {
                                _sortKey = _SortKey.winRate;
                              }
                            })),
                    const SizedBox(width: 6),
                  ],
                  if (showPerMatch) ...[
                    _tabBtn('Por partida', Icons.person_outline_rounded,
                        selected: _viewMode == _StatsViewMode.perMatch,
                        onTap: () => setState(() {
                              _viewMode = _StatsViewMode.perMatch;
                              if (_sortKey == _SortKey.points) {
                                _sortKey = _SortKey.winRate;
                              }
                            })),
                    const SizedBox(width: 6),
                  ],
                  if (showClassification)
                    _tabBtn('Classificacao', Icons.leaderboard_outlined,
                        selected: _viewMode == _StatsViewMode.classification,
                        onTap: () => setState(() {
                              _viewMode = _StatsViewMode.classification;
                              _sortKey = _SortKey.points;
                            })),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, IconData icon,
          {required bool selected, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected
                      ? AppColors.slate900
                      : Colors.white.withAlpha(200)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.slate900
                        : Colors.white.withAlpha(200),
                  )),
            ],
          ),
        ),
      );
}

// ── Rankings content ──────────────────────────────────────────────────────────

class _RankingsContent extends StatelessWidget {
  final PlayerVisualStatsReport report;
  final List<PlayerVisualStatsItem> sorted;
  final _SortKey sortKey;
  final String search;
  final TextEditingController searchCtrl;
  final GroupIcons icons;
  final bool classificationMode;
  final ValueChanged<_SortKey> onSort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onPlayerTap;

  const _RankingsContent({
    required this.report,
    required this.sorted,
    required this.sortKey,
    required this.search,
    required this.searchCtrl,
    required this.icons,
    required this.classificationMode,
    required this.onSort,
    required this.onSearch,
    required this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final globalSynergy = _buildGlobalSynergy(report.players);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Player ranking card ─────────────────────────────────────────
        _card(isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  isDark,
                  icon: Icons.leaderboard_outlined,
                  title: 'Ranking de jogadores',
                  child: null,
                ),
                // Toolbar: search + sort chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _searchField(isDark, searchCtrl, onSearch),
                      const SizedBox(height: 8),
                      _sortChips(
                        isDark,
                        sortKey,
                        icons,
                        onSort,
                        classificationMode: classificationMode,
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: isDark ? AppColors.slate700 : AppColors.slate100),
                // Ranking list
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('Nenhum jogador encontrado.',
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.slate500
                                    : AppColors.slate400))),
                  )
                else
                  ...sorted.asMap().entries.map((e) => _RankingListItem(
                        rank:
                            classificationMode && e.value.classificationRank > 0
                                ? e.value.classificationRank
                                : e.key + 1,
                        player: e.value,
                        icons: icons,
                        classificationMode: classificationMode,
                        isDark: isDark,
                        onTap: () => onPlayerTap(e.value.playerId),
                      )),
              ],
            )),

        // ── Melhores duplas ─────────────────────────────────────────────
        if (globalSynergy.isNotEmpty) ...[
          const SizedBox(height: 16),
          _card(isDark,
              child: Column(
                children: [
                  _cardHeader(
                    isDark,
                    icon: Icons.layers_outlined,
                    title: 'Melhores duplas',
                    sub:
                        '${min(globalSynergy.length, 20)} pares · por win rate',
                    child: null,
                  ),
                  Divider(
                      height: 1,
                      color: isDark ? AppColors.slate700 : AppColors.slate100),
                  ...globalSynergy
                      .take(20)
                      .toList()
                      .asMap()
                      .entries
                      .map((e) => _SynergyPairRow(
                            idx: e.key + 1,
                            row: e.value,
                            isDark: isDark,
                          )),
                ],
              )),
        ],
      ],
    );
  }
}

// ── Ranking table ─────────────────────────────────────────────────────────────

class _RankingTable extends StatelessWidget {
  final List<PlayerVisualStatsItem> sorted;
  final GroupIcons icons;
  final bool isDark;
  final ValueChanged<String> onTap;

  const _RankingTable({
    required this.sorted,
    required this.icons,
    required this.isDark,
    required this.onTap,
  });

  static const _rankW = 32.0;
  static const _gamesW = 32.0;
  static const _vedW = 72.0;
  static const _wrW = 130.0;
  static const _mvpW = 44.0;
  static const _iconColW = 34.0;
  static const _nameW = 160.0;

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: isDark ? AppColors.slate500 : AppColors.slate400,
    );
    final divColor = isDark ? AppColors.slate800 : AppColors.slate50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          color: isDark ? AppColors.slate800.withAlpha(120) : AppColors.slate50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                  width: _rankW, child: Center(child: Text('#', style: head))),
              SizedBox(width: _nameW, child: Text('JOGADOR', style: head)),
              SizedBox(
                  width: _gamesW, child: Center(child: Text('J', style: head))),
              SizedBox(
                  width: _vedW,
                  child: Center(child: Text('V/E/D', style: head))),
              SizedBox(
                  width: _wrW,
                  child: Text('WIN RATE',
                      style: head.copyWith(letterSpacing: 0.5))),
              SizedBox(
                  width: _mvpW, child: Center(child: Text('MVP', style: head))),
              SizedBox(
                  width: _iconColW,
                  child: Center(child: renderGroupIcon(icons.goal, size: 12))),
              SizedBox(
                  width: _iconColW,
                  child:
                      Center(child: renderGroupIcon(icons.assist, size: 12))),
              SizedBox(
                  width: _iconColW + 8,
                  child:
                      Center(child: renderGroupIcon(icons.ownGoal, size: 12))),
            ],
          ),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: _rankW +
                  _nameW +
                  _gamesW +
                  _vedW +
                  _wrW +
                  _mvpW +
                  _iconColW * 3 +
                  8,
              child: Center(
                child: Text('Nenhum jogador encontrado.',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? AppColors.slate500 : AppColors.slate400)),
              ),
            ),
          )
        else
          ...sorted.asMap().entries.map((e) {
            final idx = e.key;
            final p = e.value;
            final wr = _normalizeWR(p.winRate);
            final dimColor = isDark ? AppColors.slate700 : AppColors.slate100;
            return GestureDetector(
              onTap: () => onTap(p.playerId),
              child: Container(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Container(
                      color: isDark ? AppColors.slate700 : divColor,
                      height: 0.5,
                    ),
                    Opacity(
                      opacity: p.isActive ? 1.0 : 0.45,
                      child: Row(
                        children: [
                          // Rank
                          SizedBox(
                            width: _rankW,
                            child: Center(
                                child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.slate500
                                      : AppColors.slate400,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ]),
                            )),
                          ),
                          // Name
                          SizedBox(
                            width: _nameW,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                if (p.isGoalkeeper) ...[
                                  renderGroupIcon(icons.goalkeeper,
                                      size: 12,
                                      color: isDark
                                          ? AppColors.slate400
                                          : AppColors.slate500),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                    child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.slate900),
                                )),
                                if (p.mvps > 0) ...[
                                  const SizedBox(width: 3),
                                  renderGroupIcon(icons.mvp,
                                      size: 10, color: const Color(0xFFFBBF24)),
                                ],
                                if (!p.isActive) ...[
                                  const SizedBox(width: 4),
                                  Text('inativo',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: isDark
                                              ? AppColors.slate500
                                              : AppColors.slate400)),
                                ],
                              ]),
                            ),
                          ),
                          // Games
                          SizedBox(
                            width: _gamesW,
                            child: Center(
                                child: Text(
                              '${p.gamesPlayed}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ]),
                            )),
                          ),
                          // V/E/D
                          SizedBox(
                            width: _vedW,
                            child: Center(
                                child: RichText(
                                    text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontFeatures: [FontFeature.tabularFigures()]),
                              children: [
                                TextSpan(
                                    text: '${p.wins}',
                                    style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w700)),
                                TextSpan(
                                    text: '/',
                                    style: TextStyle(
                                        color: isDark
                                            ? AppColors.slate600
                                            : AppColors.slate300)),
                                TextSpan(
                                    text: '${p.ties}',
                                    style: TextStyle(
                                        color: isDark
                                            ? AppColors.slate400
                                            : AppColors.slate500)),
                                TextSpan(
                                    text: '/',
                                    style: TextStyle(
                                        color: isDark
                                            ? AppColors.slate600
                                            : AppColors.slate300)),
                                TextSpan(
                                    text: '${p.losses}',
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w700)),
                              ],
                            ))),
                          ),
                          // WR bar
                          SizedBox(
                            width: _wrW,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _WRBar(value: wr, isDark: isDark),
                            ),
                          ),
                          // MVP
                          SizedBox(
                            width: _mvpW,
                            child: Center(
                              child: p.mvps > 0
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                          renderGroupIcon(icons.mvp,
                                              size: 11,
                                              color: const Color(0xFFF59E0B)),
                                          const SizedBox(width: 2),
                                          Text('${p.mvps}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFF59E0B),
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              )),
                                        ])
                                  : Text('—',
                                      style: TextStyle(
                                          fontSize: 11, color: dimColor)),
                            ),
                          ),
                          // Goals
                          SizedBox(
                            width: _iconColW,
                            child: Center(
                                child: p.goals > 0
                                    ? Text('${p.goals}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.slate300
                                                : AppColors.slate700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ]))
                                    : Text('—',
                                        style: TextStyle(
                                            fontSize: 11, color: dimColor))),
                          ),
                          // Assists
                          SizedBox(
                            width: _iconColW,
                            child: Center(
                                child: p.assists > 0
                                    ? Text('${p.assists}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.slate300
                                                : AppColors.slate700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ]))
                                    : Text('—',
                                        style: TextStyle(
                                            fontSize: 11, color: dimColor))),
                          ),
                          // Own goals
                          SizedBox(
                            width: _iconColW + 8,
                            child: Center(
                                child: p.ownGoals > 0
                                    ? Text('${p.ownGoals}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFEF4444),
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ]))
                                    : Text('—',
                                        style: TextStyle(
                                            fontSize: 11, color: dimColor))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── Ranking list item (Geral tab) ─────────────────────────────────────────────

class _RankingListItem extends StatelessWidget {
  final int rank;
  final PlayerVisualStatsItem player;
  final GroupIcons icons;
  final bool classificationMode;
  final bool isDark;
  final VoidCallback onTap;

  const _RankingListItem({
    required this.rank,
    required this.player,
    required this.icons,
    required this.classificationMode,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wr = _normalizeWR(player.winRate);
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : null;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: player.isActive ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: isDark ? AppColors.slate700 : AppColors.slate100,
                    width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rank number
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Medal (top 3) or blank space
              SizedBox(
                width: 18,
                child: medal != null
                    ? Text(medal, style: const TextStyle(fontSize: 13))
                    : null,
              ),
              const SizedBox(width: 6),
              // Name + inline stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (player.isGoalkeeper) ...[
                        renderGroupIcon(icons.goalkeeper,
                            size: 11,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                          child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      )),
                      if (player.mvps > 0) ...[
                        const SizedBox(width: 4),
                        renderGroupIcon(icons.mvp,
                            size: 11, color: const Color(0xFFFBBF24)),
                      ],
                      if (!player.isActive) ...[
                        const SizedBox(width: 4),
                        Text('inativo',
                            style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? AppColors.slate500
                                    : AppColors.slate400)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    _InlineStats(
                      player: player,
                      icons: icons,
                      isDark: isDark,
                      classificationMode: classificationMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // WR bar or points
              classificationMode
                  ? SizedBox(
                      width: 52,
                      child: Text(
                        '${player.points} pts',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.slate900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  : SizedBox(
                      width: 90, child: _WRBar(value: wr, isDark: isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStats extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final GroupIcons icons;
  final bool isDark;
  final bool classificationMode;

  const _InlineStats({
    required this.player,
    required this.icons,
    required this.isDark,
    required this.classificationMode,
  });

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? AppColors.slate500 : AppColors.slate400;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 10,
          color: dim,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        children: classificationMode
            ? [
                TextSpan(text: '${player.gamesPlayed}j '),
                TextSpan(
                    text: '${player.wins}V',
                    style: const TextStyle(
                        color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                TextSpan(text: ' ${player.ties}E '),
                TextSpan(
                    text: '${player.losses}D',
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                TextSpan(text: ' Â· âš½${_rankText(player.goalsRank)}'),
                TextSpan(text: ' Â· ðŸ¤${_rankText(player.assistsRank)}'),
                TextSpan(text: ' Â· MVP ${_rankText(player.mvpsRank)}'),
                TextSpan(text: ' Â· Votos ${_rankText(player.mvpVotesRank)}'),
                TextSpan(
                    text:
                        ' Â· GC ${player.ownGoals > 0 ? _rankText(player.ownGoalsRank) : 'â€”'}'),
              ]
            : [
                TextSpan(text: '${player.gamesPlayed}j '),
                TextSpan(
                    text: '${player.wins}V',
                    style: const TextStyle(
                        color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                TextSpan(text: ' ${player.ties}E '),
                TextSpan(
                    text: '${player.losses}D',
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                if (player.mvps > 0) TextSpan(text: ' · 🏆${player.mvps}'),
                if (player.goals > 0) TextSpan(text: ' · ⚽${player.goals}'),
                if (player.assists > 0)
                  TextSpan(text: ' · 🤝${player.assists}'),
                if (player.mvpVotes > 0)
                  TextSpan(text: ' · ${player.mvpVotes} votos'),
              ],
      ),
    );
  }
}

// ── Players content ───────────────────────────────────────────────────────────

class _PlayersContent extends StatelessWidget {
  final PlayerVisualStatsReport report;
  final List<PlayerVisualStatsItem> sorted;
  final _SortKey sortKey;
  final String search;
  final TextEditingController searchCtrl;
  final GroupIcons icons;
  final ValueChanged<_SortKey> onSort;
  final ValueChanged<String> onSearch;

  const _PlayersContent({
    required this.report,
    required this.sorted,
    required this.sortKey,
    required this.search,
    required this.searchCtrl,
    required this.icons,
    required this.onSort,
    required this.onSearch,
  });

  void _showDetail(BuildContext context, PlayerVisualStatsItem player) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerDetailSheet(
        player: player,
        icons: icons,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _card(isDark,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _searchField(isDark, searchCtrl, onSearch),
                  const SizedBox(height: 8),
                  _sortChips(
                    isDark,
                    sortKey,
                    icons,
                    onSort,
                    classificationMode: false,
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: isDark ? AppColors.slate700 : AppColors.slate100),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: Text('Nenhum jogador encontrado.',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400))),
              )
            else
              ...sorted.map((p) => _PlayerListItem(
                    player: p,
                    icons: icons,
                    isDark: isDark,
                    onTap: () => _showDetail(context, p),
                  )),
          ],
        ));
  }
}

// ── Player detail bottom sheet ────────────────────────────────────────────────

class _PlayerDetailSheet extends StatefulWidget {
  final PlayerVisualStatsItem player;
  final GroupIcons icons;
  final bool isDark;

  const _PlayerDetailSheet({
    required this.player,
    required this.icons,
    required this.isDark,
  });

  @override
  State<_PlayerDetailSheet> createState() => _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends State<_PlayerDetailSheet> {
  int _minTogether = 1;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.slate900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlayerDetailCard(
                    player: widget.player,
                    icons: widget.icons,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 14),
                  _SynergyCard(
                    player: widget.player,
                    minTogether: _minTogether,
                    icons: widget.icons,
                    isDark: widget.isDark,
                    onMinChange: (v) => setState(() => _minTogether = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player list item ──────────────────────────────────────────────────────────

class _PlayerListItem extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final GroupIcons icons;
  final bool isDark;
  final VoidCallback onTap;

  const _PlayerListItem({
    required this.player,
    required this.icons,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wr = _normalizeWR(player.winRate);
    final wrCol = _wrColor(wr);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              )),
            ),
            const SizedBox(width: 10),
            // Name + sub
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (player.isGoalkeeper) ...[
                    renderGroupIcon(icons.goalkeeper,
                        size: 11,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                      child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.slate900),
                  )),
                ]),
                Text(
                  '${player.gamesPlayed}j · ${player.wins}V${player.ties}E${player.losses}D',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            )),
            // WR % + chevron
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_pct(wr),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: wrCol,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? AppColors.slate600 : AppColors.slate300),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Player detail card ────────────────────────────────────────────────────────

class _PlayerDetailCard extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final GroupIcons icons;
  final bool isDark;

  const _PlayerDetailCard({
    required this.player,
    required this.icons,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final wr = _normalizeWR(player.winRate);
    final col = _wrColor(wr);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WR color strip
          Container(height: 3, color: col),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : AppColors.slate900,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text(
                        player.name.isNotEmpty
                            ? player.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.slate900 : Colors.white,
                        ),
                      )),
                    ),
                    const SizedBox(width: 12),
                    // Name + badges + inline stats
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(player.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                  letterSpacing: -0.3,
                                )),
                            if (player.isGoalkeeper)
                              _pillBadge(
                                label: 'Goleiro',
                                icon: Icons.shield_outlined,
                                bg: const Color(0xFFFEF3C7),
                                fg: const Color(0xFFB45309),
                                border: const Color(0xFFFDE68A),
                              ),
                            if (!player.isActive)
                              _pillBadge(
                                label: 'Inativo',
                                bg: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate100,
                                fg: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
                                border: isDark
                                    ? AppColors.slate700
                                    : AppColors.slate200,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Inline stats
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _statChip(
                                '${player.gamesPlayed} jogos',
                                isDark
                                    ? AppColors.slate300
                                    : AppColors.slate600),
                            _statChip(
                                '${player.wins}V', const Color(0xFF16A34A),
                                bold: true),
                            _statChip(
                                '${player.ties}E',
                                isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500),
                            _statChip(
                                '${player.losses}D', const Color(0xFFEF4444),
                                bold: true),
                            if (player.mvps > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                renderGroupIcon(icons.mvp,
                                    size: 11, color: const Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                _statChip(
                                    '${player.mvps} MVP${player.mvps > 1 ? 's' : ''}',
                                    const Color(0xFFF59E0B),
                                    bold: true),
                              ]),
                            if (player.goals > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                renderGroupIcon(icons.goal,
                                    size: 11,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate600),
                                const SizedBox(width: 3),
                                _statChip(
                                    '${player.goals}',
                                    isDark
                                        ? AppColors.slate400
                                        : AppColors.slate600),
                              ]),
                            if (player.assists > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                renderGroupIcon(icons.assist,
                                    size: 11,
                                    color: isDark
                                        ? AppColors.slate400
                                        : AppColors.slate600),
                                const SizedBox(width: 3),
                                _statChip(
                                    '${player.assists}',
                                    isDark
                                        ? AppColors.slate400
                                        : AppColors.slate600),
                              ]),
                            if (player.ownGoals > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                renderGroupIcon(icons.ownGoal,
                                    size: 11, color: const Color(0xFFEF4444)),
                                const SizedBox(width: 3),
                                _statChip('${player.ownGoals} GC',
                                    const Color(0xFFEF4444)),
                              ]),
                          ],
                        ),
                      ],
                    )),
                    // Big WR
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_pct(wr),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: col,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              )),
                          Text('Win Rate',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.8,
                                color: isDark
                                    ? AppColors.slate500
                                    : AppColors.slate400,
                              )),
                        ]),
                  ],
                ),
                const SizedBox(height: 14),
                // WDL proportion bar
                _WDLBar(
                  wins: player.wins,
                  ties: player.ties,
                  losses: player.losses,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color, {bool bold = false}) => Text(text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ));

  Widget _pillBadge({
    required String label,
    IconData? icon,
    required Color bg,
    required Color fg,
    required Color border,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500, color: fg)),
        ]),
      );
}

// ── Synergy card ──────────────────────────────────────────────────────────────

class _SynergyCard extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final int minTogether;
  final GroupIcons icons;
  final bool isDark;
  final ValueChanged<int> onMinChange;

  const _SynergyCard({
    required this.player,
    required this.minTogether,
    required this.icons,
    required this.isDark,
    required this.onMinChange,
  });

  @override
  Widget build(BuildContext context) {
    final synergies = (player.synergies)
        .map((s) => (s, _normalizeWR(s.winRateTogether)))
        .where((t) => t.$1.matchesTogether >= minTogether)
        .toList()
      ..sort((a, b) => b.$2 != a.$2
          ? b.$2.compareTo(a.$2)
          : b.$1.matchesTogether.compareTo(a.$1.matchesTogether));

    return _card(isDark,
        child: Column(
          children: [
            // Header with filter dropdown
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 15,
                      color: isDark ? AppColors.slate500 : AppColors.slate400),
                  const SizedBox(width: 8),
                  Text('Sinergias',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate100 : AppColors.slate800,
                      )),
                  const SizedBox(width: 6),
                  Text(
                    '${synergies.length} parceiro${synergies.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppColors.slate500 : AppColors.slate400),
                  ),
                  const Spacer(),
                  // Min filter
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Mín.',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400)),
                    const SizedBox(width: 6),
                    DropdownButton<int>(
                      value: minTogether,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: isDark ? AppColors.slate800 : Colors.white,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate100 : AppColors.slate900,
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1+ j')),
                        DropdownMenuItem(value: 2, child: Text('2+ j')),
                        DropdownMenuItem(value: 3, child: Text('3+ j')),
                        DropdownMenuItem(value: 5, child: Text('5+ j')),
                        DropdownMenuItem(value: 8, child: Text('8+ j')),
                      ],
                      onChanged: (v) {
                        if (v != null) onMinChange(v);
                      },
                    ),
                  ]),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: isDark ? AppColors.slate700 : AppColors.slate100),
            if (synergies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                    child: Text('Sem sinergias com esse filtro.',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.slate500
                                : AppColors.slate400))),
              )
            else
              ...synergies.map((t) {
                final s = t.$1;
                final wr = t.$2;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color:
                                isDark ? AppColors.slate700 : AppColors.slate50,
                            width: 0.5)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    // Partner avatar
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate800 : AppColors.slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text(
                        s.withPlayerName.isNotEmpty
                            ? s.withPlayerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate600),
                      )),
                    ),
                    const SizedBox(width: 10),
                    // Name + games
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.withPlayerName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.slate900)),
                        Text('${s.matchesTogether}j · ${s.winsTogether}V',
                            style: TextStyle(
                                fontSize: 10,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                color: isDark
                                    ? AppColors.slate500
                                    : AppColors.slate400)),
                      ],
                    )),
                    const SizedBox(width: 12),
                    // WR bar
                    SizedBox(
                        width: 110, child: _WRBar(value: wr, isDark: isDark)),
                  ]),
                );
              }),
          ],
        ));
  }
}

// ── Best pairs row ────────────────────────────────────────────────────────────

class _SynergyPairRow extends StatelessWidget {
  final int idx;
  final _GlobalSynergyRow row;
  final bool isDark;
  const _SynergyPairRow(
      {required this.idx, required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: isDark ? AppColors.slate700 : AppColors.slate50,
                  width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(
            width: 24,
            child: Text('$idx',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
        Expanded(
            child: Row(children: [
          Flexible(
              child: Text(row.aName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.slate900))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('+',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate600 : AppColors.slate300)),
          ),
          Flexible(
              child: Text(row.bName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.slate900))),
        ])),
        const SizedBox(width: 8),
        Text('${row.matches}j · ${row.wins}V',
            style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
                fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 10),
        SizedBox(width: 110, child: _WRBar(value: row.wr, isDark: isDark)),
      ]),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

/// Proportional W/E/D bar (3 segments)
class _WDLBar extends StatelessWidget {
  final int wins, ties, losses;
  final bool isDark;
  const _WDLBar(
      {required this.wins,
      required this.ties,
      required this.losses,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = wins + ties + losses;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(4)),
      );
    }
    final wF = wins / total;
    final tF = ties / total;
    final lF = losses / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(children: [
          if (wF > 0)
            Flexible(
                flex: (wF * 1000).round(),
                child: Container(color: const Color(0xFF16A34A))),
          if (tF > 0)
            Flexible(
                flex: (tF * 1000).round(),
                child: Container(color: const Color(0xFF94A3B8))),
          if (lF > 0)
            Flexible(
                flex: (lF * 1000).round(),
                child: Container(color: const Color(0xFFDC2626))),
        ]),
      ),
    );
  }
}

/// WR progress bar + % label
class _WRBar extends StatelessWidget {
  final double value; // 0–100
  final bool isDark;
  const _WRBar({required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final col = _wrColor(value);
    return Row(children: [
      Expanded(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(children: [
            Container(color: isDark ? AppColors.slate800 : AppColors.slate100),
            FractionallySizedBox(
              widthFactor: (value / 100).clamp(0, 1),
              child: Container(color: col),
            ),
          ]),
        ),
      )),
      const SizedBox(width: 6),
      SizedBox(
          width: 36,
          child: Text(_pct(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: col,
                  fontFeatures: const [FontFeature.tabularFigures()]))),
    ]);
  }
}

// ── Shared search + sort helpers ──────────────────────────────────────────────

Widget _searchField(bool isDark, TextEditingController ctrl,
        ValueChanged<String> onSearch) =>
    TextField(
      controller: ctrl,
      onChanged: onSearch,
      style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.slate100 : AppColors.slate900),
      decoration: InputDecoration(
        hintText: 'Buscar jogador…',
        hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.slate500 : AppColors.slate400),
        prefixIcon: Icon(Icons.search_rounded,
            size: 16, color: isDark ? AppColors.slate500 : AppColors.slate400),
        isDense: true,
        filled: true,
        fillColor: isDark ? AppColors.slate800 : AppColors.slate50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
                color: isDark ? AppColors.slate700 : AppColors.slate200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.blue500, width: 1.5)),
      ),
    );

Widget _sortChips(
  bool isDark,
  _SortKey current,
  GroupIcons icons,
  ValueChanged<_SortKey> onSort, {
  required bool classificationMode,
}) =>
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _SortKey.values
            .where((k) => classificationMode || k != _SortKey.points)
            .map((k) {
          final active = k == current;
          Widget label;
          switch (k) {
            case _SortKey.goals:
              label = renderGroupIcon(icons.goal, size: 12);
              break;
            case _SortKey.assists:
              label = renderGroupIcon(icons.assist, size: 12);
              break;
            case _SortKey.ownGoals:
              label = renderGroupIcon(icons.ownGoal, size: 12);
              break;
            default:
              label = Text(k.shortLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? (isDark ? AppColors.slate900 : Colors.white)
                          : (isDark
                              ? AppColors.slate400
                              : AppColors.slate600)));
          }
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: GestureDetector(
              onTap: () => onSort(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark ? Colors.white : AppColors.slate900)
                      : (isDark ? AppColors.slate800 : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? (isDark ? Colors.white : AppColors.slate900)
                        : (isDark ? AppColors.slate700 : AppColors.slate200),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: label,
              ),
            ),
          );
        }).toList(),
      ),
    );

// ── Card wrapper ──────────────────────────────────────────────────────────────

Widget _card(bool isDark, {required Widget child}) => Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

Widget _cardHeader(
  bool isDark, {
  required IconData icon,
  required String title,
  String? sub,
  required Widget? child,
}) =>
    Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      color: isDark ? AppColors.slate900 : AppColors.slate50,
      child: Row(children: [
        Icon(icon,
            size: 15, color: isDark ? AppColors.slate400 : AppColors.slate500),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate100 : AppColors.slate800,
            )),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Text(sub,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
        ],
        if (child != null) ...[const Spacer(), child],
      ]),
    );

// ── Skeleton / Error / No-group states ───────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.slate800 : AppColors.slate100;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Column(children: [
            Container(
                height: 280,
                decoration: BoxDecoration(
                    color: base, borderRadius: BorderRadius.circular(14))),
            const SizedBox(height: 14),
            Container(
                height: 160,
                decoration: BoxDecoration(
                    color: base, borderRadius: BorderRadius.circular(14))),
          ]),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Text(message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9B1239))),
        ),
      );
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.slate500),
          SizedBox(height: 12),
          Text('Crie ou entre em um grupo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate400, fontSize: 13)),
        ]),
      );
}
