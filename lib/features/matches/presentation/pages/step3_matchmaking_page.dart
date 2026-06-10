import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/match_models.dart';
import '../providers/match_provider.dart';
import '../widgets/match_flyer.dart';

const _kStrategies = [
  (id: 1, label: 'Manual'),
  (id: 2, label: 'Aleatório'),
  (id: 3, label: 'Algoritmo'),
  (id: 4, label: 'Por Vitórias'),
];

class Step3MatchmakingPage extends ConsumerStatefulWidget {
  const Step3MatchmakingPage({super.key});

  @override
  ConsumerState<Step3MatchmakingPage> createState() => _Step3State();
}

class _Step3State extends ConsumerState<Step3MatchmakingPage> {
  int  _strategyType       = 3;
  int  _playersPerTeam     = 6;
  bool _includeGoalkeepers = true;

  // Cores
  bool    _editingColors     = false;
  String? _selectedTeamAColorId;
  String? _selectedTeamBColorId;

  // Geração
  bool _generatedOnce = false;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false) || (acc?.isAdmin ?? false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(matchNotifierProvider);
      _selectedTeamAColorId = s.teamAColor?.id;
      _selectedTeamBColorId = s.teamBColor?.id;
      if (_selectedTeamAColorId == null && s.availableColors.isNotEmpty) {
        _selectedTeamAColorId = s.availableColors[0].id;
        _selectedTeamBColorId = s.availableColors.length > 1
            ? s.availableColors[1].id
            : s.availableColors[0].id;
      }
      setState(() {});
    });
  }

  Future<void> _applyColors() async {
    if (_selectedTeamAColorId == null || _selectedTeamBColorId == null) return;
    await ref.read(matchNotifierProvider.notifier)
        .setColors(_selectedTeamAColorId!, _selectedTeamBColorId!);
    // Only close editor on success; error path is handled by ref.listen
    if (ref.read(matchNotifierProvider).error == null) {
      setState(() => _editingColors = false);
    }
  }

  Future<void> _generateTeams() async {
    await ref.read(matchNotifierProvider.notifier).generateTeams(
      strategyType:       _strategyType,
      playersPerTeam:     _playersPerTeam,
      includeGoalkeepers: _includeGoalkeepers,
    );
    setState(() => _generatedOnce = true);
  }

  Future<void> _startMatch() async {
    await ref.read(matchNotifierProvider.notifier).startMatch();
  }

  @override
  Widget build(BuildContext context) {
    // Sincroniza cores locais sempre que o provider atualizar teamAColor/teamBColor
    // e exibe erros via snackbar.
    ref.listen<MatchState>(matchNotifierProvider, (prev, next) {
      final aChanged = prev?.teamAColor?.id != next.teamAColor?.id;
      final bChanged = prev?.teamBColor?.id != next.teamBColor?.id;
      if (aChanged || bChanged) {
        setState(() {
          if (next.teamAColor != null) _selectedTeamAColorId = next.teamAColor!.id;
          if (next.teamBColor != null) _selectedTeamBColorId = next.teamBColor!.id;
          _editingColors = false; // fecha o painel após aplicar
        });
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(matchNotifierProvider.notifier).clearError();
      }
    });

    final s      = ref.watch(matchNotifierProvider);
    final colors = s.availableColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colorsSet   = s.colorsLocked || (s.teamAColor != null && s.teamBColor != null);
    final hasOptions  = s.teamGenOptions.isNotEmpty;
    final teamsSet    = s.teamsAssigned;

    final teamAColor = colors.firstWhere(
      (c) => c.id == _selectedTeamAColorId,
      orElse: () => s.teamAColor ?? (colors.isNotEmpty ? colors[0] : _nullColor),
    );
    final teamBColor = colors.firstWhere(
      (c) => c.id == _selectedTeamBColorId,
      orElse: () => s.teamBColor ?? (colors.length > 1 ? colors[1] : _nullColor),
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Seção: Cores dos times ──────────────────────────────────────
            if (_isAdmin && colors.isNotEmpty) ...[
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: título + tabs
                    Row(
                      children: [
                        Text(
                          'Cores dos times',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? AppColors.slate100 : AppColors.slate900,
                          ),
                        ),
                        const Spacer(),
                        // Tabs: Editar | Manual | Aleatório
                        _TabBar(
                          tabs: colorsSet && !_editingColors
                              ? const ['Editar', 'Aleatório']
                              : const ['Manual', 'Aleatório'],
                          selectedIdx: 0,
                          onTap: (i) {
                            if (colorsSet && !_editingColors && i == 0) {
                              setState(() => _editingColors = true);
                            } else if (i == (colorsSet && !_editingColors ? 1 : 1)) {
                              ref.read(matchNotifierProvider.notifier).setColorsRandom();
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (colorsSet && !_editingColors) ...[
                      // Cores já definidas — exibição compacta
                      Text(
                        'Cores já definidas.',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ColorChip(color: s.teamAColor, label: 'TIME A'),
                          const SizedBox(width: 16),
                          _ColorChip(color: s.teamBColor, label: 'TIME B'),
                        ],
                      ),
                    ] else ...[
                      // Editor de cores
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ColorPickerSection(
                            label: 'TIME A',
                            colors: colors,
                            selectedId: _selectedTeamAColorId,
                            onChanged: (id) => setState(() => _selectedTeamAColorId = id),
                            isDark: isDark,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _ColorPickerSection(
                            label: 'TIME B',
                            colors: colors,
                            selectedId: _selectedTeamBColorId,
                            onChanged: (id) => setState(() => _selectedTeamBColorId = id),
                            isDark: isDark,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: s.mutating ? null : _applyColors,
                          child: const Text('Aplicar cores'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Seção: Gerar Times ──────────────────────────────────────────
            if (_isAdmin) ...[
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Algoritmo
                    DropdownButtonFormField<int>(
                      value: _strategyType,
                      decoration: const InputDecoration(
                        labelText: 'Algoritmo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _kStrategies
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _strategyType = v ?? 3),
                    ),
                    const SizedBox(height: 12),
                    // Players/Team
                    TextFormField(
                      initialValue: '$_playersPerTeam',
                      decoration: const InputDecoration(
                        labelText: 'Players/Team',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) setState(() => _playersPerTeam = n);
                      },
                    ),
                    const SizedBox(height: 8),
                    // Checkbox Incluir goleiros
                    CheckboxListTile(
                      value: _includeGoalkeepers,
                      onChanged: (v) => setState(() => _includeGoalkeepers = v ?? true),
                      title: const Text('Incluir goleiros', style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 4),
                    // Botão Gerar times
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.slate900),
                        onPressed: s.mutating ? null : _generateTeams,
                        child: s.mutating
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Gerar times', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Seção: Opções geradas ───────────────────────────────────────
            if (hasOptions) ...[
              _TeamGenOptionsSection(
                options:     s.teamGenOptions,
                selectedIdx: s.selectedTeamGenIdx,
                teamAColor:  s.teamAColor,
                teamBColor:  s.teamBColor,
                isAdmin:     _isAdmin,
                mutating:    s.mutating,
                isDark:      isDark,
                onSelectIdx: (i) => ref.read(matchNotifierProvider.notifier).selectTeamGenOption(i),
                onConfirm:   () => ref.read(matchNotifierProvider.notifier).assignTeamsFromGenerated(),
                onRegenerate: _generateTeams,
              ),
              const SizedBox(height: 12),
            ],

            // ── Times já atribuídos (sem opções no carrossel) ───────────────
            if (!hasOptions && teamsSet) ...[
              _AssignedTeamsSection(
                s:       s,
                isAdmin: _isAdmin,
                isDark:  isDark,
                onNoShow: (matchPlayerId, noShow) => ref
                    .read(matchNotifierProvider.notifier)
                    .setNoShow(matchPlayerId, noShow),
              ),
              const SizedBox(height: 12),
              // ── Card da partida ───────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () {
                  final acc = ref.read(accountStoreProvider).activeAccount;
                  final gid = acc?.activeGroupId ?? '';
                  final dio = ref.read(dioProvider);
                  showMatchCardDialog(
                    context: context, s: s, groupId: gid, dio: dio);
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Card da partida',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 12),

              if (s.unassignedPlayers.isNotEmpty) ...[
                _UnassignedSection(
                  players:    s.unassignedPlayers,
                  isAdmin:    _isAdmin,
                  isDark:     isDark,
                  teamALabel: s.teamAColor?.name ?? 'Time A',
                  teamBLabel: s.teamBColor?.name ?? 'Time B',
                  teamAColor: s.teamAColor?.color,
                  teamBColor: s.teamBColor?.color,
                  onAssign:   (pid, toA) => ref
                      .read(matchNotifierProvider.notifier)
                      .assignUnassigned(pid, toA),
                ),
                const SizedBox(height: 12),
              ],
              if (_isAdmin) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: s.mutating ? null : _startMatch,
                    icon: s.mutating
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sports_soccer_rounded, size: 18),
                    label: s.mutating
                        ? const SizedBox.shrink()
                        : const Text('Iniciar partida', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // ── Placeholder (nem times nem opções) ──────────────────────────
            if (!hasOptions && !teamsSet && !_generatedOnce)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    _isAdmin
                        ? 'Configure as opções acima e clique em "Gerar times".'
                        : 'Aguardando o admin montar os times.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder de cor nula ───────────────────────────────────────────────────

final _nullColor = TeamColorInfo(id: '', name: '—', hexValue: '#cbd5e1');

// ── Opções geradas + carrossel ────────────────────────────────────────────────

class _TeamGenOptionsSection extends ConsumerStatefulWidget {
  final List<TeamGenOption> options;
  final int selectedIdx;
  final TeamColorInfo? teamAColor;
  final TeamColorInfo? teamBColor;
  final bool isAdmin;
  final bool mutating;
  final bool isDark;
  final void Function(int) onSelectIdx;
  final VoidCallback onConfirm;
  final VoidCallback onRegenerate;

  const _TeamGenOptionsSection({
    required this.options,
    required this.selectedIdx,
    required this.teamAColor,
    required this.teamBColor,
    required this.isAdmin,
    required this.mutating,
    required this.isDark,
    required this.onSelectIdx,
    required this.onConfirm,
    required this.onRegenerate,
  });

  @override
  ConsumerState<_TeamGenOptionsSection> createState() => _TeamGenOptionsSectionState();
}

class _TeamGenOptionsSectionState extends ConsumerState<_TeamGenOptionsSection> {
  bool    _showExplanation = false;
  String? _selectedA;
  String? _selectedB;

  @override
  void didUpdateWidget(_TeamGenOptionsSection old) {
    super.didUpdateWidget(old);
    if (old.selectedIdx != widget.selectedIdx) {
      _selectedA = null;
      _selectedB = null;
    }
  }

  void _moveToB() {
    if (_selectedA == null) return;
    final opt = widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final player = opt.teamA.firstWhere((p) => p.playerId == _selectedA);
    ref.read(matchNotifierProvider.notifier).editTeamGenOption(
      widget.selectedIdx,
      opt.teamA.where((p) => p.playerId != _selectedA).toList(),
      [...opt.teamB, player],
    );
    setState(() { _selectedA = null; _selectedB = null; });
  }

  void _moveToA() {
    if (_selectedB == null) return;
    final opt = widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final player = opt.teamB.firstWhere((p) => p.playerId == _selectedB);
    ref.read(matchNotifierProvider.notifier).editTeamGenOption(
      widget.selectedIdx,
      [...opt.teamA, player],
      opt.teamB.where((p) => p.playerId != _selectedB).toList(),
    );
    setState(() { _selectedA = null; _selectedB = null; });
  }

  void _swap() {
    if (_selectedA == null || _selectedB == null) return;
    final opt = widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final pA = opt.teamA.firstWhere((p) => p.playerId == _selectedA);
    final pB = opt.teamB.firstWhere((p) => p.playerId == _selectedB);
    ref.read(matchNotifierProvider.notifier).editTeamGenOption(
      widget.selectedIdx,
      opt.teamA.map((p) => p.playerId == _selectedA ? pB : p).toList(),
      opt.teamB.map((p) => p.playerId == _selectedB ? pA : p).toList(),
    );
    setState(() { _selectedA = null; _selectedB = null; });
  }

  @override
  Widget build(BuildContext context) {
    final opt   = widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final total = widget.options.length;
    final cur   = widget.selectedIdx + 1;
    final exp   = opt.explanation;

    final aColor = widget.teamAColor?.color ?? AppColors.blue500;
    final bColor = widget.teamBColor?.color ?? AppColors.slate400;
    final aName  = widget.teamAColor?.name  ?? 'Time A';
    final bName  = widget.teamBColor?.name  ?? 'Time B';

    return _SectionCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header com navegação ──────────────────────────────────────────
          Row(
            children: [
              Text(
                'Opções geradas',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: widget.isDark ? AppColors.slate100 : AppColors.slate900,
                ),
              ),
              const Spacer(),
              // Dots
              Row(
                children: List.generate(total, (i) => GestureDetector(
                  onTap: () => widget.onSelectIdx(i),
                  child: Container(
                    width: i == widget.selectedIdx ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == widget.selectedIdx
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.slate300,
                    ),
                  ),
                )),
              ),
              const SizedBox(width: 8),
              // Setas
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: cur > 1,
                onTap: () => widget.onSelectIdx(widget.selectedIdx - 1),
              ),
              const SizedBox(width: 4),
              Text('$cur/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: cur < total,
                onTap: () => widget.onSelectIdx(widget.selectedIdx + 1),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Stats: Peso + Diff ────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                icon: Icons.fitness_center_outlined,
                label: 'Peso',
                valueA: opt.teamAWeight,
                valueB: opt.teamBWeight,
                isDark: widget.isDark,
              ),
              const SizedBox(width: 8),
              _DiffChip(value: opt.balanceDiff, isDark: widget.isDark),
            ],
          ),

          // ── Stats: Ataque / Defesa / Físico ──────────────────────────────
          if (opt.attackDiff != null || opt.defenseDiff != null || opt.physicalDiff != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (opt.attackDiff != null)
                  Expanded(child: _DimStat(label: 'Ataque',  diff: opt.attackDiff!,   isDark: widget.isDark)),
                if (opt.defenseDiff != null)
                  Expanded(child: _DimStat(label: 'Defesa',  diff: opt.defenseDiff!,  isDark: widget.isDark)),
                if (opt.physicalDiff != null)
                  Expanded(child: _DimStat(label: 'Físico',  diff: opt.physicalDiff!, isDark: widget.isDark)),
              ],
            ),
          ],

          // ── Explicação ────────────────────────────────────────────────────
          if (exp != null && exp.resumo.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showExplanation = !_showExplanation),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    _showExplanation ? 'Ocultar análise' : 'Ver análise',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                ],
              ),
            ),
            if (_showExplanation) ...[
              const SizedBox(height: 8),
              _ExplanationBlock(exp: exp, isDark: widget.isDark),
            ],
          ],

          const SizedBox(height: 14),

          // ── Listas de jogadores com seleção ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TeamPlayerList(
                teamName:        aName,
                color:           aColor,
                players:         opt.teamA,
                isDark:          widget.isDark,
                selectedPlayerId: _selectedA,
                onPlayerTap: widget.isAdmin ? (pid) => setState(() {
                  _selectedA = _selectedA == pid ? null : pid;
                }) : null,
              )),
              const SizedBox(width: 8),
              Expanded(child: _TeamPlayerList(
                teamName:        bName,
                color:           bColor,
                players:         opt.teamB,
                isDark:          widget.isDark,
                selectedPlayerId: _selectedB,
                onPlayerTap: widget.isAdmin ? (pid) => setState(() {
                  _selectedB = _selectedB == pid ? null : pid;
                }) : null,
              )),
            ],
          ),

          // ── Jogadores não atribuídos (ex: goleiros) ───────────────────────
          if (opt.unassigned.isNotEmpty) ...[
            const SizedBox(height: 10),
            _UnassignedGenSection(
              players:    opt.unassigned,
              isAdmin:    widget.isAdmin,
              isDark:     widget.isDark,
              teamALabel: aName,
              teamBLabel: bName,
              teamAColor: aColor,
              teamBColor: bColor,
              onAssign: (pid, toA) {
                final player = opt.unassigned.firstWhere((p) => p.playerId == pid);
                ref.read(matchNotifierProvider.notifier).editTeamGenOption(
                  widget.selectedIdx,
                  toA ? [...opt.teamA, player] : opt.teamA,
                  toA ? opt.teamB : [...opt.teamB, player],
                  unassigned: opt.unassigned.where((p) => p.playerId != pid).toList(),
                );
              },
            ),
          ],


          if (widget.isAdmin) ...[
            const SizedBox(height: 10),

            // ── Botões mover / trocar ─────────────────────────────────────
            Builder(builder: (context) {
              final canMoveToA  = _selectedB != null && _selectedA == null;
              final canMoveToB  = _selectedA != null && _selectedB == null;
              final canSwap     = _selectedA != null && _selectedB != null;
              // Fallback visual para cores claras
              final uiA = aColor.computeLuminance() > 0.7 ? AppColors.slate600 : aColor;
              final uiB = bColor.computeLuminance() > 0.7 ? AppColors.slate600 : bColor;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: canMoveToA ? uiA : AppColors.slate400,
                        backgroundColor: canMoveToA ? uiA.withValues(alpha: 0.08) : null,
                        side: BorderSide(
                          color: canMoveToA ? uiA : AppColors.slate300,
                          width: canMoveToA ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: canMoveToA ? _moveToA : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: Text('<< $aName', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: canSwap
                        ? IconButton(
                            onPressed: _swap,
                            icon: Icon(Icons.swap_horiz, size: 22,
                                color: Theme.of(context).colorScheme.primary),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                          )
                        : const Icon(Icons.swap_horiz, size: 18, color: AppColors.slate300),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: canMoveToB ? uiB : AppColors.slate400,
                        backgroundColor: canMoveToB ? uiB.withValues(alpha: 0.08) : null,
                        side: BorderSide(
                          color: canMoveToB ? uiB : AppColors.slate300,
                          width: canMoveToB ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: canMoveToB ? _moveToB : null,
                      icon: Text('$bName >>', style: const TextStyle(fontSize: 12)),
                      label: const Icon(Icons.chevron_right, size: 16),
                    ),
                  ),
                ],
              );
            }),

            // ── Hint ──────────────────────────────────────────────────────
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final canSwap = _selectedA != null && _selectedB != null;
              String hint;
              if (canSwap) {
                hint = 'Toque ⇄ para trocar os jogadores selecionados';
              } else if (_selectedA != null) {
                hint = 'Toque em "$bName >>" para mover para o $bName';
              } else if (_selectedB != null) {
                hint = 'Toque em "<< $aName" para mover para o $aName';
              } else {
                hint = 'Toque em um jogador para movê-lo de time';
              }
              return Text(
                hint,
                style: TextStyle(
                  fontSize: 11,
                  color: (_selectedA != null || _selectedB != null)
                      ? Colors.amber.shade700
                      : AppColors.slate400,
                ),
                textAlign: TextAlign.center,
              );
            }),
          ],

          if (widget.isAdmin) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Escolha uma opção acima e confirme aqui.',
              style: TextStyle(fontSize: 12, color: widget.isDark ? AppColors.slate400 : AppColors.slate500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.mutating ? null : widget.onRegenerate,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Gerar prévia', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.mutating ? null : widget.onConfirm,
                    child: widget.mutating
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Setar times', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Times já atribuídos ───────────────────────────────────────────────────────

class _AssignedTeamsSection extends StatelessWidget {
  final MatchState s;
  final bool isAdmin;
  final bool isDark;
  final void Function(String matchPlayerId, bool noShow)? onNoShow;

  const _AssignedTeamsSection({
    required this.s,
    required this.isAdmin,
    required this.isDark,
    this.onNoShow,
  });

  static String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  Widget _buildPlayerList(List<MatchPlayerInfo> players, Color color, String teamName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: color.computeLuminance() > 0.7
                        ? AppColors.slate400
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  teamName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: isDark ? AppColors.slate100 : AppColors.slate900,
                  ),
                ),
              ),
              Icon(Icons.sports_soccer, size: 13, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...players.map((p) {
          final absent = p.didNotPlay;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            decoration: BoxDecoration(
              color: absent ? AppColors.rose50.withValues(alpha: isDark ? 0.1 : 1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: absent
                        ? AppColors.rose200.withValues(alpha: 0.4)
                        : color.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      _initial(p.playerName),
                      style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: absent ? AppColors.rose400 : color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.playerName,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: absent
                              ? (isDark ? AppColors.slate500 : AppColors.slate400)
                              : (isDark ? AppColors.slate100 : AppColors.slate800),
                          decoration: absent ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.isGoalkeeper)
                        const Text('Goleiro', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
                    ],
                  ),
                ),
                if (isAdmin && onNoShow != null)
                  GestureDetector(
                    onTap: () => onNoShow!(p.matchPlayerId, !absent),
                    child: Tooltip(
                      message: absent ? 'Marcar como presente' : 'Marcar como não foi',
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: absent
                              ? AppColors.rose50.withValues(alpha: isDark ? 0.15 : 1)
                              : (isDark ? AppColors.slate800 : AppColors.slate100),
                          border: Border.all(
                            color: absent ? AppColors.rose200 : (isDark ? AppColors.slate600 : AppColors.slate300),
                          ),
                        ),
                        child: Icon(
                          absent ? Icons.person_off_rounded : Icons.person_rounded,
                          size: 13,
                          color: absent ? AppColors.rose400 : (isDark ? AppColors.slate400 : AppColors.slate500),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final aColor = s.teamAColor?.color ?? AppColors.blue500;
    final bColor = s.teamBColor?.color ?? AppColors.slate400;
    final aName  = s.teamAColor?.name  ?? 'Time A';
    final bName  = s.teamBColor?.name  ?? 'Time B';

    return _SectionCard(
      isDark: isDark,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildPlayerList(s.teamAPlayers, aColor, aName)),
          const SizedBox(width: 8),
          Expanded(child: _buildPlayerList(s.teamBPlayers, bColor, bName)),
        ],
      ),
    );
  }
}

