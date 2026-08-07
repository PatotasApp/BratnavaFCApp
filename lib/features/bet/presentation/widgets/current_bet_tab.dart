import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/bet_models.dart';
import '../providers/bet_provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';

class CurrentBetTab extends ConsumerStatefulWidget {
  final String groupId;
  const CurrentBetTab({super.key, required this.groupId});

  @override
  ConsumerState<CurrentBetTab> createState() => _CurrentBetTabState();
}

class _CurrentBetTabState extends ConsumerState<CurrentBetTab> {
  List<BettableMatchDto> _bettable = [];
  int _selectedIdx = 0;
  CurrentMatchBetContext? _ctx;
  int? _balance;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _confirmDelete = false;
  bool _showPlayerStatus = false;
  String? _error;

  List<SelectionFormState> _selections = const [
    SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final ds = ref.read(betDsProvider);
    try {
      // Carrega lista de partidas disponíveis + saldo em paralelo
      final results = await Future.wait([
        ds.fetchBettableMatches(widget.groupId),
        ds.fetchBalance(widget.groupId),
      ]);
      if (!mounted) return;

      final bettable = results[0] as List<BettableMatchDto>;
      final balance = (results[1] as int?) ?? 0;

      // Carrega contexto da partida selecionada
      CurrentMatchBetContext? ctx;
      if (bettable.isNotEmpty) {
        final idx = _selectedIdx.clamp(0, bettable.length - 1);
        ctx = await ds.fetchContextForMatch(
            widget.groupId, bettable[idx].matchId);
      } else {
        // Fallback: endpoint legado
        ctx = await ds.fetchCurrent(widget.groupId);
      }
      if (!mounted) return;

      setState(() {
        _loading = false;
        _bettable = bettable;
        _ctx = ctx;
        _balance = balance;
        _applyCtx(ctx);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = extractDioError(e);
      });
    }
  }

