import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../domain/entities/player_history_models.dart';
import '../providers/player_history_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class PlayerHistoryPage extends ConsumerStatefulWidget {
  const PlayerHistoryPage({super.key});

  @override
  ConsumerState<PlayerHistoryPage> createState() => _PlayerHistoryPageState();
}

enum _HistoryResultFilter { all, wins, draws, losses }

class _PlayerHistoryPageState extends ConsumerState<PlayerHistoryPage> {
  MyPlayer? _selectedPlayer;
  late int _selectedYear;
  _HistoryResultFilter _resultFilter = _HistoryResultFilter.all;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  void _onRefresh() {
    // Invalidate players list and history
    ref.invalidate(myPlayersProvider);
    final groupId = ref.read(accountStoreProvider).activeAccount?.activeGroupId;
    if (groupId != null && _selectedPlayer != null) {
      ref.invalidate(playerHistoryProvider((
        groupId: groupId,
        playerId: _selectedPlayer!.playerId,
        year: _selectedYear,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountStoreProvider).activeAccount;
    final groupId = account?.activeGroupId;

    if (groupId == null || groupId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Meu histórico'),
        ),
        body: const _NoGroupState(),
      );
    }

    final playersAsync = ref.watch(myPlayersProvider);
    final icons = GroupIcons.from(
      ref.watch(groupSettingsProvider(groupId)).valueOrNull,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _onRefresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context, icons)),

            // ── Selectors ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSelectors(context, playersAsync, groupId, icons),
            ),