// ── Sem time (times já atribuídos) ───────────────────────────────────────────

class _UnassignedSection extends StatelessWidget {
  final List<MatchPlayerInfo> players;
  final bool isAdmin;
  final bool isDark;
  final String teamALabel;
  final String teamBLabel;
  final Color? teamAColor;
  final Color? teamBColor;
  final void Function(String pid, bool toA) onAssign;

  const _UnassignedSection({
    required this.players,
    required this.isAdmin,
    required this.isDark,
    required this.onAssign,
    this.teamALabel = 'A',
    this.teamBLabel = 'B',
    this.teamAColor,
    this.teamBColor,
  });

  static String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorA = teamAColor ?? AppColors.blue500;
    final colorB = teamBColor ?? AppColors.slate400;
    return _SectionCard(
      isDark: isDark,
      borderColor: isDark
          ? AppColors.amber400.withValues(alpha: 0.35)
          : AppColors.amber200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com ícone amber
          Row(
            children: [
              const Icon(Icons.person_off_outlined, size: 15, color: AppColors.amber500),
              const SizedBox(width: 6),
              Text(
                'Não atribuídos (${players.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.amber500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...players.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Avatar amber
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber200,
                  ),
                  child: Center(
                    child: Text(
                      _initial(p.playerName),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.playerName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.slate100 : AppColors.slate800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.isGoalkeeper)
                        const Text('Goleiro', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  _AssignButton(label: '→ $teamALabel', color: colorA, onTap: () => onAssign(p.playerId, true)),
                  const SizedBox(width: 4),
                  _AssignButton(label: '→ $teamBLabel', color: colorB, onTap: () => onAssign(p.playerId, false)),
                ],
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Sem time (opções geradas) ─────────────────────────────────────────────────

class _UnassignedGenSection extends StatelessWidget {
  final List<TeamGenPlayer> players;
  final bool isAdmin;
  final bool isDark;
  final String teamALabel;
  final String teamBLabel;
  final Color teamAColor;
  final Color teamBColor;
  final void Function(String pid, bool toA) onAssign;

  const _UnassignedGenSection({
    required this.players,
    required this.isAdmin,
    required this.isDark,
    required this.teamALabel,
    required this.teamBLabel,
    required this.teamAColor,
    required this.teamBColor,
    required this.onAssign,
  });

  static String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      borderColor: isDark
          ? AppColors.amber400.withValues(alpha: 0.35)
          : AppColors.amber200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_off_outlined, size: 15, color: AppColors.amber500),
              const SizedBox(width: 6),
              Text(
                'Não atribuídos (${players.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.amber500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...players.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber200,
                  ),
                  child: Center(
                    child: Text(
                      _initial(p.name),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.slate100 : AppColors.slate800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.isGoalkeeper)
                        const Text('Goleiro', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
                    ],
                  ),
                ),
                if (p.weight > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      p.weight.toStringAsFixed(3),
                      style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                    ),
                  ),
                if (isAdmin) ...[
                  _AssignButton(label: '→ $teamALabel', color: teamAColor, onTap: () => onAssign(p.playerId, true)),
                  const SizedBox(width: 4),
                  _AssignButton(label: '→ $teamBLabel', color: teamBColor, onTap: () => onAssign(p.playerId, false)),
                ],
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Botão de atribuição ───────────────────────────────────────────────────────

class _AssignButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AssignButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uiColor = color.computeLuminance() > 0.7 ? AppColors.slate600 : color;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: uiColor,
        backgroundColor: uiColor.withValues(alpha: 0.08),
        side: BorderSide(color: uiColor, width: 1.5),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Lista de jogadores de um time ─────────────────────────────────────────────

class _TeamPlayerList extends StatelessWidget {
  final String teamName;
  final Color  color;
  final List<TeamGenPlayer> players;
  final bool   isDark;
  final String? selectedPlayerId;
  final void Function(String)? onPlayerTap;

  const _TeamPlayerList({
    required this.teamName, required this.color,
    required this.players,  required this.isDark,
    this.selectedPlayerId,  this.onPlayerTap,
  });

  static String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Cores claras (ex: branco) ficam invisíveis — usa slate como fallback visual
    final isLight    = color.computeLuminance() > 0.7;
    final uiColor    = isLight ? AppColors.slate600 : color;
    final dotBorder  = isLight ? AppColors.slate400 : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header do time
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: uiColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: dotBorder, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  teamName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: isDark ? AppColors.slate100 : AppColors.slate900,
                  ),
                ),
              ),
              Icon(Icons.sports_soccer, size: 13, color: uiColor.withValues(alpha: 0.7)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...players.map((p) {
          final isSelected = selectedPlayerId == p.playerId;
          return GestureDetector(
            onTap: onPlayerTap != null ? () => onPlayerTap!(p.playerId) : null,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? uiColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: uiColor.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: uiColor.withValues(alpha: isSelected ? 0.25 : 0.12),
                    ),
                    child: Center(
                      child: Text(
                        _initial(p.name),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: uiColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.slate100 : AppColors.slate800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.isGoalkeeper)
                          const Text('Goleiro', style: TextStyle(fontSize: 9, color: AppColors.slate400)),
                      ],
                    ),
                  ),
                  if (p.weight > 0)
                    Text(
                      p.weight.toStringAsFixed(3),
                      style: const TextStyle(fontSize: 11, color: AppColors.slate400),
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

// ── Chip de cor selecionada ───────────────────────────────────────────────────

class _ColorChip extends StatelessWidget {
  final TeamColorInfo? color;
  final String label;

  const _ColorChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    if (color == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color!.color,
            border: Border.all(
              color: color!.color.computeLuminance() > 0.7
                  ? AppColors.slate400
                  : AppColors.slate300,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text(color!.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ── Seletor de cor ────────────────────────────────────────────────────────────

class _ColorPickerSection extends StatelessWidget {
  final String label;
  final List<TeamColorInfo> colors;
  final String? selectedId;
  final void Function(String) onChanged;
  final bool isDark;

  const _ColorPickerSection({
    required this.label, required this.colors, this.selectedId,
    required this.onChanged, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = colors.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => colors.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.slate500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: colors.take(8).map((c) {
            final isSel   = c.id == selectedId;
            final isLight = c.color.computeLuminance() > 0.7;
            final borderColor = isSel
                ? (isLight ? AppColors.slate600 : AppColors.slate900)
                : (isLight ? AppColors.slate400 : AppColors.slate300);
            final checkColor  = isLight ? AppColors.slate800 : Colors.white;
            return GestureDetector(
              onTap: () => onChanged(c.id),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.color,
                  border: Border.all(color: borderColor, width: isSel ? 2 : 1.5),
                ),
                child: isSel
                    ? Icon(Icons.check, size: 14, color: checkColor)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected.color,
                border: Border.all(
                  color: selected.color.computeLuminance() > 0.7
                      ? AppColors.slate400
                      : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(selected.name, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
        ),
      ],
    );
  }
}

// ── Tab bar simples ───────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIdx;
  final void Function(int) onTap;

  const _TabBar({required this.tabs, required this.selectedIdx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(tabs.length, (i) {
        final sel = i == selectedIdx;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: EdgeInsets.only(left: i > 0 ? 4 : 0),
            decoration: BoxDecoration(
              color: sel ? AppColors.slate900 : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: sel ? AppColors.slate900 : AppColors.slate300),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.slate500,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Seta de navegação ─────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? AppColors.slate400 : AppColors.slate200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16,
          color: enabled ? AppColors.slate600 : AppColors.slate300),
    ),
  );
}

// ── Chip de peso ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double valueA;
  final double valueB;
  final bool isDark;

  const _StatChip({
    required this.icon, required this.label,
    required this.valueA, required this.valueB, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.slate400),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          const SizedBox(width: 6),
          Text(valueA.toStringAsFixed(3),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.blue500)),
          Text(' / ', style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          Text(valueB.toStringAsFixed(3),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate500)),
        ],
      ),
    );
  }
}

// ── Chip de diferença ─────────────────────────────────────────────────────────

class _DiffChip extends StatelessWidget {
  final double value;
  final bool isDark;

  const _DiffChip({required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isGood = value < 0.05;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? (isGood ? AppColors.emerald500.withValues(alpha: 0.15) : AppColors.amber500.withValues(alpha: 0.15))
            : (isGood ? AppColors.emerald50   : AppColors.amber50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood ? AppColors.emerald200 : AppColors.amber200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Diff', style: TextStyle(fontSize: 11, color: isGood ? AppColors.emerald700 : AppColors.orange700)),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: isGood ? AppColors.emerald700 : AppColors.orange700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estatística por dimensão ──────────────────────────────────────────────────

class _DimStat extends StatelessWidget {
  final String label;
  final double diff;
  final bool isDark;

  const _DimStat({required this.label, required this.diff, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
          const SizedBox(width: 4),
          Text(
            diff.toStringAsFixed(2),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Bloco de explicação ───────────────────────────────────────────────────────

class _ExplanationBlock extends StatelessWidget {
  final TeamGenExplanation exp;
  final bool isDark;

  const _ExplanationBlock({required this.exp, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exp.resumo.isNotEmpty)        _ExpSection(bold: 'Resumo:',    text: exp.resumo),
          if (exp.analiseTimeA.isNotEmpty)   _ExpSection(bold: 'Time A:',   text: exp.analiseTimeA),
          if (exp.analiseTimeB.isNotEmpty)   _ExpSection(bold: 'Time B:',   text: exp.analiseTimeB),
          if (exp.conclusao.isNotEmpty)      _ExpSection(bold: 'Conclusão:', text: exp.conclusao),
        ],
      ),
    );
  }
}

class _ExpSection extends StatelessWidget {
  final String bold;
  final String text;
  const _ExpSection({required this.bold, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: AppColors.slate600, height: 1.4),
        children: [
          TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate800)),
          TextSpan(text: text),
        ],
      ),
    ),
  );
}

// ── Card de seção ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color? borderColor;

  const _SectionCard({required this.child, required this.isDark, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? AppColors.slate900.withValues(alpha: 0.6) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? (isDark ? AppColors.slate700.withValues(alpha: 0.6) : AppColors.slate200),
      ),
      boxShadow: isDark ? null : [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
      ],
    ),
    child: child,
  );
}