  Future<void> _selectMatch(int idx) async {
    if (idx == _selectedIdx && _ctx != null) return;
    setState(() {
      _loading = true;
      _selectedIdx = idx;
      _error = null;
    });
    final ds = ref.read(betDsProvider);
    try {
      final ctx =
          await ds.fetchContextForMatch(widget.groupId, _bettable[idx].matchId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ctx = ctx;
        _applyCtx(ctx);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = extractDioError(e);
      });
    }
  }

  void _applyCtx(CurrentMatchBetContext? ctx) {
    if (ctx?.myBet?.selections.isNotEmpty == true) {
      _selections = ctx!.myBet!.selections.map(_fromDto).toList();
    } else if (ctx?.myBet == null) {
      _selections = const [
        SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
      ];
    }
  }

  // ── Parse existing bet selections ─────────────────────────────────────────

  SelectionFormState _fromDto(BetSelectionDto s) {
    switch (s.category) {
      case 'WinningTeam':
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          winTeam: s.predictedValue,
        );
      case 'FinalScore':
        final p = s.predictedValue.split(':');
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          scoreA: int.tryParse(p.isNotEmpty ? p[0] : '0') ?? 0,
          scoreB: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        );
      case 'PlayerGoals':
      case 'PlayerAssists':
        final p = s.predictedValue.split('|');
        return SelectionFormState(
          category: s.category,
          fichasWagered: s.fichasWagered,
          playerMatchId: p.isNotEmpty ? p[0] : null,
          playerCount: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
        );
      default:
        return SelectionFormState(
            category: s.category, fichasWagered: s.fichasWagered);
    }
  }

  // ── Selections management ─────────────────────────────────────────────────

  void _updateSelection(int i, SelectionFormState updated) {
    setState(() {
      final list = List<SelectionFormState>.from(_selections);
      list[i] = updated;
      _selections = list;
    });
  }

  void _removeSelection(int i) {
    setState(() {
      final list = List<SelectionFormState>.from(_selections);
      list.removeAt(i);
      _selections = list;
    });
  }

  void _addCategory(String cat) {
    if (_selections.length >= 5) return;
    setState(() {
      _selections = [
        ..._selections,
        SelectionFormState(category: cat, fichasWagered: 30),
      ];
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate each selection
    final invalid = _selections.indexWhere((s) => !s.isValid);
    if (invalid >= 0) {
      final cat = _selections[invalid].category;
      _showSnack(
        'Seleção incompleta: ${kCategoryLabels[cat] ?? cat}',
        error: true,
      );
      return;
    }
    // Validate total wager
    final total = _selections.fold(0, (s, sel) => s + sel.fichasWagered);
    if (total > kMaxWager) {
      _showSnack('Máximo $kMaxWager BC por partida. Total: $total',
          error: true);
      return;
    }

    final ctx = _ctx;
    if (ctx == null) return;

    setState(() => _saving = true);
    try {
      final dto = PlaceMatchBetDto(
        selections: _selections.map((s) => s.toDto()).toList(),
      );
      await ref
          .read(betDsProvider)
          .placeOrUpdateBet(widget.groupId, ctx.matchId, dto);
      if (mounted) {
        _showSnack(
            ctx.myBet != null ? 'Aposta atualizada!' : 'Aposta registrada!');
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final ctx = _ctx;
    if (ctx == null) return;
    setState(() {
      _deleting = true;
      _confirmDelete = false;
    });
    try {
      await ref.read(betDsProvider).deleteBet(widget.groupId, ctx.matchId);
      if (mounted) {
        _showSnack('Aposta removida.');
        setState(() {
          _selections = const [
            SelectionFormState(category: 'WinningTeam', fichasWagered: 50),
          ];
        });
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao remover: $e', error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.rose500 : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ));
    }

    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.rose500),
          const SizedBox(height: 12),
          Text('Erro ao carregar apostas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.onDark : AppColors.slate900,
              )),
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ]),
      ));
    }

    final ctx = _ctx;

    if (ctx == null) {
      return _EmptyMatchState(isDark: isDark);
    }

    final isLocked = !ctx.betWindowOpen;
    final totalWager = _selections.fold(0, (s, sel) => s + sel.fichasWagered);
    final overMax = totalWager > kMaxWager;
    final members = ctx.players.where((p) => !p.isGuest).toList();
    final betCount = members.where((p) => p.hasBet).length;
    final hasExisting = ctx.myBet != null;

    // Available categories to add
    final usedCats = _selections.map((s) => s.category).toSet();
    final availCats = <String>[];
    if (!usedCats.contains('FinalScore')) availCats.add('FinalScore');
    if (_selections.length < 5)
      availCats.addAll(['PlayerGoals', 'PlayerAssists']);

    return Column(
      children: [
        // ── Seletor de partidas (quando há mais de uma) ───────────────────
        if (_bettable.length > 1)
          _BetMatchSelector(
            matches: _bettable,
            selected: _selectedIdx.clamp(0, _bettable.length - 1),
            isDark: isDark,
            onSelect: _selectMatch,
          ),

        Expanded(
            child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Janela de apostas fechada ─────────────────────────────────────
              if (isLocked) ...[
                _BetClosedBanner(statusName: ctx.statusName, isDark: isDark),
                const SizedBox(height: 16),
              ],

              // ── Player status card (só quando apostas disponíveis) ────────────
              if (!isLocked) ...[
                _PlayerStatusCard(
                  groupId: widget.groupId,
                  members: members,
                  betCount: betCount,
                  playedAt: ctx.playedAt,
                  statusName: ctx.statusName,
                  balance: _balance,
                  isExpanded: _showPlayerStatus,
                  onToggle: () =>
                      setState(() => _showPlayerStatus = !_showPlayerStatus),
                  isDark: isDark,
                  onRefresh: _load,
                ),
                const SizedBox(height: 12),
              ],

              // ── Escalação dos times ───────────────────────────────────────────
              if (ctx.players.any((p) => p.team != 0)) ...[
                _TeamLineupPanel(
                  groupId: widget.groupId,
                  players: ctx.players,
                  selections: _selections,
                  teamAName: ctx.teamAName,
                  teamBName: ctx.teamBName,
                  teamAColor: ctx.teamAColor,
                  teamBColor: ctx.teamBColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
              ],

              // ── Selection cards ───────────────────────────────────────────────
              if (hasExisting || !isLocked)
                for (var i = 0; i < _selections.length; i++) ...[
                  _SelectionCard(
                    groupId: widget.groupId,
                    sel: _selections[i],
                    index: i,
                    players: ctx.players,
                    locked: isLocked,
                    canRemove: !isLocked && i > 0,
                    winnerHint:
                        _selections.any((s) => s.category == 'WinningTeam')
                            ? _selections
                                .firstWhere((s) => s.category == 'WinningTeam')
                                .winTeam
                            : null,
                    isDark: isDark,
                    teamAName: ctx.teamAName,
                    teamBName: ctx.teamBName,
                    teamAColor: ctx.teamAColor,
                    teamBColor: ctx.teamBColor,
                    onUpdate: (updated) => _updateSelection(i, updated),
                    onRemove: () => _removeSelection(i),
                  ),
                  const SizedBox(height: 10),
                ],

              // ── Add category buttons ──────────────────────────────────────────
              if (!isLocked &&
                  availCats.isNotEmpty &&
                  _selections.length < 5) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availCats
                      .map((cat) => _AddCatBtn(
                            label: '+ ${kCategoryLabels[cat] ?? cat}',
                            isDark: isDark,
                            onTap: () => _addCategory(cat),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Total + submit ────────────────────────────────────────────────
              if (!isLocked) ...[
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  Text(
                    'Total: ',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500),
                  ),
                  Text(
                    '$totalWager / $kMaxWager BC',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: overMax
                          ? AppColors.rose500
                          : (isDark ? AppColors.onDark : AppColors.slate900),
                    ),
                  ),
                  const Spacer(),
                  // Delete / confirm-delete
                  if (hasExisting)
                    _confirmDelete
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Resetar?',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.rose500)),
                            const SizedBox(width: 8),
                            _SmallBtn(
                              label: 'Não',
                              onTap: () =>
                                  setState(() => _confirmDelete = false),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),
                            _SmallBtn(
                              label: _deleting ? '…' : 'Sim',
                              onTap: _deleting ? null : _delete,
                              danger: true,
                              isDark: isDark,
                            ),
                          ])
                        : TextButton.icon(
                            onPressed: () =>
                                setState(() => _confirmDelete = true),
                            icon: const Icon(Icons.close,
                                size: 14, color: AppColors.rose500),
                            label: const Text('Resetar',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.rose500)),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4)),
                          ),
                  const SizedBox(width: 8),
                  // Submit
                  ElevatedButton.icon(
                    onPressed: (_saving || overMax) ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.onDark))
                        : const Icon(Icons.check, size: 15),
                    label: Text(hasExisting ? 'Atualizar' : 'Apostar',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.onDark : AppColors.slate900,
                      foregroundColor:
                          isDark ? AppColors.slate900 : AppColors.onDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ],
          ),
        )),
      ],
    );
  }
}

