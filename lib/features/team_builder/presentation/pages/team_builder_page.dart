import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/football_pitch.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';
import '../../../../shared/presentation/widgets/no_active_group_view.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
import '../../data/datasources/team_builder_datasource.dart';
import '../../domain/entities/team_builder_models.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _teamBuilderDsProvider = Provider<TeamBuilderDataSource>(
  (ref) => TeamBuilderDataSource(ref.watch(dioProvider)),
);

final _groupPlayersProvider =
    FutureProvider.family<List<TeamBuilderPlayer>, String>(
        (ref, groupId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(ApiConstants.groupById(groupId));
  final raw = res.data;
  final Map<String, dynamic> body =
      (raw is Map<String, dynamic> && raw.containsKey('data'))
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
  final players = (body['players'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .where((p) => p['isGuest'] != true && p['status'] != 'Inactive')
      .map((p) => TeamBuilderPlayer(
            id: (p['id'] ?? '') as String,
            name: (p['name'] ?? '') as String,
            isGoalkeeper: (p['isGoalkeeper'] ?? false) as bool,
          ))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return players;
});

// ── Field position helpers ────────────────────────────────────────────────────

List<Offset> _outfieldPositions(int n) {
  const patterns = <int, List<Offset>>{
    0: [],
    1: [Offset(0.50, 0.40)],
    2: [Offset(0.30, 0.47), Offset(0.70, 0.47)],
    3: [Offset(0.50, 0.32), Offset(0.25, 0.56), Offset(0.75, 0.56)],
    4: [
      Offset(0.30, 0.33),
      Offset(0.70, 0.33),
      Offset(0.22, 0.60),
      Offset(0.78, 0.60)
    ],
  };
  final key = math.min(n, 4);
  return patterns[key] ?? patterns[4]!;
}

List<Offset> _getPositions(List<TeamBuilderPlayer> players) {
  final result = List<Offset>.filled(players.length, Offset.zero);
  final gkIdx = players.indexWhere((p) => p.isGoalkeeper);
  if (gkIdx >= 0) result[gkIdx] = const Offset(0.50, 0.85);

  final outfieldIdx =
      List.generate(players.length, (i) => i).where((i) => i != gkIdx).toList();
  final outPos = _outfieldPositions(outfieldIdx.length);
  for (var i = 0; i < outfieldIdx.length; i++) {
    result[outfieldIdx[i]] = outPos[i];
  }
  return result;
}

// ── Field painter ─────────────────────────────────────────────────────────────
// As marcações agora vivem em `shared/presentation/widgets/football_pitch.dart`
// (`FootballPitchPainter`), porque o dashboard também desenha o campo. Manter
// duas cópias era garantia de divergirem.

// ── Football field widget ─────────────────────────────────────────────────────

class _FootballField extends StatelessWidget {
  const _FootballField({
    required this.players,
    required this.onRemove,
    required this.loading,
    required this.icons,
  });

  final List<TeamBuilderPlayer> players;
  final void Function(TeamBuilderPlayer) onRemove;
  final bool loading;
  final GroupIcons icons;

  @override
  Widget build(BuildContext context) {
    final positions = _getPositions(players);

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPressed,
                    AppColors.primaryPressed,
                    AppColors.primaryPressed
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Field markings
            CustomPaint(
              size: Size.infinite,
              painter: FootballPitchPainter(),
            ),

            // Loading overlay
            if (loading)
              Container(
                color: AppColors.darkApp.withAlpha(76),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      renderGroupIcon(
                        icons.goal,
                        size: 40,
                        color: AppColors.onDark,
                      ),
                      const SizedBox(height: 8),
                      const Text('Buscando…',
                          style: TextStyle(
                              color: AppColors.onDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            // Empty hint
            if (players.isEmpty && !loading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    renderGroupIcon(
                      icons.goal,
                      size: 48,
                      color: AppColors.onDark.withAlpha(100),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione jogadores abaixo\npara montar o time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.onDark.withAlpha(120),
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ],
                ),
              ),

            // Players
            ...List.generate(players.length, (i) {
              final p = players[i];
              final pos = positions[i];
              return AnimatedAlign(
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                alignment: Alignment(pos.dx * 2 - 1, pos.dy * 2 - 1),
                child: _PlayerPin(
                  player: p,
                  onRemove: () => onRemove(p),
                  icons: icons,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Player pin (bubble on field) ──────────────────────────────────────────────

class _PlayerPin extends StatefulWidget {
  const _PlayerPin({
    required this.player,
    required this.onRemove,
    required this.icons,
  });
  final TeamBuilderPlayer player;
  final VoidCallback onRemove;
  final GroupIcons icons;

  @override
  State<_PlayerPin> createState() => _PlayerPinState();
}

class _PlayerPinState extends State<_PlayerPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGK = widget.player.isGoalkeeper;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovering = true),
        onTapUp: (_) {
          setState(() => _hovering = false);
          widget.onRemove();
        },
        onTapCancel: () => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _hovering ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isGK ? AppColors.warning : AppColors.infoLight,
                      border: Border.all(color: AppColors.onDark, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.darkApp.withAlpha(60),
                            blurRadius: 6,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Center(
                      child: _hovering
                          ? const Icon(Icons.close_rounded,
                              color: AppColors.onDark, size: 20)
                          : renderGroupIcon(
                              isGK
                                  ? widget.icons.goalkeeper
                                  : widget.icons.player,
                              size: 22,
                              color: isGK
                                  ? AppColors.warningLight
                                  : AppColors.onDark,
                            ),
                    ),
                  ),
                  // Red overlay when hovering
                  if (_hovering)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.prototypeDanger.withAlpha(200),
                        border: Border.all(color: AppColors.onDark, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.close_rounded,
                            color: AppColors.onDark, size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              // Name tag
              Container(
                constraints: const BoxConstraints(maxWidth: 60),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.darkApp.withAlpha(140),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.player.name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.onDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    renderGroupIcon(
                      isGK ? widget.icons.goalkeeper : widget.icons.player,
                      size: 8,
                      color: AppColors.onDark,
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

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.stats,
    required this.isDark,
    required this.icons,
    required this.goalkeeperNames,
  });
  final TeamBuilderStats stats;
  final bool isDark;
  final GroupIcons icons;
  final Set<String> goalkeeperNames;

  @override
  Widget build(BuildContext context) {
    if (stats.neverPlayedTogether) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(children: [
          const Text('🤷', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Nunca jogaram juntos',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.slate100 : AppColors.slate800)),
          const SizedBox(height: 4),
          Text('Nenhuma partida finalizada com todos presentes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ]),
      );
    }

    final total = stats.wins + stats.draws + stats.losses;
    final winPct = total > 0 ? (stats.wins / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Row(children: [
          const Text('📊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '${stats.totalMatches} partida${stats.totalMatches != 1 ? "s" : ""} juntos',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.onDark : AppColors.slate800),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green500.withAlpha(isDark ? 40 : 25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green500.withAlpha(100)),
            ),
            child: Text('$winPct% vitória',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green500)),
          ),
        ]),
        const SizedBox(height: 12),

        // W / D / L
        Row(children: [
          Expanded(
              child: _resultTile(
                  '🏆', 'Vitórias', stats.wins, AppColors.accent, isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _resultTile(
                  '🤝', 'Empates', stats.draws, AppColors.warning, isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _resultTile('💔', 'Derrotas', stats.losses,
                  AppColors.prototypeDanger, isDark)),
        ]),
        const SizedBox(height: 12),

        // Goals
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : AppColors.onDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
          ),
          child: Row(children: [
            Expanded(
              child: _goalStat(
                icons.goal,
                'marcados',
                stats.goalsScored,
                isDark,
              ),
            ),
            Container(
                width: 1,
                height: 48,
                color: isDark ? AppColors.slate700 : AppColors.slate200),
            Expanded(
              child: _goalStat(
                icons.goal,
                'sofridos',
                stats.goalsConceded,
                isDark,
              ),
            ),
          ]),
        ),

        // Assists
        if (stats.assistPairs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.onDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    renderGroupIcon(
                      icons.assist,
                      size: 14,
                      color: isDark ? AppColors.slate100 : AppColors.slate800,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Assistências entre eles',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.slate100 : AppColors.slate800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...stats.assistPairs.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              PlayerNameWithIcon(
                                name: a.assisterName.split(' ').first,
                                icons: icons,
                                isGoalkeeper:
                                    goalkeeperNames.contains(a.assisterName),
                                iconSize: 10,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.slate300
                                      : AppColors.slate700,
                                ),
                              ),
                              Text(
                                '→',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.slate400
                                      : AppColors.slate500,
                                ),
                              ),
                              PlayerNameWithIcon(
                                name: a.scorerName.split(' ').first,
                                icons: icons,
                                isGoalkeeper:
                                    goalkeeperNames.contains(a.scorerName),
                                iconSize: 10,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.slate300
                                      : AppColors.slate700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.slate700
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${a.count}x',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.slate200
                                      : AppColors.slate700)),
                        ),
                      ]),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultTile(
          String emoji, String label, int val, Color color, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text('$val',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withAlpha(200))),
        ]),
      );

  Widget _goalStat(String icon, String label, int val, bool isDark) => Column(
        children: [
          renderGroupIcon(
            icon,
            size: 22,
            color: isDark ? AppColors.slate300 : AppColors.slate600,
          ),
          const SizedBox(height: 4),
          Text('$val',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.slate100 : AppColors.slate900)),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ],
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class TeamBuilderPage extends ConsumerStatefulWidget {
  const TeamBuilderPage({super.key});

  @override
  ConsumerState<TeamBuilderPage> createState() => _TeamBuilderPageState();
}

class _TeamBuilderPageState extends ConsumerState<TeamBuilderPage> {
  final List<TeamBuilderPlayer> _selected = [];
  TeamBuilderStats? _stats;
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _canAdd(TeamBuilderPlayer player) {
    if (_selected.any((p) => p.id == player.id)) return false;
    if (_selected.length >= 5) return false;
    if (player.isGoalkeeper && _selected.any((p) => p.isGoalkeeper)) {
      return false;
    }
    return true;
  }

  void _togglePlayer(TeamBuilderPlayer player) {
    setState(() {
      _stats = null;
      _error = null;
      if (_selected.any((p) => p.id == player.id)) {
        _selected.removeWhere((p) => p.id == player.id);
      } else if (_canAdd(player)) {
        _selected.add(player);
      }
    });

    _debounce?.cancel();
    if (_selected.length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 450), _fetchStats);
  }

  Future<void> _fetchStats() async {
    final groupId = ref.read(accountStoreProvider).activeAccount?.activeGroupId;
    if (groupId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = ref.read(_teamBuilderDsProvider);
      final result =
          await ds.fetchStats(groupId, _selected.map((p) => p.id).toList());
      if (mounted) {
        setState(() {
          _stats = result;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.response?.data?['error'] as String? ??
              'Erro ao buscar estatísticas.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erro inesperado. Tente novamente.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final account = ref.watch(accountStoreProvider).activeAccount;
    final activePlayer = ref.watch(activePlayerProvider);
    final groupId = account?.activeGroupId ?? activePlayer?.groupId ?? '';
    final settings = groupId.isEmpty
        ? null
        : ref.watch(groupSettingsProvider(groupId)).valueOrNull;
    final icons = GroupIcons.from(settings);

    if (groupId.isEmpty) {
      return Scaffold(
        body: Column(
          children: [
            _buildHeader(icons),
            const Expanded(
              child: NoActiveGroupView(
                message: 'Selecione uma patota para montar seu time.',
              ),
            ),
          ],
        ),
      );
    }

    final playersAsync = ref.watch(_groupPlayersProvider(groupId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader(icons)),

          // ── Content ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Football field
                  _FootballField(
                    players: _selected,
                    onRemove: _togglePlayer,
                    loading: _loading,
                    icons: icons,
                  ),
                  const SizedBox(height: 12),

                  // Hint text
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        key: ValueKey(_selected.length),
                        _selected.length < 2
                            ? 'Selecione ${2 - _selected.length} jogador${2 - _selected.length != 1 ? "es" : ""} para ver as estatísticas'
                            : _selected.length < 5
                                ? '${5 - _selected.length} vaga${5 - _selected.length != 1 ? "s" : ""} restante${5 - _selected.length != 1 ? "s" : ""} • toque para remover do campo'
                                : 'Time completo! Toque no jogador para remover.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  if (_error != null) _buildError(isDark),
                  if (_stats != null)
                    _StatsPanel(
                      stats: _stats!,
                      isDark: isDark,
                      icons: icons,
                      goalkeeperNames: {
                        for (final player in _selected)
                          if (player.isGoalkeeper) player.name,
                      },
                    ),
                  const SizedBox(height: 20),

                  // Player selector
                  _buildPlayerSelector(isDark, playersAsync, icons),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(GroupIcons icons) {
    return const AppPageHeader(
      title: 'Monte seu time',
      subtitle: 'Visualize o desempenho da formação',
      icon: Icons.groups_2_outlined,
    );
  }

  // ── Player selector ────────────────────────────────────────────────────────

  Widget _buildPlayerSelector(
    bool isDark,
    AsyncValue<List<TeamBuilderPlayer>> async,
    GroupIcons icons,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jogadores',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro ao carregar jogadores.',
              style: TextStyle(
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
          data: (players) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: players.map((p) {
              final sel = _selected.any((s) => s.id == p.id);
              final canAdd = _canAdd(p);
              final disabled = !sel && !canAdd;

              return GestureDetector(
                onTap: disabled ? null : () => _togglePlayer(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: sel
                        ? (isDark ? AppColors.onDark : AppColors.slate900)
                        : disabled
                            ? (isDark
                                ? AppColors.slate800.withAlpha(100)
                                : AppColors.slate100.withAlpha(100))
                            : (isDark ? AppColors.slate800 : AppColors.onDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? (isDark ? AppColors.onDark : AppColors.slate900)
                          : disabled
                              ? (isDark
                                  ? AppColors.slate700.withAlpha(100)
                                  : AppColors.slate200.withAlpha(100))
                              : (isDark
                                  ? AppColors.slate600
                                  : AppColors.slate300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      renderGroupIcon(
                        p.isGoalkeeper ? icons.goalkeeper : icons.player,
                        size: 12,
                        color: sel
                            ? (isDark ? AppColors.slate900 : AppColors.onDark)
                            : disabled
                                ? (isDark
                                    ? AppColors.slate600
                                    : AppColors.slate300)
                                : (isDark
                                    ? AppColors.slate100
                                    : AppColors.slate800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.name.split(' ').first,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? (isDark ? AppColors.slate900 : AppColors.onDark)
                              : disabled
                                  ? (isDark
                                      ? AppColors.slate600
                                      : AppColors.slate300)
                                  : (isDark
                                      ? AppColors.slate100
                                      : AppColors.slate800),
                        ),
                      ),
                      if (sel) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.close_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.slate600
                                : AppColors.slate300),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(bool isDark) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.dangerBackground
              : AppColors.dangerBackgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.rose200),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.prototypeDanger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.prototypeDanger))),
        ]),
      );
}
