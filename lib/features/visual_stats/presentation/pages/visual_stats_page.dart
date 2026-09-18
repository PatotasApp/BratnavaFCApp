import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/visual_stats_report.dart';
import '../../domain/utils/competition_ranking.dart';
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
  if (v >= 60) return AppColors.primaryPressed;
  if (v >= 45) return AppColors.warningLight;
  return AppColors.prototypeDanger;
}

String _pct(double v) => '${v.toStringAsFixed(0)}%';

double _perGame(num value, int gamesPlayed) =>
    gamesPlayed > 0 ? value / gamesPlayed : 0;

String _perGameText(num value, int gamesPlayed) =>
    _perGame(value, gamesPlayed).toStringAsFixed(2).replaceAll('.', ',');

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

enum _ClassificationMetric {
  points,
  winRate,
  games,
  wins,
  ties,
  losses,
  goals,
  assists,
  mvps,
  mvpVotes,
  ownGoals,
}

class _ClassificationRanks {
  final Map<_ClassificationMetric, Map<String, int>> _values;

  _ClassificationRanks(List<PlayerVisualStatsItem> players)
      : _values = {
          for (final metric in _ClassificationMetric.values)
            metric: _build(players, metric),
        };

  static num _metricValue(
    PlayerVisualStatsItem player,
    _ClassificationMetric metric,
  ) =>
      switch (metric) {
        _ClassificationMetric.points => calculateClassificationPoints(
            wins: player.wins,
            ties: player.ties,
          ),
        _ClassificationMetric.winRate => _normalizeWR(player.winRate),
        _ClassificationMetric.games => player.gamesPlayed,
        _ClassificationMetric.wins => player.wins,
        _ClassificationMetric.ties => player.ties,
        _ClassificationMetric.losses => player.losses,
        _ClassificationMetric.goals => player.goals,
        _ClassificationMetric.assists => player.assists,
        _ClassificationMetric.mvps => player.mvps,
        _ClassificationMetric.mvpVotes => player.mvpVotes,
        _ClassificationMetric.ownGoals => player.ownGoals,
      };