// ── Seletor de partidas para apostas ─────────────────────────────────────────

class _BetMatchSelector extends StatelessWidget {
  final List<BettableMatchDto> matches;
  final int selected;
  final bool isDark;
  final void Function(int) onSelect;

  const _BetMatchSelector({
    required this.matches,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? AppColors.slate800 : AppColors.slate100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(matches.length, (i) {
            final m = matches[i];
            final active = i == selected;
            final d = m.playedAt;
            final label = '${d.day.toString().padLeft(2, '0')}/'
                '${d.month.toString().padLeft(2, '0')} · '
                '${m.placeName.isNotEmpty ? m.placeName : 'Partida'}';
            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark ? AppColors.onDark : AppColors.slate900)
                      : (isDark ? AppColors.slate700 : AppColors.onDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppColors.transparent
                        : (isDark ? AppColors.slate600 : AppColors.slate200),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? (isDark ? AppColors.slate900 : AppColors.onDark)
                        : (isDark ? AppColors.slate300 : AppColors.slate600),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Player status card ────────────────────────────────────────────────────────

class _PlayerStatusCard extends StatelessWidget {
  final String groupId;
  final List<BetPlayer> members;
  final int betCount;
  final String playedAt;
  final String statusName;
  final int? balance;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final bool isDark;

  const _PlayerStatusCard({
    required this.groupId,
    required this.members,
    required this.betCount,
    required this.playedAt,
    required this.statusName,
    required this.balance,
    required this.isExpanded,
    required this.onToggle,
    required this.onRefresh,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor = isDark ? AppColors.slate800 : AppColors.onDark;

    String fmtDate(String raw) {
      try {
        final d = AppDateUtils.parseOrNow(raw);
        return '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';
      } catch (_) {
        return raw;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header row (tappable)
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$betCount de ${members.length} jogador${members.length != 1 ? "es" : ""} já '
                    '${betCount != 1 ? "fizeram" : "fez"} sua aposta',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.onDark : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(playedAt)} · $statusName',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppColors.slate400 : AppColors.slate500),
                  ),
                ],
              )),
              if (balance != null) ...[
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Saldo',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      )),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.monetization_on_outlined,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text('$balance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fichasColor(balance),
                        )),
                  ]),
                ]),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 2),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ]),
          ),
        ),
        // Expanded player list
        if (isExpanded) ...[
          Divider(
              height: 1,
              color: isDark ? AppColors.slate700 : AppColors.slate100),
          for (final p in members)
            Container(
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: isDark
                              ? AppColors.slate700.withValues(alpha: .5)
                              : AppColors.slate50,
                          width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                ),
                if (p.hasBet)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded,
                        size: 14, color: AppColors.primaryHover),
                    const SizedBox(width: 4),
                    Text('Apostou',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryHover)),
                    if (p.totalFichasWagered != null) ...[
                      Text(' · ${p.totalFichasWagered} BC',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500)),
                    ],
                  ])
                else
                  Text('Aguardando…',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.slate500
                              : AppColors.slate400)),
              ]),
            ),
        ],
      ]),
    );
  }
}

