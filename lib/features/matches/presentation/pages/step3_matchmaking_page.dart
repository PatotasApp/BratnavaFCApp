import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../../../shared/presentation/widgets/horizontal_team_field.dart';
import '../../../auth/presentation/providers/account_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../group_settings/presentation/providers/group_settings_provider.dart';
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
  int _strategyType = 3;
  int _playersPerTeam = 6;
  bool _includeGoalkeepers = true;

  // Cores
  bool _editingColors = false;
  String? _selectedTeamAColorId;
  String? _selectedTeamBColorId;

  bool get _isAdmin {
    final acc = ref.read(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    return gid.isNotEmpty && (acc?.isGroupAdmin(gid) ?? false) ||
        (acc?.isAdmin ?? false);
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
    await ref
        .read(matchNotifierProvider.notifier)
        .setColors(_selectedTeamAColorId!, _selectedTeamBColorId!);
    // Only close editor on success; error path is handled by ref.listen
    if (ref.read(matchNotifierProvider).error == null) {
      setState(() => _editingColors = false);
    }
  }

  Future<void> _generateTeams() async {
    await ref.read(matchNotifierProvider.notifier).generateTeams(
          strategyType: _strategyType,
          playersPerTeam: _playersPerTeam,
          includeGoalkeepers: _includeGoalkeepers,
        );
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
          if (next.teamAColor != null) {
            _selectedTeamAColorId = next.teamAColor!.id;
          }
          if (next.teamBColor != null) {
            _selectedTeamBColorId = next.teamBColor!.id;
          }
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

    final s = ref.watch(matchNotifierProvider);
    final colors = s.availableColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final acc = ref.watch(accountStoreProvider).activeAccount;
    final gid = acc?.activeGroupId ?? '';
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);

    final colorsSet =
        s.colorsLocked || (s.teamAColor != null && s.teamBColor != null);
    final hasOptions = s.teamGenOptions.isNotEmpty;
    final teamsSet = s.teamsAssigned ||
        s.teamAPlayers.isNotEmpty ||
        s.teamBPlayers.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => ref.read(matchNotifierProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isAdmin) ...[
              _SectionCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _strategyType,
                      decoration: const InputDecoration(
                        labelText: 'Algoritmo',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _kStrategies
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _strategyType = v ?? 3),
                    ),
                    const SizedBox(height: 12),
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
                        if (n != null && n > 0) {
                          setState(() => _playersPerTeam = n);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _includeGoalkeepers,
                      onChanged: (v) =>
                          setState(() => _includeGoalkeepers = v ?? true),
                      title: const Text('Incluir goleiros',
                          style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.slate900),
                        onPressed: s.mutating ? null : _generateTeams,
                        child: s.mutating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Gerar times',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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
                            color: isDark
                                ? AppColors.slate100
                                : AppColors.slate900,
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
                            } else if (i ==
                                (colorsSet && !_editingColors ? 1 : 1)) {
                              ref
                                  .read(matchNotifierProvider.notifier)
                                  .setColorsRandom();
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
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500),
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
                          Expanded(
                              child: _ColorPickerSection(
                            label: 'TIME A',
                            colors: colors,
                            selectedId: _selectedTeamAColorId,
                            onChanged: (id) =>
                                setState(() => _selectedTeamAColorId = id),
                            isDark: isDark,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _ColorPickerSection(
                            label: 'TIME B',
                            colors: colors,
                            selectedId: _selectedTeamBColorId,
                            onChanged: (id) =>
                                setState(() => _selectedTeamBColorId = id),
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

            // ── Seção: Opções geradas ───────────────────────────────────────
            if (hasOptions) ...[
              _TeamGenOptionsSection(
                options: s.teamGenOptions,
                selectedIdx: s.selectedTeamGenIdx,
                teamAColor: s.teamAColor,
                teamBColor: s.teamBColor,
                isAdmin: _isAdmin,
                mutating: s.mutating,
                isDark: isDark,
                onSelectIdx: (i) => ref
                    .read(matchNotifierProvider.notifier)
                    .selectTeamGenOption(i),
                onConfirm: () => ref
                    .read(matchNotifierProvider.notifier)
                    .assignTeamsFromGenerated(),
                onRegenerate: _generateTeams,
              ),
              const SizedBox(height: 12),
            ] else if (!teamsSet) ...[
              if (_isAdmin)
                _DashedHint(
                  text: _isAdmin
                      ? 'Clique em Gerar times para ver as opções de sorteio.'
                      : 'Aguardando o admin montar os times.',
                  isDark: isDark,
                ),
              if (!_isAdmin) ...[
                _MatchSummaryCard(s: s, isDark: isDark),
                const SizedBox(height: 12),
                _WaitingTeamsCard(
                  s: s,
                  isDark: isDark,
                  onRefresh: () =>
                      ref.read(matchNotifierProvider.notifier).refresh(),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // ── Times já atribuídos (sem opções no carrossel) ───────────────
            if (teamsSet) ...[
              _AssignedTeamsSection(
                s: s,
                isDark: isDark,
                isAdmin: _isAdmin,
                onRefresh: () =>
                    ref.read(matchNotifierProvider.notifier).refresh(),
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
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Gerar card para o Instagram',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final acc = ref.read(accountStoreProvider).activeAccount;
                  final gid = acc?.activeGroupId ?? '';
                  final dio = ref.read(dioProvider);
                  showMatchCardDialog(
                      context: context, s: s, groupId: gid, dio: dio);
                },
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Compartilhar escalação',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: AppColors.blue600,
                  side: const BorderSide(color: AppColors.blue600),
                ),
              ),
              const SizedBox(height: 12),

              if (s.unassignedPlayers.isNotEmpty) ...[
                _UnassignedSection(
                  players: s.unassignedPlayers,
                  isAdmin: _isAdmin,
                  isDark: isDark,
                  teamALabel: s.teamAColor?.name ?? 'Time A',
                  teamBLabel: s.teamBColor?.name ?? 'Time B',
                  teamAColor: s.teamAColor?.color,
                  teamBColor: s.teamBColor?.color,
                  icons: icons,
                  onAssign: (pid, toA) => ref
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sports_soccer_rounded, size: 18),
                    label: s.mutating
                        ? const SizedBox.shrink()
                        : const Text('Iniciar partida',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Placeholder de cor nula ───────────────────────────────────────────────────

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
  ConsumerState<_TeamGenOptionsSection> createState() =>
      _TeamGenOptionsSectionState();
}

class _TeamGenOptionsSectionState
    extends ConsumerState<_TeamGenOptionsSection> {
  bool _showExplanation = false;
  String? _sel1Id;
  bool? _sel1IsTeamA;
  String? _sel2Id;
  bool? _sel2IsTeamA;

  @override
  void didUpdateWidget(_TeamGenOptionsSection old) {
    super.didUpdateWidget(old);
    if (old.selectedIdx != widget.selectedIdx) {
      _sel1Id = null;
      _sel1IsTeamA = null;
      _sel2Id = null;
      _sel2IsTeamA = null;
    }
  }

  // ignore: unused_element
  void _onFieldTap(String id, bool isTeamA) {
    if (!widget.isAdmin) return;
    if (_sel1Id == null) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
      });
      return;
    }
    if (_sel1Id == id) {
      setState(() {
        _sel1Id = null;
        _sel1IsTeamA = null;
      });
      return;
    }
    if (_sel1IsTeamA == isTeamA) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
      });
      return;
    }
    // Different teams — swap
    final id1 = _sel1Id!;
    final id1IsA = _sel1IsTeamA!;
    setState(() {
      _sel1Id = null;
      _sel1IsTeamA = null;
    });
    final opt =
        widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final p1 = id1IsA
        ? opt.teamA.firstWhere((p) => p.playerId == id1)
        : opt.teamB.firstWhere((p) => p.playerId == id1);
    final p2 = isTeamA
        ? opt.teamA.firstWhere((p) => p.playerId == id)
        : opt.teamB.firstWhere((p) => p.playerId == id);
    List<TeamGenPlayer> newA, newB;
    if (id1IsA) {
      newA = opt.teamA.map((p) => p.playerId == id1 ? p2 : p).toList();
      newB = opt.teamB.map((p) => p.playerId == id ? p1 : p).toList();
    } else {
      newA = opt.teamA.map((p) => p.playerId == id ? p1 : p).toList();
      newB = opt.teamB.map((p) => p.playerId == id1 ? p2 : p).toList();
    }
    ref
        .read(matchNotifierProvider.notifier)
        .editTeamGenOption(widget.selectedIdx, newA, newB);
  }

  TeamGenOption get _currentOption =>
      widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];

  void _clearGeneratedSelection() {
    setState(() {
      _sel1Id = null;
      _sel1IsTeamA = null;
      _sel2Id = null;
      _sel2IsTeamA = null;
    });
  }

  void _setGeneratedOption(
    List<TeamGenPlayer> teamA,
    List<TeamGenPlayer> teamB, {
    List<TeamGenPlayer>? unassigned,
  }) {
    ref.read(matchNotifierProvider.notifier).editTeamGenOption(
          widget.selectedIdx,
          teamA,
          teamB,
          unassigned: unassigned ?? _currentOption.unassigned,
        );
  }

  void _onGeneratedFieldTap(String id, bool isTeamA) {
    if (!widget.isAdmin) return;
    if (_sel1Id == null) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
      });
      return;
    }
    if (_sel1Id == id) {
      setState(() {
        _sel1Id = _sel2Id;
        _sel1IsTeamA = _sel2IsTeamA;
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    if (_sel2Id == id) {
      setState(() {
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    if (_sel2Id != null || _sel1IsTeamA == isTeamA) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    setState(() {
      _sel2Id = id;
      _sel2IsTeamA = isTeamA;
    });
  }

  TeamGenPlayer? _singleSelectedPlayer(TeamGenOption opt) {
    if (_sel1Id == null || _sel1IsTeamA == null || _sel2Id != null) {
      return null;
    }
    final players = _sel1IsTeamA! ? opt.teamA : opt.teamB;
    for (final player in players) {
      if (player.playerId == _sel1Id) return player;
    }
    return null;
  }

  void _moveSelectedTo(bool toTeamA) {
    final opt = _currentOption;
    if (_sel1Id == null || _sel1IsTeamA == null || _sel2Id != null) return;
    if (_sel1IsTeamA == toTeamA) return;

    final playerId = _sel1Id!;
    final player = _singleSelectedPlayer(opt);
    if (player == null) return;

    final baseA = opt.teamA.where((p) => p.playerId != playerId).toList();
    final baseB = opt.teamB.where((p) => p.playerId != playerId).toList();
    final unassigned =
        opt.unassigned.where((p) => p.playerId != playerId).toList();
    final teamA = toTeamA ? [...baseA, player] : baseA;
    final teamB = toTeamA ? baseB : [...baseB, player];

    _setGeneratedOption(teamA, teamB, unassigned: unassigned);
    _clearGeneratedSelection();
  }

  void _swapSelectedGeneratedPlayers() {
    if (_sel1Id == null ||
        _sel1IsTeamA == null ||
        _sel2Id == null ||
        _sel2IsTeamA == null ||
        _sel1IsTeamA == _sel2IsTeamA) {
      return;
    }

    final opt = _currentOption;
    final firstId = _sel1Id!;
    final secondId = _sel2Id!;
    final firstIsTeamA = _sel1IsTeamA!;
    final firstPlayer = firstIsTeamA
        ? opt.teamA.firstWhere((p) => p.playerId == firstId)
        : opt.teamB.firstWhere((p) => p.playerId == firstId);
    final secondPlayer = firstIsTeamA
        ? opt.teamB.firstWhere((p) => p.playerId == secondId)
        : opt.teamA.firstWhere((p) => p.playerId == secondId);

    final teamA = firstIsTeamA
        ? opt.teamA
            .map((p) => p.playerId == firstId ? secondPlayer : p)
            .toList()
        : opt.teamA
            .map((p) => p.playerId == secondId ? firstPlayer : p)
            .toList();
    final teamB = firstIsTeamA
        ? opt.teamB
            .map((p) => p.playerId == secondId ? firstPlayer : p)
            .toList()
        : opt.teamB
            .map((p) => p.playerId == firstId ? secondPlayer : p)
            .toList();

    _setGeneratedOption(teamA, teamB);
    _clearGeneratedSelection();
  }

  @override
  Widget build(BuildContext context) {
    final opt =
        widget.options[widget.selectedIdx.clamp(0, widget.options.length - 1)];
    final total = widget.options.length;
    final cur = widget.selectedIdx + 1;
    final exp = opt.explanation;

    final aColor = widget.teamAColor?.color ?? AppColors.blue500;
    final bColor = widget.teamBColor?.color ?? AppColors.slate400;
    final aName = widget.teamAColor?.name ?? 'Time A';
    final bName = widget.teamBColor?.name ?? 'Time B';
    final gid =
        ref.watch(accountStoreProvider).activeAccount?.activeGroupId ?? '';
    final icons =
        GroupIcons.from(ref.watch(groupSettingsProvider(gid)).valueOrNull);
    final hasSingleSelection = _sel1Id != null && _sel2Id == null;
    final canMoveToA = hasSingleSelection && _sel1IsTeamA == false;
    final canMoveToB = hasSingleSelection && _sel1IsTeamA == true;
    final canSwapSelection = _sel1Id != null &&
        _sel2Id != null &&
        _sel1IsTeamA != null &&
        _sel2IsTeamA != null &&
        _sel1IsTeamA != _sel2IsTeamA;

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
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color:
                      widget.isDark ? AppColors.slate100 : AppColors.slate900,
                ),
              ),
              const Spacer(),
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: cur > 1,
                onTap: () => widget.onSelectIdx(widget.selectedIdx - 1),
              ),
              const SizedBox(width: 8),
              Text('$cur/$total',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: cur < total,
                onTap: () => widget.onSelectIdx(widget.selectedIdx + 1),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              total,
              (i) => GestureDetector(
                onTap: () => widget.onSelectIdx(i),
                child: Container(
                  width: i == widget.selectedIdx ? 18 : 8,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: i == widget.selectedIdx
                        ? AppColors.slate900
                        : AppColors.slate300,
                  ),
                ),
              ),
            ),
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
          if (opt.attackDiff != null ||
              opt.defenseDiff != null ||
              opt.physicalDiff != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (opt.attackDiff != null)
                  Expanded(
                      child: _DimStat(
                          label: 'Ataque',
                          diff: opt.attackDiff!,
                          isDark: widget.isDark)),
                if (opt.defenseDiff != null)
                  Expanded(
                      child: _DimStat(
                          label: 'Defesa',
                          diff: opt.defenseDiff!,
                          isDark: widget.isDark)),
                if (opt.physicalDiff != null)
                  Expanded(
                      child: _DimStat(
                          label: 'Físico',
                          diff: opt.physicalDiff!,
                          isDark: widget.isDark)),
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
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Text(
                    _showExplanation ? 'Ocultar análise' : 'Ver análise',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.slate400),
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

          // ── Campo interativo ──────────────────────────────────────────────
          if (opt.teamA.isNotEmpty || opt.teamB.isNotEmpty) ...[
            if (widget.isAdmin) ...[
              _GeneratedTeamSwapBar(
                teamAName: aName,
                teamBName: bName,
                teamAColor: aColor,
                teamBColor: bColor,
                canMoveToA: canMoveToA,
                canMoveToB: canMoveToB,
                canSwap: canSwapSelection,
                onMoveToA: () => _moveSelectedTo(true),
                onMoveToB: () => _moveSelectedTo(false),
                onSwap: _swapSelectedGeneratedPlayers,
              ),
              const SizedBox(height: 12),
            ],
            HorizontalTeamField(
              teamA: opt.teamA
                  .map((p) => FieldPlayer(
                      id: p.playerId,
                      name: p.name,
                      isGoalkeeper: p.isGoalkeeper))
                  .toList(),
              teamB: opt.teamB
                  .map((p) => FieldPlayer(
                      id: p.playerId,
                      name: p.name,
                      isGoalkeeper: p.isGoalkeeper))
                  .toList(),
              teamAColor: aColor,
              teamBColor: bColor,
              canInteract: widget.isAdmin,
              sel1Id: _sel1Id,
              sel2Id: _sel2Id,
              onPlayerClick: _onGeneratedFieldTap,
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 6),
              Text(
                _sel2Id != null
                    ? 'Clique no botão central para trocar os jogadores.'
                    : _sel1Id != null
                        ? 'Use o botão do outro time para mover o jogador.'
                        : 'Toque em um jogador para selecioná-lo',
                style: TextStyle(
                  fontSize: 11,
                  color: _sel1Id != null
                      ? Colors.amber.shade700
                      : AppColors.slate400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
          ],

          // ── Jogadores não atribuídos (ex: goleiros) ───────────────────────
          if (opt.unassigned.isNotEmpty) ...[
            _UnassignedGenSection(
              players: opt.unassigned,
              isAdmin: widget.isAdmin,
              isDark: widget.isDark,
              teamALabel: aName,
              teamBLabel: bName,
              teamAColor: aColor,
              teamBColor: bColor,
              icons: icons,
              onAssign: (pid, toA) {
                final player =
                    opt.unassigned.firstWhere((p) => p.playerId == pid);
                ref.read(matchNotifierProvider.notifier).editTeamGenOption(
                      widget.selectedIdx,
                      toA ? [...opt.teamA, player] : opt.teamA,
                      toA ? opt.teamB : [...opt.teamB, player],
                      unassigned: opt.unassigned
                          .where((p) => p.playerId != pid)
                          .toList(),
                    );
              },
            ),
            const SizedBox(height: 10),
          ],

          if (widget.isAdmin) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Escolha uma opção acima e confirme aqui.',
              style: TextStyle(
                  fontSize: 12,
                  color:
                      widget.isDark ? AppColors.slate400 : AppColors.slate500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.mutating ? null : widget.onRegenerate,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Gerar prévia',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.mutating ? null : widget.onConfirm,
                    child: widget.mutating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Setar times',
                            style: TextStyle(fontSize: 13)),
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

class _AssignedTeamsSection extends ConsumerStatefulWidget {
  final MatchState s;
  final bool isDark;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _AssignedTeamsSection({
    required this.s,
    required this.isDark,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  ConsumerState<_AssignedTeamsSection> createState() =>
      _AssignedTeamsSectionState();
}

class _AssignedTeamsSectionState extends ConsumerState<_AssignedTeamsSection> {
  String? _sel1Id;
  bool? _sel1IsTeamA;
  String? _sel2Id;
  bool? _sel2IsTeamA;
  bool _swapping = false;

  void _onFieldTap(String id, bool isTeamA) {
    if (!widget.isAdmin || _swapping) return;
    if (_sel1Id == null) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
      });
      return;
    }
    if (_sel1Id == id) {
      setState(() {
        _sel1Id = _sel2Id;
        _sel1IsTeamA = _sel2IsTeamA;
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    if (_sel2Id == id) {
      setState(() {
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    if (_sel2Id != null || _sel1IsTeamA == isTeamA) {
      setState(() {
        _sel1Id = id;
        _sel1IsTeamA = isTeamA;
        _sel2Id = null;
        _sel2IsTeamA = null;
      });
      return;
    }
    setState(() {
      _sel2Id = id;
      _sel2IsTeamA = isTeamA;
    });
  }

  void _clearSelection() {
    setState(() {
      _sel1Id = null;
      _sel1IsTeamA = null;
      _sel2Id = null;
      _sel2IsTeamA = null;
    });
  }

  Future<void> _moveSelectedTo(bool toTeamA) async {
    if (_swapping ||
        _sel1Id == null ||
        _sel1IsTeamA == null ||
        _sel2Id != null ||
        _sel1IsTeamA == toTeamA) {
      return;
    }
    final id = _sel1Id!;
    final fromTeamA = _sel1IsTeamA!;
    setState(() => _swapping = true);
    await ref
        .read(matchNotifierProvider.notifier)
        .movePlayerToOtherTeam(id, fromTeamA);
    if (!mounted) return;
    _clearSelection();
    setState(() => _swapping = false);
  }

  Future<void> _swapSelectedPlayers() async {
    if (_swapping ||
        _sel1Id == null ||
        _sel2Id == null ||
        _sel1IsTeamA == null ||
        _sel2IsTeamA == null ||
        _sel1IsTeamA == _sel2IsTeamA) {
      return;
    }
    final id1 = _sel1Id!;
    final id2 = _sel2Id!;
    setState(() => _swapping = true);
    await ref.read(matchNotifierProvider.notifier).swapPlayers(id1, id2);
    if (!mounted) return;
    _clearSelection();
    setState(() => _swapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final aColor = s.teamAColor?.color ?? AppColors.blue500;
    final bColor = s.teamBColor?.color ?? AppColors.slate400;

    final fieldA = s.teamAPlayers
        .map((p) => FieldPlayer(
            id: p.playerId, name: p.playerName, isGoalkeeper: p.isGoalkeeper))
        .toList();
    final fieldB = s.teamBPlayers
        .map((p) => FieldPlayer(
            id: p.playerId, name: p.playerName, isGoalkeeper: p.isGoalkeeper))
        .toList();
    final aName = s.teamAColor?.name ?? 'Time A';
    final bName = s.teamBColor?.name ?? 'Time B';
    final hasSingleSelection = _sel1Id != null && _sel2Id == null;
    final canMoveToA = widget.isAdmin &&
        !_swapping &&
        hasSingleSelection &&
        _sel1IsTeamA == false;
    final canMoveToB = widget.isAdmin &&
        !_swapping &&
        hasSingleSelection &&
        _sel1IsTeamA == true;
    final canSwapSelection = widget.isAdmin &&
        !_swapping &&
        _sel1Id != null &&
        _sel2Id != null &&
        _sel1IsTeamA != null &&
        _sel2IsTeamA != null &&
        _sel1IsTeamA != _sel2IsTeamA;

    final field = HorizontalTeamField(
      teamA: fieldA,
      teamB: fieldB,
      teamAColor: aColor,
      teamBColor: bColor,
      canInteract: widget.isAdmin && !_swapping,
      sel1Id: _sel1Id,
      sel2Id: _sel2Id,
      onPlayerClick: _onFieldTap,
    );

    if (!widget.isAdmin) {
      return _SectionCard(
        isDark: widget.isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Times',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color:
                        widget.isDark ? AppColors.slate100 : AppColors.slate900,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 13),
                  label:
                      const Text('Recarregar', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TeamColorsLine(
              teamA: s.teamAColor,
              teamB: s.teamBColor,
              isDark: widget.isDark,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppColors.slate900.withValues(alpha: .35)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      widget.isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Times definidos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? AppColors.slate100
                          : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  field,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Times definidos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      widget.isDark ? AppColors.slate100 : AppColors.slate900,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 148,
                child: _GeneratedTeamSwapBar(
                  teamAName: aName,
                  teamBName: bName,
                  teamAColor: aColor,
                  teamBColor: bColor,
                  canMoveToA: canMoveToA,
                  canMoveToB: canMoveToB,
                  canSwap: canSwapSelection,
                  onMoveToA: () => _moveSelectedTo(true),
                  onMoveToB: () => _moveSelectedTo(false),
                  onSwap: _swapSelectedPlayers,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          field,
          if (widget.isAdmin) ...[
            const SizedBox(height: 6),
            if (_swapping)
              const Center(
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Text(
                _sel2Id != null
                    ? 'Use o botão central para trocar os jogadores.'
                    : _sel1Id != null
                        ? 'Use o botão do outro time para mover o jogador.'
                        : 'Toque em um jogador para selecioná-lo',
                style: TextStyle(
                  fontSize: 11,
                  color: _sel1Id != null
                      ? Colors.amber.shade700
                      : AppColors.slate400,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }
}

class _GeneratedTeamSwapBar extends StatelessWidget {
  final String teamAName;
  final String teamBName;
  final Color teamAColor;
  final Color teamBColor;
  final bool canMoveToA;
  final bool canMoveToB;
  final bool canSwap;
  final VoidCallback onMoveToA;
  final VoidCallback onMoveToB;
  final VoidCallback onSwap;

  const _GeneratedTeamSwapBar({
    required this.teamAName,
    required this.teamBName,
    required this.teamAColor,
    required this.teamBColor,
    required this.canMoveToA,
    required this.canMoveToB,
    required this.canSwap,
    required this.onMoveToA,
    required this.onMoveToB,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TeamSideButton(
            label: '<< $teamAName',
            color: teamAColor,
            alignEnd: true,
            enabled: canMoveToA,
            onTap: onMoveToA,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 34,
          child: FilledButton(
            onPressed: canSwap ? onSwap : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              disabledBackgroundColor: AppColors.slate200,
              disabledForegroundColor: AppColors.slate400,
              backgroundColor: AppColors.emerald200,
              foregroundColor: AppColors.emerald700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.swap_horiz_rounded, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TeamSideButton(
            label: '$teamBName >>',
            color: teamBColor,
            enabled: canMoveToB,
            onTap: onMoveToB,
          ),
        ),
      ],
    );
  }
}

class _TeamSideButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool alignEnd;
  final bool enabled;
  final VoidCallback onTap;

  const _TeamSideButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : AppColors.slate500;
    final icon = alignEnd
        ? Icons.keyboard_double_arrow_left
        : Icons.keyboard_double_arrow_right;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: enabled
              ? effectiveColor.withValues(alpha: .28)
              : AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 64;
            final iconWidget = Icon(icon, size: compact ? 18 : 16);
            final textWidget = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: effectiveColor,
              ),
            );
            return Align(
              alignment: compact
                  ? Alignment.center
                  : (alignEnd ? Alignment.centerRight : Alignment.centerLeft),
              child: IconTheme(
                data: IconThemeData(
                  color: effectiveColor,
                  size: compact ? 18 : 16,
                ),
                child: compact
                    ? iconWidget
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: alignEnd
                            ? [
                                iconWidget,
                                const SizedBox(width: 2),
                                Flexible(child: textWidget)
                              ]
                            : [
                                Flexible(child: textWidget),
                                const SizedBox(width: 2),
                                iconWidget
                              ],
                      ),
              ),
            );
          },
        ),
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
  final GroupIcons icons;
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
    this.icons = GroupIcons.defaults,
  });

  static String _initial(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
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
              const Icon(Icons.person_off_outlined,
                  size: 15, color: AppColors.amber500),
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
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
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
                              color: isDark
                                  ? AppColors.slate100
                                  : AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.isGoalkeeper)
                            renderGroupIcon(icons.goalkeeper,
                                size: 11, color: AppColors.slate400),
                        ],
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      _AssignButton(
                          label: '→ $teamALabel',
                          color: colorA,
                          onTap: () => onAssign(p.playerId, true)),
                      const SizedBox(width: 4),
                      _AssignButton(
                          label: '→ $teamBLabel',
                          color: colorB,
                          onTap: () => onAssign(p.playerId, false)),
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
  final GroupIcons icons;
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
    this.icons = GroupIcons.defaults,
  });

  static String _initial(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
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
              const Icon(Icons.person_off_outlined,
                  size: 15, color: AppColors.amber500),
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
                      width: 26,
                      height: 26,
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
                              color: isDark
                                  ? AppColors.slate100
                                  : AppColors.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.isGoalkeeper)
                            renderGroupIcon(icons.goalkeeper,
                                size: 11, color: AppColors.slate400),
                        ],
                      ),
                    ),
                    if (p.weight > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          p.weight.toStringAsFixed(3),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.slate400),
                        ),
                      ),
                    if (isAdmin) ...[
                      _AssignButton(
                          label: '→ $teamALabel',
                          color: teamAColor,
                          onTap: () => onAssign(p.playerId, true)),
                      const SizedBox(width: 4),
                      _AssignButton(
                          label: '→ $teamBLabel',
                          color: teamBColor,
                          onTap: () => onAssign(p.playerId, false)),
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

  const _AssignButton(
      {required this.label, required this.color, required this.onTap});

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
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
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
          width: 20,
          height: 20,
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
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.slate400)),
            Text(color!.name,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    required this.label,
    required this.colors,
    this.selectedId,
    required this.onChanged,
    required this.isDark,
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
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppColors.slate500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: colors.take(8).map((c) {
            final isSel = c.id == selectedId;
            final isLight = c.color.computeLuminance() > 0.7;
            final borderColor = isSel
                ? (isLight ? AppColors.slate600 : AppColors.slate900)
                : (isLight ? AppColors.slate400 : AppColors.slate300);
            final checkColor = isLight ? AppColors.slate800 : Colors.white;
            return GestureDetector(
              onTap: () => onChanged(c.id),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.color,
                  border:
                      Border.all(color: borderColor, width: isSel ? 2 : 1.5),
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
              width: 10,
              height: 10,
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
            Text(selected.name,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.slate500)),
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

  const _TabBar(
      {required this.tabs, required this.selectedIdx, required this.onTap});

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
              border: Border.all(
                  color: sel ? AppColors.slate900 : AppColors.slate300),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
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

  const _NavArrow(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            border: Border.all(
                color: enabled ? AppColors.slate400 : AppColors.slate200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 16,
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
    required this.icon,
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.slate400),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
          const SizedBox(width: 6),
          Text(valueA.toStringAsFixed(3),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue500)),
          const Text(' / ',
              style: TextStyle(fontSize: 11, color: AppColors.slate400)),
          Text(valueB.toStringAsFixed(3),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate500)),
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
            ? (isGood
                ? AppColors.emerald500.withValues(alpha: 0.15)
                : AppColors.amber500.withValues(alpha: 0.15))
            : (isGood ? AppColors.emerald50 : AppColors.amber50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood ? AppColors.emerald200 : AppColors.amber200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Diff',
              style: TextStyle(
                  fontSize: 11,
                  color: isGood ? AppColors.emerald700 : AppColors.orange700)),
          const SizedBox(width: 4),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
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

  const _DimStat(
      {required this.label, required this.diff, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
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
        border:
            Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exp.resumo.isNotEmpty)
            _ExpSection(bold: 'Resumo:', text: exp.resumo),
          if (exp.analiseTimeA.isNotEmpty)
            _ExpSection(bold: 'Time A:', text: exp.analiseTimeA),
          if (exp.analiseTimeB.isNotEmpty)
            _ExpSection(bold: 'Time B:', text: exp.analiseTimeB),
          if (exp.conclusao.isNotEmpty)
            _ExpSection(bold: 'Conclusão:', text: exp.conclusao),
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
            style: const TextStyle(
                fontSize: 11, color: AppColors.slate600, height: 1.4),
            children: [
              TextSpan(
                  text: '$bold ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.slate800)),
              TextSpan(text: text),
            ],
          ),
        ),
      );
}

class _MatchSummaryCard extends StatelessWidget {
  final MatchState s;
  final bool isDark;

  const _MatchSummaryCard({required this.s, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final playedAt = s.playedAt;
    final dateText = playedAt == null
        ? '--'
        : DateFormat('dd/MM/yyyy, HH:mm').format(playedAt);
    final place = (s.placeName ?? '').trim().isEmpty ? '--' : s.placeName!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900.withValues(alpha: .6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 3,
            color: AppColors.violet600,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.violet600.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Times',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.violet600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 5),
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? AppColors.slate300 : AppColors.slate600,
                        ),
                      ),
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
}

class _WaitingTeamsCard extends StatelessWidget {
  final MatchState s;
  final bool isDark;
  final VoidCallback onRefresh;

  const _WaitingTeamsCard({
    required this.s,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Times',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? AppColors.slate100 : AppColors.slate900,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 13),
                label: const Text('Recarregar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TeamColorsLine(
            teamA: s.teamAColor,
            teamB: s.teamBColor,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _DashedHint(
            text: 'Times ainda não foram definidos.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _TeamColorsLine extends StatelessWidget {
  final TeamColorInfo? teamA;
  final TeamColorInfo? teamB;
  final bool isDark;

  const _TeamColorsLine({
    required this.teamA,
    required this.teamB,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: _TeamColorName(color: teamA, fallback: 'Time A')),
          Text(
            'vs',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.slate500 : AppColors.slate400,
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _TeamColorName(
                color: teamB,
                fallback: 'Time B',
                reverse: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColorName extends StatelessWidget {
  final TeamColorInfo? color;
  final String fallback;
  final bool reverse;

  const _TeamColorName({
    required this.color,
    required this.fallback,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = color?.name ?? fallback;
    final dot = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color?.color ?? AppColors.slate300,
        shape: BoxShape.circle,
      ),
    );
    final text = Flexible(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color?.color ?? AppColors.slate600,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          reverse ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: reverse
          ? [text, const SizedBox(width: 6), dot]
          : [dot, const SizedBox(width: 6), text],
    );
  }
}

// ── Card de seção ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Color? borderColor;

  const _SectionCard(
      {required this.child, required this.isDark, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.slate900.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor ??
                (isDark
                    ? AppColors.slate700.withValues(alpha: 0.6)
                    : AppColors.slate200),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
        ),
        child: child,
      );
}

class _DashedHint extends StatelessWidget {
  final String text;
  final bool isDark;
  const _DashedHint({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.slate900.withValues(alpha: .35) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
            style: BorderStyle.solid,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: isDark ? AppColors.slate400 : AppColors.slate500,
          ),
        ),
      );
}