            // ── History content ──────────────────────────────────────
            if (_selectedPlayer != null)
              _buildHistorySliver(context, groupId, icons)
            else
              SliverToBoxAdapter(
                child: _buildPickPlayerPrompt(context),
              ),
          ],
        ),
      ),
    );
  }

  // ── Dark gradient header ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, GroupIcons icons) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightText,
            AppColors.darkCard,
            AppColors.lightText
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/app');
                  }
                },
                tooltip: 'Voltar',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.onDark.withAlpha(20),
                  foregroundColor: AppColors.onDark,
                  side: BorderSide(color: AppColors.onDark.withAlpha(40)),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.onDark.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.onDark.withAlpha(50)),
                ),
                child: const Icon(Icons.history_rounded,
                    size: 26, color: AppColors.onDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meu Histórico',
                      style: TextStyle(
                        color: AppColors.onDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_selectedPlayer != null)
                      PlayerNameWithIcon(
                        name: _selectedPlayer!.playerName,
                        icons: icons,
                        isGoalkeeper: _selectedPlayer!.isGoalkeeper,
                        iconSize: 10,
                        style: TextStyle(
                          color: AppColors.onDark.withAlpha(160),
                          fontSize: 12,
                        ),
                      )
                    else
                      Text(
                        'Selecione um jogador',
                        style: TextStyle(
                          color: AppColors.onDark.withAlpha(160),
                          fontSize: 12,
                        ),
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

  // ── Selectors row ─────────────────────────────────────────────────────────

  Widget _buildSelectors(
    BuildContext context,
    AsyncValue<List<MyPlayer>> playersAsync,
    String groupId,
    GroupIcons icons,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentYear = DateTime.now().year;
    final years = List.generate(4, (i) => currentYear - i);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Player dropdown
          Expanded(
            child: _buildPlayerDropdown(
              context,
              playersAsync,
              isDark,
              icons,
            ),
          ),
          const SizedBox(width: 10),
          // Year dropdown
          _buildYearDropdown(context, years, isDark),
        ],
      ),
    );
  }

  Widget _buildPlayerDropdown(
    BuildContext context,
    AsyncValue<List<MyPlayer>> playersAsync,
    bool isDark,
    GroupIcons icons,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: playersAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Carregando...', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        error: (e, _) => SizedBox(
          height: 40,
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 16, color: AppColors.prototypeDanger),
              const SizedBox(width: 6),
              Text('Erro',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate400 : AppColors.slate500)),
            ],
          ),
        ),
        data: (players) {
          if (players.isEmpty) {
            return SizedBox(
              height: 40,
              child: Text(
                'Nenhum jogador',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            );
          }

          // Auto-select first player if none selected
          if (_selectedPlayer == null && players.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedPlayer = players.first);
            });
          }

          return DropdownButtonHideUnderline(
            child: DropdownButton<MyPlayer>(
              value: _selectedPlayer,
              isExpanded: true,
              isDense: true,
              dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
              hint: Text(
                'Selecionar jogador',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.onDark : AppColors.slate900,
              ),
              icon: Icon(Icons.expand_more_rounded,
                  size: 18,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              items: players
                  .map((p) => DropdownMenuItem<MyPlayer>(
                        value: p,
                        child: PlayerNameWithIcon(
                          name: p.playerName,
                          icons: icons,
                          isGoalkeeper: p.isGoalkeeper,
                          iconSize: 11,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? AppColors.onDark : AppColors.slate900,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (p) {
                if (p != null) setState(() => _selectedPlayer = p);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearDropdown(
    BuildContext context,
    List<int> years,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          isDense: true,
          dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.onDark : AppColors.slate900,
          ),
          icon: Icon(Icons.expand_more_rounded,
              size: 18,
              color: isDark ? AppColors.slate400 : AppColors.slate500),
          items: years
              .map((y) => DropdownMenuItem<int>(
                    value: y,
                    child: Text(
                      '$y',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.onDark : AppColors.slate900,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (y) {
            if (y != null) setState(() => _selectedYear = y);
          },
        ),
      ),
    );
  }

  // ── History sliver ────────────────────────────────────────────────────────

  Widget _buildHistorySliver(
    BuildContext context,
    String groupId,
    GroupIcons icons,
  ) {
    final player = _selectedPlayer!;
    final args = (
      groupId: groupId,
      playerId: player.playerId,
      year: _selectedYear,
    );
    final historyAsync = ref.watch(playerHistoryProvider(args));

    return historyAsync.when(
      loading: () => const SliverToBoxAdapter(child: _SkeletonLoader()),
      error: (e, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao carregar histórico: $e'),
                backgroundColor: AppColors.prototypeDanger,
              ),
            );
          }
        });
        return SliverToBoxAdapter(
          child: _ErrorState(message: extractDioError(e)),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyState());
        }
        final summary = PlayerHistorySummary.from(items);
        final filteredItems = switch (_resultFilter) {
          _HistoryResultFilter.all => items,
          _HistoryResultFilter.wins =>
            items.where((item) => item.isWin).toList(),
          _HistoryResultFilter.draws =>
            items.where((item) => item.isDraw).toList(),
          _HistoryResultFilter.losses =>
            items.where((item) => item.isLoss).toList(),
        };
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(summary: summary, icons: icons),
                const SizedBox(height: 16),
                _HistoryResultFilters(
                  selected: _resultFilter,
                  summary: summary,
                  onSelected: (filter) =>
                      setState(() => _resultFilter = filter),
                ),
                const SizedBox(height: 12),
                if (filteredItems.isEmpty)
                  const _FilteredMatchesEmptyState()
                else
                  _MatchList(items: filteredItems, icons: icons),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickPlayerPrompt(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              size: 52,
              color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 16),
          Text(
            'Selecione um jogador para ver o histórico.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final PlayerHistorySummary summary;
  final GroupIcons icons;

  const _SummaryCard({
    required this.summary,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isDark ? AppColors.warningLight : AppColors.accent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESUMO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                // Match counts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statPill(
                      value: '${summary.totalMatches}',
                      label: 'Jogos',
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.wins}',
                      label: 'Vitórias',
                      color: AppColors.primaryPressed,
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.draws}',
                      label: 'Empates',
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.losses}',
                      label: 'Derrotas',
                      color: AppColors.prototypeDanger,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                ),
                const SizedBox(height: 12),
                // Scoring stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statPill(
                      value: '${summary.totalGoals}',
                      label: 'Gols',
                      icon: icons.goal,
                      color: AppColors.accent,
                      valueColor:
                          isDark ? AppColors.slate100 : AppColors.slate900,
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.totalAssists}',
                      label: 'Assist.',
                      icon: icons.assist,
                      color: AppColors.info,
                      valueColor:
                          isDark ? AppColors.slate100 : AppColors.slate900,
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.totalMvps}',
                      label: 'MVPs',
                      icon: icons.mvp,
                      color: AppColors.warning,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required String value,
    required String label,
    String? icon,
    required Color color,
    Color? valueColor,
    required bool isDark,
  }) =>
      Column(
        children: [
          if (icon != null) ...[
            renderGroupIcon(icon, size: 14, color: color),
            const SizedBox(height: 3),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor ?? color,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.4,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
      );
}

// ── Match list ────────────────────────────────────────────────────────────────

class _HistoryResultFilters extends StatelessWidget {
  final _HistoryResultFilter selected;
  final PlayerHistorySummary summary;
  final ValueChanged<_HistoryResultFilter> onSelected;

  const _HistoryResultFilters({
    required this.selected,
    required this.summary,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _ResultFilterChip(
            label: 'Todas',
            count: summary.totalMatches,
            color: isDark ? AppColors.slate300 : AppColors.slate600,
            selected: selected == _HistoryResultFilter.all,
            onTap: () => onSelected(_HistoryResultFilter.all),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ResultFilterChip(
            label: 'Vitórias',
            count: summary.wins,
            color: AppColors.primaryPressed,
            selected: selected == _HistoryResultFilter.wins,
            onTap: () => onSelected(_HistoryResultFilter.wins),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ResultFilterChip(
            label: 'Empates',
            count: summary.draws,
            color: isDark ? AppColors.slate300 : AppColors.slate600,
            selected: selected == _HistoryResultFilter.draws,
            onTap: () => onSelected(_HistoryResultFilter.draws),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ResultFilterChip(
            label: 'Derrotas',
            count: summary.losses,
            color: AppColors.prototypeDanger,
            selected: selected == _HistoryResultFilter.losses,
            onTap: () => onSelected(_HistoryResultFilter.losses),
          ),
        ),
      ],
    );
  }
}

class _ResultFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ResultFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withAlpha(isDark ? 42 : 24)
                : (isDark ? AppColors.slate800 : AppColors.onDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color
                  : (isDark ? AppColors.slate700 : AppColors.slate200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? color
                      : (isDark ? AppColors.slate300 : AppColors.slate600),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? color
                      : (isDark ? AppColors.slate400 : AppColors.slate500),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredMatchesEmptyState extends StatelessWidget {
  const _FilteredMatchesEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Text(
        'Nenhuma partida encontrada para este filtro.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.slate400 : AppColors.slate500,
        ),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<MatchHistoryItem> items;
  final GroupIcons icons;

  const _MatchList({
    required this.items,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];
    String? currentMonth;

    for (final item in items) {
      final date = AppDateUtils.parseOrNow(item.date);
      final month = DateFormat('MMMM yyyy', 'pt_BR').format(date);

      if (month != currentMonth) {
        currentMonth = month;
        rows.add(_MonthHeader(label: month, isDark: isDark));
      }

      rows.add(_MatchRow(item: item, isDark: isDark, icons: icons));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.onDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: isDark ? AppColors.slate900 : AppColors.slate50,
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded,
                    size: 15,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
                const SizedBox(width: 8),
                Text(
                  '${items.length} partidas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate100 : AppColors.slate800,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.slate700 : AppColors.slate100,
          ),
          ...rows,
        ],
      ),
    );
  }
}

// ── Match row ─────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String label;
  final bool isDark;

  const _MonthHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 8),
      color: isDark ? AppColors.slate900 : AppColors.slate50,
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? AppColors.slate300 : AppColors.slate600,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final MatchHistoryItem item;
  final bool isDark;
  final GroupIcons icons;

  const _MatchRow({
    required this.item,
    required this.isDark,
    required this.icons,
  });

  Color get _resultColor {
    if (item.isWin) return AppColors.primaryPressed;
    if (item.isLoss) return AppColors.prototypeDanger;
    return isDark ? AppColors.slate500 : AppColors.slate400;
  }

  String get _resultLabel {
    if (item.isWin) return 'V';
    if (item.isLoss) return 'D';
    return 'E';
  }

  Color get _resultBg {
    if (item.isWin) return AppColors.green100;
    if (item.isLoss) return AppColors.rose50;
    return isDark ? AppColors.slate700 : AppColors.slate100;
  }

  String _formatDate(String raw) {
    try {
      final dt = AppDateUtils.parseOrNow(raw);
      return DateFormat("dd/MM/yyyy", 'pt_BR').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate700 : AppColors.slate100,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _resultBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _resultLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _resultColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Date + place
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(item.date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.onDark : AppColors.slate900,
                  ),
                ),
                if (item.place != null && item.place!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color:
                              isDark ? AppColors.slate500 : AppColors.slate400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.place!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate500
                                  : AppColors.slate400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Player stats row
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 10,
                    children: [
                      if (item.goals > 0)
                        _miniStat(
                          icon: icons.goal,
                          value: '${item.goals}',
                          color: AppColors.accent,
                        ),
                      if (item.assists > 0)
                        _miniStat(
                          icon: icons.assist,
                          value: '${item.assists}',
                          color: AppColors.info,
                        ),
                      if (item.isMvp)
                        _miniStat(
                          icon: icons.mvp,
                          value: 'MVP',
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _scoreBox(item.teamAScore, _hexColor(item.teamAColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ),
                  _scoreBox(item.teamBScore, _hexColor(item.teamBColor)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String icon,
    required String value,
    required Color color,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          renderGroupIcon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.slate100 : AppColors.slate900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );

  Widget _scoreBox(int score, Color? teamColor) {
    final background =
        teamColor ?? (isDark ? AppColors.slate700 : AppColors.slate100);
    final foreground = background.computeLuminance() > .48
        ? AppColors.slate900
        : AppColors.onDark;

    return Container(
      width: 32,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: background.computeLuminance() > .72
              ? AppColors.slate400
              : background.withAlpha(220),
        ),
      ),
      child: Text(
        '$score',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
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

// ── Skeleton / Empty / Error / No-group ───────────────────────────────────────

class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
          child: Column(
            children: [
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 14),
              ...List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_soccer_outlined,
            size: 52,
            color: isDark ? AppColors.slate600 : AppColors.slate300,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma partida encontrada.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.slate400 : AppColors.slate500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tente selecionar outro ano ou jogador.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
        ],
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
          child: Text(
            message,
            style:
                const TextStyle(fontSize: 13, color: AppColors.prototypeDanger),
          ),
        ),
      );
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: AppColors.slate500),
            SizedBox(height: 12),
            Text(
              'Crie ou entre em um grupo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate400, fontSize: 13),
            ),
          ],
        ),
      );
}