// ── SelectionCard ─────────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String groupId;
  final SelectionFormState sel;
  final int index;
  final List<BetPlayer> players;
  final bool locked;
  final bool canRemove;
  final String? winnerHint;
  final bool isDark;
  final String? teamAName;
  final String? teamBName;
  final Color? teamAColor;
  final Color? teamBColor;
  final ValueChanged<SelectionFormState> onUpdate;
  final VoidCallback onRemove;

  const _SelectionCard({
    required this.groupId,
    required this.sel,
    required this.index,
    required this.players,
    required this.locked,
    required this.canRemove,
    required this.isDark,
    required this.onUpdate,
    required this.onRemove,
    this.winnerHint,
    this.teamAName,
    this.teamBName,
    this.teamAColor,
    this.teamBColor,
  });

  bool _scoreConsistent(String? winner, int? a, int? b) {
    if (winner == null || a == null || b == null) return true;
    if (winner == 'TeamA') return a > b;
    if (winner == 'TeamB') return b > a;
    if (winner == 'Draw') return a == b;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final bgColor =
        isDark ? AppColors.slate800.withValues(alpha: .5) : AppColors.onDark;
    final labelStyle = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? AppColors.slate400 : AppColors.slate500);
    final subStyle = TextStyle(
        fontSize: 10, color: isDark ? AppColors.slate500 : AppColors.slate400);
    final isMandatory = sel.category == 'WinningTeam';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(children: [
          Text('#${index + 1}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.slate500 : AppColors.slate400)),
          const SizedBox(width: 8),
          Text(kCategoryLabels[sel.category] ?? sel.category,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.onDark : AppColors.slate900)),
          if (isMandatory) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.rose500.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('obrigatório',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose500)),
            ),
          ],
          const Spacer(),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close,
                  size: 16,
                  color: isDark ? AppColors.slate400 : AppColors.slate500),
            ),
        ]),
        const SizedBox(height: 4),
        Text(kCategoryMultipliers[sel.category] ?? '', style: subStyle),
        const SizedBox(height: 12),

        // ── Input area ─────────────────────────────────────────────────────
        if (sel.category == 'WinningTeam') _buildWinningTeam(labelStyle),
        if (sel.category == 'FinalScore') _buildFinalScore(labelStyle),
        if (sel.category == 'PlayerGoals' || sel.category == 'PlayerAssists')
          _buildPlayerCategory(labelStyle),

        // ── Wager ──────────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Divider(
            height: 1, color: isDark ? AppColors.slate700 : AppColors.slate100),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.monetization_on_outlined,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Text('Bratnava Coins:', style: subStyle),
          const Spacer(),
          _NumberStepper(
            value: sel.fichasWagered,
            min: 30,
            max: kMaxWager,
            step: 10,
            disabled: locked,
            isDark: isDark,
            onChange: (v) => onUpdate(sel.copyWith(fichasWagered: v)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildWinningTeam(TextStyle labelStyle) {
    final labelA = teamAName ?? 'Time A';
    final labelB = teamBName ?? 'Time B';
    final colorA = teamAColor;
    final colorB = teamBColor;

    final opts = [
      ('TeamA', labelA, colorA),
      ('Draw', 'Empate', null as Color?),
      ('TeamB', labelB, colorB),
    ];

    return Row(
        children: opts.map((opt) {
      final active = sel.winTeam == opt.$1;
      final teamColor = opt.$3;
      final activeColor =
          teamColor ?? (isDark ? AppColors.onDark : AppColors.slate900);
      final activeFg = teamColor != null
          ? (teamColor.computeLuminance() > 0.4
              ? AppColors.slate900
              : AppColors.onDark)
          : (isDark ? AppColors.slate900 : AppColors.onDark);

      return Expanded(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          onTap: locked ? null : () => onUpdate(sel.copyWith(winTeam: opt.$1)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? activeColor
                  : (locked
                      ? (isDark ? AppColors.slate800 : AppColors.slate50)
                      : (isDark ? AppColors.slate700 : AppColors.slate50)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? activeColor
                    : (isDark ? AppColors.slate600 : AppColors.slate200),
              ),
            ),
            child: Center(
                child: Text(opt.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? activeFg
                          : (isDark ? AppColors.slate300 : AppColors.slate600),
                    ))),
          ),
        ),
      ));
    }).toList());
  }

  Widget _buildFinalScore(TextStyle labelStyle) {
    final inconsistent = sel.category == 'FinalScore' &&
        !_scoreConsistent(winnerHint, sel.scoreA, sel.scoreB);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Column(children: [
          Text(teamAName ?? 'Time A', style: labelStyle),
          const SizedBox(height: 6),
          _NumberStepper(
            value: sel.scoreA ?? 0,
            min: 0,
            max: 20,
            step: 1,
            size: _StepperSize.large,
            disabled: locked,
            isDark: isDark,
            onChange: (v) => onUpdate(sel.copyWith(scoreA: v)),
          ),
        ])),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(' × ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.slate400 : AppColors.slate400)),
        ),
        Expanded(
            child: Column(children: [
          Text(teamBName ?? 'Time B', style: labelStyle),
          const SizedBox(height: 6),
          _NumberStepper(
            value: sel.scoreB ?? 0,
            min: 0,
            max: 20,
            step: 1,
            size: _StepperSize.large,
            disabled: locked,
            isDark: isDark,
            onChange: (v) => onUpdate(sel.copyWith(scoreB: v)),
          ),
        ])),
      ]),
      if (inconsistent) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Flexible(
              child: Text(
            winnerHint == 'Draw'
                ? 'Placar inconsistente: empate exige gols iguais.'
                : 'Placar inconsistente com o time vencedor.',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.warningLight),
          )),
        ]),
      ],
    ]);
  }

  Widget _buildPlayerCategory(TextStyle labelStyle) {
    final elgPlayers = players.where((p) => p.team != 0).toList();
    final isGoals = sel.category == 'PlayerGoals';
    final hintLabel = isGoals ? 'Gols previstos' : 'Assistências previstas';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Player dropdown
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate800 : AppColors.onDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.slate600 : AppColors.slate200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: sel.playerMatchId,
            isExpanded: true,
            hint: Text('Selecione um jogador…',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.slate500 : AppColors.slate400)),
            dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
            onChanged:
                locked ? null : (v) => onUpdate(sel.copyWith(playerMatchId: v)),
            items: [
              for (final p in elgPlayers)
                DropdownMenuItem(
                  value: p.matchPlayerId,
                  child: ConfiguredPlayerName(
                    groupId: groupId,
                    name:
                        '${p.name} (${p.team == 1 ? (teamAName ?? "Time A") : (teamBName ?? "Time B")})',
                    isGoalkeeper: p.isGoalkeeper,
                    iconSize: 13,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.onDark : AppColors.slate900),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      // Count stepper
      Row(children: [
        Text('$hintLabel:',
            style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate400 : AppColors.slate500)),
        const Spacer(),
        _NumberStepper(
          value: sel.playerCount ?? 0,
          min: 0,
          max: 20,
          step: 1,
          size: _StepperSize.small,
          disabled: locked,
          isDark: isDark,
          onChange: (v) => onUpdate(sel.copyWith(playerCount: v)),
        ),
      ]),
    ]);
  }
}

