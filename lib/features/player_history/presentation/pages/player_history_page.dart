import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../dashboard/domain/entities/my_player.dart';
import '../../domain/entities/player_history_models.dart';
import '../providers/player_history_provider.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class PlayerHistoryPage extends ConsumerStatefulWidget {
  const PlayerHistoryPage({super.key});

  @override
  ConsumerState<PlayerHistoryPage> createState() => _PlayerHistoryPageState();
}

class _PlayerHistoryPageState extends ConsumerState<PlayerHistoryPage> {
  MyPlayer? _selectedPlayer;
  late int _selectedYear;

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
      return const Scaffold(body: _NoGroupState());
    }

    final playersAsync = ref.watch(myPlayersProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _onRefresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context)),

            // ── Selectors ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSelectors(context, playersAsync, groupId),
            ),

            // ── History content ──────────────────────────────────────
            if (_selectedPlayer != null)
              _buildHistorySliver(context, groupId)
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

  Widget _buildHeader(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: const Icon(Icons.history_rounded,
                    size: 26, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meu Histórico',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedPlayer != null
                        ? _selectedPlayer!.playerName
                        : 'Selecione um jogador',
                    style: TextStyle(
                      color: Colors.white.withAlpha(160),
                      fontSize: 12,
                    ),
                  ),
                ],
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
            child: _buildPlayerDropdown(context, playersAsync, isDark),
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
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
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
              const Icon(Icons.error_outline, size: 16, color: Colors.red),
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
              dropdownColor: isDark ? AppColors.slate800 : Colors.white,
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
                color: isDark ? Colors.white : AppColors.slate900,
              ),
              icon: Icon(Icons.expand_more_rounded,
                  size: 18,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
              items: players
                  .map((p) => DropdownMenuItem<MyPlayer>(
                        value: p,
                        child: Text(
                          p.playerName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.slate900,
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
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          isDense: true,
          dropdownColor: isDark ? AppColors.slate800 : Colors.white,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.slate900,
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
                        color: isDark ? Colors.white : AppColors.slate900,
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

  Widget _buildHistorySliver(BuildContext context, String groupId) {
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
                backgroundColor: Colors.red,
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
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCard(summary: summary),
                const SizedBox(height: 16),
                _MatchList(items: items),
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
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF3B82F6)],
              ),
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
                      color: const Color(0xFF16A34A),
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
                      color: const Color(0xFFDC2626),
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
                      color: const Color(0xFF22C55E),
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.totalAssists}',
                      label: 'Assist.',
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                    _statPill(
                      value: '${summary.totalMvps}',
                      label: 'MVPs',
                      color: const Color(0xFFFBBF24),
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
    required Color color,
    required bool isDark,
  }) =>
      Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
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

class _MatchList extends StatelessWidget {
  final List<MatchHistoryItem> items;
  const _MatchList({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
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
          ...items.map((item) => _MatchRow(item: item, isDark: isDark)),
        ],
      ),
    );
  }
}

// ── Match row ─────────────────────────────────────────────────────────────────

class _MatchRow extends StatelessWidget {
  final MatchHistoryItem item;
  final bool isDark;
  const _MatchRow({required this.item, required this.isDark});

  Color get _resultColor {
    if (item.isWin) return const Color(0xFF16A34A);
    if (item.isLoss) return const Color(0xFFDC2626);
    return isDark ? AppColors.slate500 : AppColors.slate400;
  }

  String get _resultLabel {
    if (item.isWin) return 'V';
    if (item.isLoss) return 'D';
    return 'E';
  }

  String get _resultFull {
    if (item.isWin) return 'Vitória';
    if (item.isLoss) return 'Derrota';
    return 'Empate';
  }

  Color get _resultBg {
    if (item.isWin) return const Color(0xFFDCFCE7);
    if (item.isLoss) return const Color(0xFFFFF1F2);
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

          // Date + place + result label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDate(item.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _resultFull,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _resultColor,
                      ),
                    ),
                  ],
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
                          icon: Icons.sports_soccer_rounded,
                          value: '${item.goals}',
                          color: const Color(0xFF22C55E),
                        ),
                      if (item.assists > 0)
                        _miniStat(
                          icon: Icons.assistant_rounded,
                          value: '${item.assists}',
                          color: const Color(0xFF3B82F6),
                        ),
                      if (item.isMvp)
                        _miniStat(
                          icon: Icons.emoji_events_rounded,
                          value: 'MVP',
                          color: const Color(0xFFFBBF24),
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
              Text(
                '${item.teamAScore} × ${item.teamBScore}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              _teamColorDots(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String value,
    required Color color,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );

  Widget _teamColorDots(BuildContext context) {
    Color? colorA = _hexColor(item.teamAColor);
    Color? colorB = _hexColor(item.teamBColor);

    if (colorA == null && colorB == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (colorA != null)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorA,
              border: Border.all(color: Colors.white.withAlpha(80), width: 1),
            ),
          ),
        if (colorA != null && colorB != null) const SizedBox(width: 3),
        if (colorB != null)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorB,
              border: Border.all(color: Colors.white.withAlpha(80), width: 1),
            ),
          ),
      ],
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
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9B1239)),
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