  static Map<String, int> _build(
    List<PlayerVisualStatsItem> players,
    _ClassificationMetric metric,
  ) =>
      buildCompetitionRanks<PlayerVisualStatsItem, String>(
        items: players,
        keyOf: (player) => player.playerId,
        valueOf: (player) => _metricValue(player, metric),
        tieBreaker: (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

  int rank(PlayerVisualStatsItem player, _ClassificationMetric metric) =>
      _values[metric]?[player.playerId] ?? 0;

  String text(PlayerVisualStatsItem player, _ClassificationMetric metric) {
    final value = rank(player, metric);
    return value > 0 ? '$valueº' : '—';
  }
}

_ClassificationMetric _classificationMetricFor(_SortKey key) => switch (key) {
      _SortKey.points => _ClassificationMetric.points,
      _SortKey.winRate => _ClassificationMetric.winRate,
      _SortKey.wins => _ClassificationMetric.wins,
      _SortKey.games => _ClassificationMetric.games,
      _SortKey.mvps => _ClassificationMetric.mvps,
      _SortKey.mvpVotes => _ClassificationMetric.mvpVotes,
      _SortKey.goals => _ClassificationMetric.goals,
      _SortKey.assists => _ClassificationMetric.assists,
      _SortKey.ownGoals => _ClassificationMetric.ownGoals,
      _SortKey.name => _ClassificationMetric.points,
    };

extension _SortKeyLabel on _SortKey {
  String label({bool perMatch = false}) {
    if (perMatch) {
      return switch (this) {
        _SortKey.wins => 'Vitórias por jogo',
        _SortKey.mvps => 'MVPs por jogo',
        _SortKey.mvpVotes => 'Votos MVP por jogo',
        _SortKey.goals => 'Gols por jogo',
        _SortKey.assists => 'Assistências por jogo',
        _SortKey.ownGoals => 'Gols contra por jogo',
        _ => label(),
      };
    }

    return switch (this) {
      _SortKey.points => 'Pontos na classificação',
      _SortKey.winRate => 'Aproveitamento',
      _SortKey.wins => 'Vitórias',
      _SortKey.games => 'Jogos disputados',
      _SortKey.mvps => 'MVPs',
      _SortKey.mvpVotes => 'Votos MVP',
      _SortKey.goals => 'Gols',
      _SortKey.assists => 'Assistências',
      _SortKey.ownGoals => 'Gols contra',
      _SortKey.name => 'Nome',
    };
  }
}

Color _sortMetricColor(
  _SortKey key,
  PlayerVisualStatsItem player,
  bool isDark,
) =>
    switch (key) {
      _SortKey.winRate => _wrColor(_normalizeWR(player.winRate)),
      _SortKey.mvps => AppColors.warning,
      _SortKey.ownGoals => player.ownGoals > 0
          ? AppColors.prototypeDanger
          : (isDark ? AppColors.slate200 : AppColors.slate800),
      _SortKey.name => isDark ? AppColors.slate200 : AppColors.slate800,
      _ => AppColors.accent,
    };

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
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    final perMatch = _viewMode == _StatsViewMode.perMatch;
    void compareMetric(num Function(PlayerVisualStatsItem) selector) {
      // Mantém mais jogos como desempate para privilegiar a amostra maior.
      list.sort((a, b) {
        final comparison = selector(b).compareTo(selector(a));
        if (comparison != 0) return comparison;
        return b.gamesPlayed.compareTo(a.gamesPlayed);
      });
    }

    num countMetric(PlayerVisualStatsItem player, int value) =>
        perMatch ? _perGame(value, player.gamesPlayed) : value;

    switch (_sortKey) {
      case _SortKey.points:
        list.sort((a, b) {
          final bPoints = calculateClassificationPoints(
            wins: b.wins,
            ties: b.ties,
          );
          final aPoints = calculateClassificationPoints(
            wins: a.wins,
            ties: a.ties,
          );
          final comparison = bPoints.compareTo(aPoints);
          if (comparison != 0) return comparison;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _SortKey.winRate:
        list.sort((a, b) =>
            _normalizeWR(b.winRate).compareTo(_normalizeWR(a.winRate)));
      case _SortKey.wins:
        compareMetric((p) => countMetric(p, p.wins));
      case _SortKey.games:
        list.sort((a, b) => b.gamesPlayed.compareTo(a.gamesPlayed));
      case _SortKey.mvps:
        compareMetric((p) => countMetric(p, p.mvps));
      case _SortKey.mvpVotes:
        compareMetric((p) => countMetric(p, p.mvpVotes));
      case _SortKey.goals:
        compareMetric((p) => countMetric(p, p.goals));
      case _SortKey.assists:
        compareMetric((p) => countMetric(p, p.assists));
      case _SortKey.ownGoals:
        compareMetric((p) => countMetric(p, p.ownGoals));
      case _SortKey.name:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    // O jogador manda no grupo: `activeGroupId` da conta pode apontar
    // para uma patota sem jogador nosso, e aí toda rota por grupo
    // responde 403. Ver dashboard_page para o diagnóstico completo.
    final groupId = account?.activeGroupId ?? activePlayer?.groupId;

    // Enquanto myPlayersProvider carrega, mostra spinner em vez de "sem grupo"
    if (groupId == null || groupId.isEmpty) {
      final playersAsync = ref.watch(myPlayersProvider);
      if (playersAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const Scaffold(
        body: Column(
          children: [
            AppPageHeader(
              title: 'Estatísticas',
              subtitle: 'Desempenho dos jogadores da patota',
              icon: Icons.bar_chart_rounded,
            ),
            Expanded(
              child: NoActiveGroupView(
                message: 'Selecione uma patota para ver as estatísticas.',
              ),
            ),
          ],
        ),
      );
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
                                backgroundColor: AppColors.transparent,
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
      if (consideredCount > 0 && consideredCount == finalizedCount) {
        subtitle += ' · $consideredCount partidas analisadas';
      } else {
        if (finalizedCount > 0) {
          subtitle += ' · $finalizedCount partidas finalizadas';
        }
        if (consideredCount > 0) {
          subtitle += ' · $consideredCount usadas no ranking';
        }
      }
    }

    return AppPageHeader(
      title: 'Estatísticas',
      subtitle: subtitle,
      icon: Icons.bar_chart_rounded,
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showGeneral)
            ChoiceChip(
              label: const Text('Geral'),
              selected: _viewMode == _StatsViewMode.general,
              onSelected: (_) => setState(() {
                _viewMode = _StatsViewMode.general;
                if (_sortKey == _SortKey.points) {
                  _sortKey = _SortKey.winRate;
                }
              }),
            ),
          if (showPerMatch)
            ChoiceChip(
              label: const Text('Por partida'),
              selected: _viewMode == _StatsViewMode.perMatch,
              onSelected: (_) => setState(() {
                _viewMode = _StatsViewMode.perMatch;
                if (_sortKey == _SortKey.points) {
                  _sortKey = _SortKey.winRate;
                }
              }),
            ),
          if (showClassification)
            ChoiceChip(
              label: const Text('Classificação'),
              selected: _viewMode == _StatsViewMode.classification,
              onSelected: (_) => setState(() {
                _viewMode = _StatsViewMode.classification;
                _sortKey = _SortKey.points;
              }),
            ),
        ],
      ),
    );
  }
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
    final classificationRanks = _ClassificationRanks(report.players);

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
                      _sortSelector(
                        isDark,
                        sortKey,
                        onSort,
                        classificationMode: classificationMode,
                      ),
                      if (classificationMode) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Vitória: 3 pontos · Empate: 1 · Derrota: 0',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        rank: classificationMode
                            ? classificationRanks.rank(
                                e.value,
                                _classificationMetricFor(sortKey),
                              )
                            : e.key + 1,
                        player: e.value,
                        icons: icons,
                        sortKey: sortKey,
                        classificationMode: classificationMode,
                        classificationRanks: classificationRanks,
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
                color: AppColors.transparent,
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
                                renderGroupIcon(
                                  p.isGoalkeeper
                                      ? icons.goalkeeper
                                      : icons.player,
                                  size: 12,
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                    child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.onDark
                                          : AppColors.slate900),
                                )),
                                if (p.mvps > 0) ...[
                                  const SizedBox(width: 3),
                                  renderGroupIcon(icons.mvp,
                                      size: 10, color: AppColors.warning),
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
                                        color: AppColors.primaryPressed,
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
                                        color: AppColors.prototypeDanger,
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
                                              color: AppColors.warning),
                                          const SizedBox(width: 2),
                                          Text('${p.mvps}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.warning,
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
                                            color: AppColors.prototypeDanger,
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
  final _SortKey sortKey;
  final bool classificationMode;
  final _ClassificationRanks classificationRanks;
  final bool isDark;
  final VoidCallback onTap;

  const _RankingListItem({
    required this.rank,
    required this.player,
    required this.icons,
    required this.sortKey,
    required this.classificationMode,
    required this.classificationRanks,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSortKey = classificationMode ? _SortKey.points : sortKey;
    final metricColor = _sortMetricColor(effectiveSortKey, player, isDark);

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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? AppColors.accent
                              .withValues(alpha: isDark ? 0.18 : 0.10)
                          : (isDark ? AppColors.slate800 : AppColors.slate50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$rankº',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3
                            ? AppColors.accent
                            : (isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? AppColors.onDark : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            renderGroupIcon(
                              player.isGoalkeeper
                                  ? icons.goalkeeper
                                  : icons.player,
                              size: 11,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              player.isGoalkeeper ? 'Goleiro' : 'Jogador',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500,
                              ),
                            ),
                            if (!player.isActive) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Inativo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.slate500
                                      : AppColors.slate400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (classificationMode) ...[
                    const SizedBox(width: 8),
                    _ClassificationPointsSummary(
                      points: calculateClassificationPoints(
                        wins: player.wins,
                        ties: player.ties,
                      ),
                      isDark: isDark,
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    _SelectedSortMetric(
                      player: player,
                      sortKey: effectiveSortKey,
                      isDark: isDark,
                      accent: metricColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate900 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: classificationMode
                    ? _ClassificationMetricsGrid(
                        player: player,
                        ranks: classificationRanks,
                        isDark: isDark,
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              _RankingMetric(
                                label: 'Jogos',
                                value: player.gamesPlayed,
                                isDark: isDark,
                              ),
                              _RankingMetric(
                                label: 'Vitórias',
                                value: player.wins,
                                isDark: isDark,
                                valueColor: AppColors.primaryPressed,
                              ),
                              _RankingMetric(
                                label: 'Empates',
                                value: player.ties,
                                isDark: isDark,
                              ),
                              _RankingMetric(
                                label: 'Derrotas',
                                value: player.losses,
                                isDark: isDark,
                                valueColor: AppColors.prototypeDanger,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.slate700
                                  : AppColors.slate200,
                            ),
                          ),
                          Row(
                            children: [
                              _RankingMetric(
                                label: 'Gols',
                                value: player.goals,
                                isDark: isDark,
                              ),
                              _RankingMetric(
                                label: 'Assistências',
                                value: player.assists,
                                isDark: isDark,
                              ),
                              _RankingMetric(
                                label: 'MVPs',
                                value: player.mvps,
                                isDark: isDark,
                                valueColor: AppColors.warning,
                              ),
                              _RankingMetric(
                                label: 'Gols contra',
                                value: player.ownGoals,
                                isDark: isDark,
                                valueColor: player.ownGoals > 0
                                    ? AppColors.prototypeDanger
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassificationPointsSummary extends StatelessWidget {
  final int points;
  final bool isDark;

  const _ClassificationPointsSummary({
    required this.points,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Pontos',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSortMetric extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final _SortKey sortKey;
  final bool isDark;
  final Color accent;
  final bool perMatchMode;

  const _SelectedSortMetric({
    required this.player,
    required this.sortKey,
    required this.isDark,
    required this.accent,
    this.perMatchMode = false,
  });

  @override
  Widget build(BuildContext context) {
    String countValue(int value) =>
        perMatchMode ? _perGameText(value, player.gamesPlayed) : '$value';

    final value = switch (sortKey) {
      _SortKey.points => '${calculateClassificationPoints(
          wins: player.wins,
          ties: player.ties,
        )}',
      _SortKey.winRate => _pct(_normalizeWR(player.winRate)),
      _SortKey.wins => countValue(player.wins),
      _SortKey.games => '${player.gamesPlayed}',
      _SortKey.mvps => countValue(player.mvps),
      _SortKey.mvpVotes => countValue(player.mvpVotes),
      _SortKey.goals => countValue(player.goals),
      _SortKey.assists => countValue(player.assists),
      _SortKey.ownGoals => countValue(player.ownGoals),
      _SortKey.name => 'A–Z',
    };

    return SizedBox(
      width: perMatchMode ? 98 : 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: sortKey == _SortKey.name
                  ? (isDark ? AppColors.slate200 : AppColors.slate800)
                  : accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            sortKey.label(perMatch: perMatchMode),
            maxLines: perMatchMode ? 3 : 2,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9,
              height: 1.15,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingMetric extends StatelessWidget {
  final String label;
  final int value;
  final bool isDark;
  final Color? valueColor;

  const _RankingMetric({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ??
                  (isDark ? AppColors.slate100 : AppColors.slate900),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationMetricsGrid extends StatelessWidget {
  final PlayerVisualStatsItem player;
  final _ClassificationRanks ranks;
  final bool isDark;

  const _ClassificationMetricsGrid({
    required this.player,
    required this.ranks,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            height: 1,
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            _RankingPositionMetric(
              label: 'Jogos',
              position: ranks.text(player, _ClassificationMetric.games),
              isDark: isDark,
            ),
            _RankingPositionMetric(
              label: 'Vitórias',
              position: ranks.text(player, _ClassificationMetric.wins),
              isDark: isDark,
              valueColor: AppColors.primaryPressed,
            ),
            _RankingPositionMetric(
              label: 'Empates',
              position: ranks.text(player, _ClassificationMetric.ties),
              isDark: isDark,
            ),
          ],
        ),
        divider(),
        Row(
          children: [
            _RankingPositionMetric(
              label: 'Derrotas',
              position: ranks.text(player, _ClassificationMetric.losses),
              isDark: isDark,
              valueColor: AppColors.prototypeDanger,
            ),
            _RankingPositionMetric(
              label: 'Gols',
              position: ranks.text(player, _ClassificationMetric.goals),
              isDark: isDark,
            ),
            _RankingPositionMetric(
              label: 'Assistências',
              position: ranks.text(player, _ClassificationMetric.assists),
              isDark: isDark,
            ),
          ],
        ),
        divider(),
        Row(
          children: [
            _RankingPositionMetric(
              label: 'MVPs',
              position: ranks.text(player, _ClassificationMetric.mvps),
              isDark: isDark,
              valueColor: AppColors.warning,
            ),
            _RankingPositionMetric(
              label: 'Votos MVP',
              position: ranks.text(player, _ClassificationMetric.mvpVotes),
              isDark: isDark,
            ),
            _RankingPositionMetric(
              label: 'Gols contra',
              position: player.ownGoals > 0
                  ? ranks.text(player, _ClassificationMetric.ownGoals)
                  : '—',
              isDark: isDark,
              valueColor:
                  player.ownGoals > 0 ? AppColors.prototypeDanger : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _RankingPositionMetric extends StatelessWidget {
  final String label;
  final String position;
  final bool isDark;
  final Color? valueColor;

  const _RankingPositionMetric({
    required this.label,
    required this.position,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            position,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ??
                  (isDark ? AppColors.slate100 : AppColors.slate900),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
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
      backgroundColor: AppColors.transparent,
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
                  _sortSelector(
                    isDark,
                    sortKey,
                    onSort,
                    classificationMode: false,
                    perMatchMode: true,
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
                    sortKey: sortKey,
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
        color: widget.isDark ? AppColors.slate900 : AppColors.onDark,
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
  final _SortKey sortKey;
  final bool isDark;
  final VoidCallback onTap;

  const _PlayerListItem({
    required this.player,
    required this.icons,
    required this.sortKey,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  renderGroupIcon(
                    player.isGoalkeeper ? icons.goalkeeper : icons.player,
                    size: 11,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.onDark : AppColors.slate900),
                  )),
                ]),
                Text(
                  '${player.gamesPlayed} jogos · ${player.wins} vitórias · '
                  '${player.ties} empates · ${player.losses} derrotas',
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            )),
            _SelectedSortMetric(
              player: player,
              sortKey: sortKey,
              isDark: isDark,
              accent: _sortMetricColor(sortKey, player, isDark),
              perMatchMode: true,
            ),
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
        color: isDark ? AppColors.slate800 : AppColors.onDark,
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
                        color: isDark ? AppColors.onDark : AppColors.slate900,
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
                          color: isDark ? AppColors.slate900 : AppColors.onDark,
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
                            renderGroupIcon(
                              player.isGoalkeeper
                                  ? icons.goalkeeper
                                  : icons.player,
                              size: 15,
                              color: isDark
                                  ? AppColors.slate300
                                  : AppColors.slate600,
                            ),
                            Text(player.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.onDark
                                      : AppColors.slate900,
                                  letterSpacing: -0.3,
                                )),
                            if (player.isGoalkeeper)
                              _pillBadge(
                                label: 'Goleiro',
                                icon: Icons.shield_outlined,
                                bg: AppColors.amber50,
                                fg: AppColors.warningLight,
                                border: AppColors.amber200,
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
                                '${player.wins}V', AppColors.primaryPressed,
                                bold: true),
                            _statChip(
                                '${player.ties}E',
                                isDark
                                    ? AppColors.slate400
                                    : AppColors.slate500),
                            _statChip(
                                '${player.losses}D', AppColors.prototypeDanger,
                                bold: true),
                            if (player.mvps > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                renderGroupIcon(icons.mvp,
                                    size: 11, color: AppColors.warning),
                                const SizedBox(width: 3),
                                _statChip(
                                    '${player.mvps} MVP${player.mvps > 1 ? 's' : ''}',
                                    AppColors.warning,
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
                                    size: 11, color: AppColors.prototypeDanger),
                                const SizedBox(width: 3),
                                _statChip('${player.ownGoals} GC',
                                    AppColors.prototypeDanger),
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
                      dropdownColor:
                          isDark ? AppColors.slate800 : AppColors.onDark,
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
                                    ? AppColors.onDark
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
                      color: isDark ? AppColors.onDark : AppColors.slate900))),
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
                      color: isDark ? AppColors.onDark : AppColors.slate900))),
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
                child: Container(color: AppColors.primaryPressed)),
          if (tF > 0)
            Flexible(
                flex: (tF * 1000).round(),
                child: Container(color: AppColors.lightPlaceholder)),
          if (lF > 0)
            Flexible(
                flex: (lF * 1000).round(),
                child: Container(color: AppColors.prototypeDanger)),
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

Widget _sortSelector(
  bool isDark,
  _SortKey current,
  ValueChanged<_SortKey> onSort, {
  required bool classificationMode,
  bool perMatchMode = false,
}) {
  final options = classificationMode
      ? <_SortKey>[
          _SortKey.points,
          _SortKey.winRate,
          _SortKey.wins,
          _SortKey.games,
          _SortKey.mvps,
          _SortKey.mvpVotes,
          _SortKey.goals,
          _SortKey.assists,
          _SortKey.ownGoals,
        ]
      : _SortKey.values.where((key) => key != _SortKey.points).toList();
  final selected = options.contains(current) ? current : options.first;

  return Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: isDark ? AppColors.slate800 : AppColors.onDark,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? AppColors.slate700 : AppColors.slate200,
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.swap_vert_rounded,
          size: 18,
          color: isDark ? AppColors.slate400 : AppColors.slate500,
        ),
        const SizedBox(width: 8),
        Text(
          'Ordenar por',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_SortKey>(
              value: selected,
              isExpanded: true,
              alignment: Alignment.centerRight,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? AppColors.slate300 : AppColors.slate700,
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate100 : AppColors.slate900,
              ),
              items: options
                  .map(
                    (key) => DropdownMenuItem<_SortKey>(
                      value: key,
                      alignment: Alignment.centerRight,
                      child: Text(
                        key.label(perMatch: perMatchMode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onSort(value);
              },
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Card wrapper ──────────────────────────────────────────────────────────────

Widget _card(bool isDark, {required Widget child}) => Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
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
            color: AppColors.rose50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.rose200),
          ),
          child: Text(message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.prototypeDanger)),
        ),
      );
}