// ── Team lineup panel ─────────────────────────────────────────────────────────

class _TeamLineupPanel extends StatelessWidget {
  final String groupId;
  final List<BetPlayer> players;
  final List<SelectionFormState> selections;
  final String? teamAName;
  final String? teamBName;
  final Color? teamAColor;
  final Color? teamBColor;
  final bool isDark;

  const _TeamLineupPanel({
    required this.groupId,
    required this.players,
    required this.selections,
    required this.isDark,
    this.teamAName,
    this.teamBName,
    this.teamAColor,
    this.teamBColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorA = teamAColor ?? AppColors.blue500;
    final colorB = teamBColor ?? AppColors.slate400;
    final labelA = teamAName ?? 'Time A';
    final labelB = teamBName ?? 'Time B';

    // Seleção de vencedor
    final winSel =
        selections.where((s) => s.category == 'WinningTeam').firstOrNull;
    final winner = winSel?.winTeam; // 'TeamA' | 'TeamB' | 'Draw' | null

    // Gols e assistências apostados por matchPlayerId
    final goals = <String, int>{};
    final assists = <String, int>{};
    for (final s in selections) {
      if (s.category == 'PlayerGoals' && s.playerMatchId != null)
        goals[s.playerMatchId!] =
            (goals[s.playerMatchId!] ?? 0) + (s.playerCount ?? 0);
      if (s.category == 'PlayerAssists' && s.playerMatchId != null)
        assists[s.playerMatchId!] =
            (assists[s.playerMatchId!] ?? 0) + (s.playerCount ?? 0);
    }

    final teamA = players.where((p) => p.team == 1).toList();
    final teamB = players.where((p) => p.team == 2).toList();

    Widget buildHeader(String label, Color color, bool highlighted) {
      final fg = color.computeLuminance() > 0.4
          ? AppColors.slate900
          : AppColors.onDark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: color,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: fg,
              ),
            ),
            if (highlighted && winner != null && winner != 'Draw') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.onDark.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('✓ VITÓRIA',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: fg)),
              ),
            ],
            if (winner == 'Draw') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.onDark.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('EMPATE',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: fg)),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildPlayer(BetPlayer p) {
      final g = goals[p.matchPlayerId];
      final a = assists[p.matchPlayerId];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: ConfiguredPlayerName(
                groupId: groupId,
                name: p.name,
                isGoalkeeper: p.isGoalkeeper,
                iconSize: 12,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                ),
              ),
            ),
            if (g != null || a != null)
              _ConfiguredBetStats(
                groupId: groupId,
                goals: g,
                assists: a,
                isDark: isDark,
              ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: isDark ? AppColors.slate700 : AppColors.slate200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Time A ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(
                        labelA, colorA, winner == 'TeamA' || winner == 'Draw'),
                    ...teamA.map(buildPlayer),
                  ],
                ),
              ),
              // divisor vertical
              VerticalDivider(
                  width: 1,
                  color: isDark ? AppColors.slate700 : AppColors.slate200),
              // ── Time B ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(
                        labelB, colorB, winner == 'TeamB' || winner == 'Draw'),
                    ...teamB.map(buildPlayer),
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

