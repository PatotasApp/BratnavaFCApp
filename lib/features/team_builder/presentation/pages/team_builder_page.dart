import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/team_builder_datasource.dart';
import '../../domain/entities/team_builder_models.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _teamBuilderDsProvider = Provider<TeamBuilderDataSource>(
  (ref) => TeamBuilderDataSource(ref.watch(dioProvider)),
);

final _groupPlayersProvider =
    FutureProvider.family<List<TeamBuilderPlayer>, String>((ref, groupId) async {
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
            id:           (p['id'] ?? '') as String,
            name:         (p['name'] ?? '') as String,
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
    4: [Offset(0.30, 0.33), Offset(0.70, 0.33), Offset(0.22, 0.60), Offset(0.78, 0.60)],
  };
  final key = math.min(n, 4);
  return patterns[key] ?? patterns[4]!;
}

List<Offset> _getPositions(List<TeamBuilderPlayer> players) {
  final result = List<Offset>.filled(players.length, Offset.zero);
  final gkIdx  = players.indexWhere((p) => p.isGoalkeeper);
  if (gkIdx >= 0) result[gkIdx] = const Offset(0.50, 0.85);

  final outfieldIdx = List.generate(players.length, (i) => i)
      .where((i) => i != gkIdx)
      .toList();
  final outPos = _outfieldPositions(outfieldIdx.length);
  for (var i = 0; i < outfieldIdx.length; i++) {
    result[outfieldIdx[i]] = outPos[i];
  }
  return result;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ── Field painter ─────────────────────────────────────────────────────────────

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grass stripes
    final stripePaint = Paint()..color = Colors.black.withAlpha(18);
    for (double y = 0; y < h; y += 36) {
      canvas.drawRect(Rect.fromLTWH(0, y + 18, w, 18), stripePaint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(140)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final thin = Paint()
      ..color = Colors.white.withAlpha(100)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.fill;

    final m = 8 / 200; // margin ratio

    // Outer boundary
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * m, h * (8 / 300), w * (1 - m), h * (292 / 300)),
        const Radius.circular(3),
      ),
      linePaint,
    );

    // Center line
    canvas.drawLine(Offset(w * m, h * 0.5), Offset(w * (1 - m), h * 0.5), thin);

    // Center circle
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.14, thin);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 2.5, glowPaint);

    // Top penalty area
    canvas.drawRect(
      Rect.fromLTRB(w * (52 / 200), h * (8 / 300), w * (148 / 200), h * (54 / 300)),
      thin,
    );
    // Top goal area
    canvas.drawRect(
      Rect.fromLTRB(w * (72 / 200), h * (8 / 300), w * (128 / 200), h * (28 / 300)),
      thin,
    );
    // Top goal
    final goalFill = Paint()..color = Colors.white.withAlpha(40)..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * (84 / 200), h * (2 / 300), w * (116 / 200), h * (9 / 300)),
        const Radius.circular(1.5),
      ),
      goalFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * (84 / 200), h * (2 / 300), w * (116 / 200), h * (9 / 300)),
        const Radius.circular(1.5),
      ),
      linePaint,
    );

    // Bottom penalty area
    canvas.drawRect(
      Rect.fromLTRB(w * (52 / 200), h * (246 / 300), w * (148 / 200), h * (292 / 300)),
      thin,
    );
    // Bottom goal area
    canvas.drawRect(
      Rect.fromLTRB(w * (72 / 200), h * (272 / 300), w * (128 / 200), h * (292 / 300)),
      thin,
    );
    // Bottom goal
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * (84 / 200), h * (291 / 300), w * (116 / 200), h * (298 / 300)),
        const Radius.circular(1.5),
      ),
      goalFill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * (84 / 200), h * (291 / 300), w * (116 / 200), h * (298 / 300)),
        const Radius.circular(1.5),
      ),
      linePaint,
    );

    // Penalty spots
    canvas.drawCircle(Offset(w * 0.5, h * (36 / 300)),  2.5, glowPaint);
    canvas.drawCircle(Offset(w * 0.5, h * (264 / 300)), 2.5, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Football field widget ─────────────────────────────────────────────────────

class _FootballField extends StatelessWidget {
  const _FootballField({
    required this.players,
    required this.onRemove,
    required this.loading,
  });

  final List<TeamBuilderPlayer> players;
  final void Function(TeamBuilderPlayer) onRemove;
  final bool loading;

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
                  colors: [Color(0xFF166534), Color(0xFF15803D), Color(0xFF166534)],
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                ),
              ),
            ),

            // Field markings
            CustomPaint(
              size: Size.infinite,
              painter: _FieldPainter(),
            ),

            // Loading overlay
            if (loading)
              Container(
                color: Colors.black.withAlpha(76),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('⚽', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('Buscando…',
                          style: TextStyle(color: Colors.white, fontSize: 13,
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
                    Text('⚽',
                        style: TextStyle(fontSize: 48,
                            color: Colors.white.withAlpha(100))),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione jogadores abaixo\npara montar o time',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withAlpha(120),
                          fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),

            // Players
            ...List.generate(players.length, (i) {
              final p   = players[i];
              final pos = positions[i];
              return AnimatedAlign(
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                alignment: Alignment(pos.dx * 2 - 1, pos.dy * 2 - 1),
                child: _PlayerPin(
                  player:   p,
                  onRemove: () => onRemove(p),
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
  const _PlayerPin({required this.player, required this.onRemove});
  final TeamBuilderPlayer player;
  final VoidCallback onRemove;

  @override
  State<_PlayerPin> createState() => _PlayerPinState();
}

class _PlayerPinState extends State<_PlayerPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
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
        onTapDown:  (_) => setState(() => _hovering = true),
        onTapUp:    (_) { setState(() => _hovering = false); widget.onRemove(); },
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
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape:  BoxShape.circle,
                      color:  isGK ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(60),
                            blurRadius: 6, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Center(
                      child: _hovering
                          ? const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20)
                          : isGK
                              ? const Text('🧤',
                                  style: TextStyle(fontSize: 22))
                              : Text(_initials(widget.player.name),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isGK
                                        ? const Color(0xFF78350F)
                                        : Colors.white,
                                  )),
                    ),
                  ),
                  // Red overlay when hovering
                  if (_hovering)
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDC2626).withAlpha(200),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
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
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.player.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.isDark});
  final TeamBuilderStats stats;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (stats.neverPlayedTogether) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
        ),
        child: Column(children: [
          const Text('🤷', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Nunca jogaram juntos',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.slate100 : AppColors.slate800)),
          const SizedBox(height: 4),
          Text('Nenhuma partida finalizada com todos presentes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
        ]),
      );
    }

    final total  = stats.wins + stats.draws + stats.losses;
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
                fontSize: 15, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.slate800),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColors.green500.withAlpha(isDark ? 40 : 25),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: AppColors.green500.withAlpha(100)),
            ),
            child: Text('$winPct% vitória',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600, color: AppColors.green500)),
          ),
        ]),
        const SizedBox(height: 12),

        // W / D / L
        Row(children: [
          Expanded(child: _resultTile('🏆', 'Vitórias', stats.wins,
              const Color(0xFF22C55E), isDark)),
          const SizedBox(width: 8),
          Expanded(child: _resultTile('🤝', 'Empates',  stats.draws,
              const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 8),
          Expanded(child: _resultTile('💔', 'Derrotas', stats.losses,
              const Color(0xFFEF4444), isDark)),
        ]),
        const SizedBox(height: 12),

        // Goals
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:        isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200),
          ),
          child: Row(children: [
            Expanded(child: _goalStat('⚽', 'marcados', stats.goalsScored, isDark)),
            Container(width: 1, height: 48,
                color: isDark ? AppColors.slate700 : AppColors.slate200),
            Expanded(child: _goalStat('🥅', 'sofridos', stats.goalsConceded, isDark)),
          ]),
        ),

        // Assists
        if (stats.assistPairs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.slate900 : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎯 Assistências entre eles',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.slate100 : AppColors.slate800)),
                const SizedBox(height: 12),
                ...stats.assistPairs.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text.rich(TextSpan(
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AppColors.slate300 : AppColors.slate700),
                        children: [
                          TextSpan(text: a.assisterName.split(' ').first,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' → '),
                          TextSpan(text: a.scorerName.split(' ').first,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      )),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color:        isDark ? AppColors.slate700 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${a.count}x',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.slate200 : AppColors.slate700)),
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

  Widget _resultTile(String emoji, String label, int val, Color color, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        color.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withAlpha(100)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text('$val',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: color.withAlpha(200))),
        ]),
      );

  Widget _goalStat(String emoji, String label, int val, bool isDark) => Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text('$val',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: isDark ? AppColors.slate100 : AppColors.slate900)),
      Text(label,
          style: TextStyle(fontSize: 11,
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
  bool              _loading = false;
  String?           _error;
  Timer?            _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _canAdd(TeamBuilderPlayer player) {
    if (_selected.any((p) => p.id == player.id)) return false;
    if (_selected.length >= 5) return false;
    if (player.isGoalkeeper && _selected.any((p) => p.isGoalkeeper)) return false;
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
    final groupId =
        ref.read(accountStoreProvider).activeAccount?.activeGroupId;
    if (groupId == null) return;

    setState(() { _loading = true; _error = null; });
    try {
      final ds     = ref.read(_teamBuilderDsProvider);
      final result = await ds.fetchStats(
          groupId, _selected.map((p) => p.id).toList());
      if (mounted) setState(() { _stats = result; _loading = false; });
    } on DioException catch (e) {
      if (mounted) setState(() {
        _error   = e.response?.data?['error'] as String?
            ?? 'Erro ao buscar estatísticas.';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error   = 'Erro inesperado. Tente novamente.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final account     = ref.watch(accountStoreProvider).activeAccount;
    final groupId     = account?.activeGroupId ?? '';
    final playersAsync = ref.watch(_groupPlayersProvider(groupId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader()),

          // ── Content ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Football field
                  _FootballField(
                    players:  _selected,
                    onRemove: _togglePlayer,
                    loading:  _loading,
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
                            color: isDark ? AppColors.slate400 : AppColors.slate500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  if (_error != null) _buildError(isDark),
                  if (_stats != null) _StatsPanel(stats: _stats!, isDark: isDark),
                  const SizedBox(height: 20),

                  // Player selector
                  _buildPlayerSelector(isDark, playersAsync),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color:        Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: const Center(
              child: Text('⚽', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monte seu Time',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.celebration_outlined, size: 12,
                      color: Color(0xFFFBBF24)),
                  SizedBox(width: 4),
                  Text('Funcionalidade de evento',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    ),
  );

  // ── Player selector ────────────────────────────────────────────────────────

  Widget _buildPlayerSelector(bool isDark, AsyncValue<List<TeamBuilderPlayer>> async) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jogadores',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.slate300 : AppColors.slate600)),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Text('Erro ao carregar jogadores.',
              style: TextStyle(
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
          data: (players) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: players.map((p) {
              final sel      = _selected.any((s) => s.id == p.id);
              final canAdd   = _canAdd(p);
              final disabled = !sel && !canAdd;

              return GestureDetector(
                onTap: disabled ? null : () => _togglePlayer(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? (isDark ? Colors.white : AppColors.slate900)
                        : disabled
                            ? (isDark ? AppColors.slate800.withAlpha(100) : AppColors.slate100.withAlpha(100))
                            : (isDark ? AppColors.slate800 : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? (isDark ? Colors.white : AppColors.slate900)
                          : disabled
                              ? (isDark ? AppColors.slate700.withAlpha(100) : AppColors.slate200.withAlpha(100))
                              : (isDark ? AppColors.slate600 : AppColors.slate300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.isGoalkeeper)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('🧤', style: TextStyle(fontSize: 12)),
                        ),
                      Text(
                        p.name.split(' ').first,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? (isDark ? AppColors.slate900 : Colors.white)
                              : disabled
                                  ? (isDark ? AppColors.slate600 : AppColors.slate300)
                                  : (isDark ? AppColors.slate100 : AppColors.slate800),
                        ),
                      ),
                      if (sel) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.close_rounded, size: 12,
                            color: isDark ? AppColors.slate600 : AppColors.slate300),
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
      color:        isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, size: 16,
          color: Color(0xFFEF4444)),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!,
          style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)))),
    ]),
  );
}