class _ConfiguredBetStats extends ConsumerWidget {
  final String groupId;
  final int? goals;
  final int? assists;
  final bool isDark;

  const _ConfiguredBetStats({
    required this.groupId,
    required this.goals,
    required this.assists,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icons = GroupIcons.from(
      ref.watch(groupSettingsProvider(groupId)).valueOrNull,
    );
    final color = isDark ? AppColors.slate400 : AppColors.slate500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (goals != null) ...[
          Text('$goals', style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(width: 2),
          renderGroupIcon(icons.goal, size: 11, color: color),
        ],
        if (goals != null && assists != null) const SizedBox(width: 6),
        if (assists != null) ...[
          Text('$assists', style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(width: 2),
          renderGroupIcon(icons.assist, size: 11, color: color),
        ],
      ],
    );
  }
}

// ── NumberStepper ─────────────────────────────────────────────────────────────

enum _StepperSize { small, medium, large }

class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final bool disabled;
  final bool isDark;
  final ValueChanged<int> onChange;
  final _StepperSize size;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.disabled,
    required this.isDark,
    required this.onChange,
    this.size = _StepperSize.medium,
  });

  double get _btnSize => switch (size) {
        _StepperSize.small => 28,
        _StepperSize.medium => 34,
        _StepperSize.large => 40,
      };

  double get _fontSize => switch (size) {
        _StepperSize.small => 12,
        _StepperSize.medium => 14,
        _StepperSize.large => 18,
      };

  @override
  Widget build(BuildContext context) {
    final btnBg = isDark ? AppColors.slate700 : AppColors.slate100;
    final txtCol = isDark ? AppColors.slate200 : AppColors.slate700;

    Widget btn(String label, bool enabled, VoidCallback fn) => SizedBox(
          width: _btnSize,
          height: _btnSize,
          child: Material(
            color: enabled ? btnBg : btnBg.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: enabled && !disabled ? fn : null,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? txtCol
                              : txtCol.withValues(alpha: .35)))),
            ),
          ),
        );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn('−', value > min, () => onChange((value - step).clamp(min, max))),
      SizedBox(
        width: _btnSize + 8,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.onDark : AppColors.slate900),
        ),
      ),
      btn('+', value < max, () => onChange((value + step).clamp(min, max))),
    ]);
  }
}

// ── Add category button ───────────────────────────────────────────────────────

class _AddCatBtn extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _AddCatBtn(
      {required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                style: BorderStyle.solid,
                color: isDark ? AppColors.slate600 : AppColors.slate300),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              )),
        ),
      );
}

// ── Small button ──────────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool isDark;
  const _SmallBtn({
    required this.label,
    required this.onTap,
    required this.isDark,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppColors.rose500
        : (isDark ? AppColors.slate700 : AppColors.slate200);
    final fg = danger
        ? AppColors.onDark
        : (isDark ? AppColors.slate200 : AppColors.slate700);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            )),
      ),
    );
  }
}

// ── Bet closed banner ─────────────────────────────────────────────────────────

class _BetClosedBanner extends StatelessWidget {
  final String statusName;
  final bool isDark;
  const _BetClosedBanner({required this.statusName, required this.isDark});

  String get _reason {
    final s = statusName.toLowerCase();
    if (s == 'acceptation') {
      return 'As apostas abrem quando o Matchmaking começar.';
    }
    if (s == 'matchmaking') {
      return 'Aguardando a formação dos times.';
    }
    if (s == 'started') {
      return 'A partida já foi iniciada. As apostas estão encerradas.';
    }
    if (s == 'ended' || s == 'postgame' || s == 'finalized') {
      return 'A partida encerrou. As apostas estão fechadas.';
    }
    return 'Apostas não disponíveis nesta etapa.';
  }

  bool get _isMatchMaking => statusName.toLowerCase() == 'matchmaking';

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isMatchMaking
              ? (isDark
                  ? AppColors.warningLight.withValues(alpha: .2)
                  : AppColors.amber50)
              : (isDark ? AppColors.slate800 : AppColors.slate50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isMatchMaking
                ? (isDark ? AppColors.warningLight : AppColors.amber200)
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Row(children: [
          Icon(Icons.lock_outline_rounded,
              size: 18,
              color:
                  _isMatchMaking ? AppColors.warningLight : AppColors.slate400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apostas indisponíveis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isMatchMaking
                          ? AppColors.warningLight
                          : (isDark ? AppColors.slate200 : AppColors.slate700),
                    )),
                const SizedBox(height: 2),
                Text(_reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isMatchMaking
                          ? AppColors.warningLight
                          : (isDark ? AppColors.slate400 : AppColors.slate500),
                    )),
              ],
            ),
          ),
        ]),
      );
}

// ── Empty match state ─────────────────────────────────────────────────────────

class _EmptyMatchState extends StatelessWidget {
  final bool isDark;
  const _EmptyMatchState({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_soccer_outlined,
              size: 48,
              color: isDark ? AppColors.slate600 : AppColors.slate300),
          const SizedBox(height: 16),
          Text('Nenhuma partida em andamento',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.slate400 : AppColors.slate500)),
          const SizedBox(height: 6),
          Text(
            'As apostas ficam disponíveis durante o matchmaking.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.slate500 : AppColors.slate400),
          ),
        ]),
      ));
}
