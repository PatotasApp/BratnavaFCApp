import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/match_details.dart';

/// Painel de gols da partida (abas por time, linha de cada gol com horário e,
/// para o admin, editar/excluir/registrar) e o formulário de gol. Compartilhado
/// com os jogos do campeonato, que mostram os gols do mesmo jeito.

// ── Goals section ─────────────────────────────────────────────────────────────

class GoalWithTeam {
  final MatchGoal goal;
  final String team; // 'A' | 'B' | '?'
  const GoalWithTeam({required this.goal, required this.team});
}

class MatchGoalsSection extends StatelessWidget {
  final List<GoalWithTeam> goals;
  final int tab;
  final void Function(int) onTab;
  final Color aColor, bColor;
  final String aName, bName;
  final bool isDark;
  final GroupIcons icons;
  final Map<String, bool> goalkeeperByName;
  final bool isAdmin;
  final VoidCallback? onAddGoal;
  final void Function(MatchGoal)? onEditGoal;
  final void Function(MatchGoal)? onDeleteGoal;

  const MatchGoalsSection({
    required this.goals,
    required this.tab,
    required this.onTab,
    required this.aColor,
    required this.bColor,
    required this.aName,
    required this.bName,
    required this.isDark,
    required this.icons,
    required this.goalkeeperByName,
    this.isAdmin = false,
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onDeleteGoal,
  });

  List<GoalWithTeam> get _filtered {
    if (tab == 1) return goals.where((g) => g.team == 'A').toList();
    if (tab == 2) return goals.where((g) => g.team == 'B').toList();
    return goals;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
            // Filtros por time
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TabBtn(
                              label: 'Todos',
                              active: tab == 0,
                              isDark: isDark,
                              onTap: () => onTab(0)),
                          const SizedBox(width: 6),
                          _TabBtn(
                              dotColor: aColor,
                              label: aName,
                              active: tab == 1,
                              isDark: isDark,
                              onTap: () => onTab(1)),
                          const SizedBox(width: 6),
                          _TabBtn(
                              dotColor: bColor,
                              label: bName,
                              active: tab == 2,
                              isDark: isDark,
                              onTap: () => onTab(2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Nenhum gol registrado.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.slate500 : AppColors.slate400,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((g) => _GoalRow(
                    goalWithTeam: g,
                    aColor: aColor,
                    bColor: bColor,
                    isDark: isDark,
                    icons: icons,
                    goalkeeperByName: goalkeeperByName,
                    isAdmin: isAdmin,
                    onEdit:
                        onEditGoal == null ? null : () => onEditGoal!(g.goal),
                    onDelete: onDeleteGoal == null
                        ? null
                        : () => onDeleteGoal!(g.goal),
                  )),
            if (isAdmin && onAddGoal != null) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: onAddGoal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Registrar gol'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.darkApp,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalWithTeam goalWithTeam;
  final Color aColor, bColor;
  final bool isDark;
  final GroupIcons icons;
  final Map<String, bool> goalkeeperByName;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GoalRow({
    required this.goalWithTeam,
    required this.aColor,
    required this.bColor,
    required this.isDark,
    required this.icons,
    required this.goalkeeperByName,
    this.isAdmin = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final g = goalWithTeam.goal;
    final team = goalWithTeam.team;
    final color = team == 'A'
        ? aColor
        : team == 'B'
            ? bColor
            : AppColors.slate400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
          ),
        ),
      ),
      child: Row(
        children: [
          // Marcador vertical do time que marcou
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          // Scorer + assist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    renderGroupIcon(icons.goal, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: PlayerNameWithIcon(
                        name: g.scorerName ?? '—',
                        icons: icons,
                        isGoalkeeper: goalkeeperByName[g.scorerName] ?? false,
                        iconSize: 10,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.onDark : AppColors.slate900,
                        ),
                      ),
                    ),
                    if (g.isOwnGoal)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.orange50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GC',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningLight,
                          ),
                        ),
                      ),
                  ],
                ),
                if (g.assistName != null && g.assistName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        renderGroupIcon(
                          icons.assist,
                          size: 11,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: PlayerNameWithIcon(
                            name: g.assistName!,
                            icons: icons,
                            isGoalkeeper:
                                goalkeeperByName[g.assistName] ?? false,
                            iconSize: 9,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Time
          if (g.time != null)
            Text(
              g.time!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          // Admin edit / delete
          if (isAdmin) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 15,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.rose500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final Color? dotColor;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.isDark,
    this.dotColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? AppColors.onDark : AppColors.slate900)
              : (isDark ? AppColors.slate900 : AppColors.onDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? (isDark ? AppColors.onDark : AppColors.slate900)
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? (isDark ? AppColors.slate900 : AppColors.onDark)
                    : (isDark ? AppColors.slate300 : AppColors.slate700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Goal form sheet ───────────────────────────────────────────────────────────

class GoalFormSheet extends StatefulWidget {
  final List<MatchPlayer> players;
  final GroupIcons icons;
  final MatchGoal? editing;
  final Future<void> Function(String scorerPlayerId, String? assistPlayerId,
      String time, bool isOwnGoal) onSave;

  const GoalFormSheet({
    required this.players,
    required this.icons,
    this.editing,
    required this.onSave,
  });

  @override
  State<GoalFormSheet> createState() => GoalFormSheetState();
}

class GoalFormSheetState extends State<GoalFormSheet> {
  String? _scorerPlayerId;
  String? _assistPlayerId;
  late final TextEditingController _timeCtrl;
  bool _isOwnGoal = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _scorerPlayerId = e?.scorerPlayerId;
    _assistPlayerId = e?.assistPlayerId;
    _timeCtrl = TextEditingController(text: e?.time ?? _defaultTime());
    _isOwnGoal = e?.isOwnGoal ?? false;
  }

  List<MatchPlayer> get _assistCandidates {
    if (_scorerPlayerId == null) return [];
    final scorer =
        widget.players.where((p) => p.playerId == _scorerPlayerId).firstOrNull;
    if (scorer == null) return [];
    return widget.players.where((p) {
      if (p.playerId == _scorerPlayerId) return false;
      return _isOwnGoal ? p.team != scorer.team : p.team == scorer.team;
    }).toList();
  }

  void _setScorer(String? id) {
    setState(() {
      _scorerPlayerId = id;
      _assistPlayerId = null;
    });
  }

  void _setOwnGoal(bool value) {
    setState(() {
      _isOwnGoal = value;
      _assistPlayerId = null;
    });
  }

  String _defaultTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_scorerPlayerId == null) {
      setState(() => _error = 'Selecione o marcador do gol.');
      return;
    }
    final time = _timeCtrl.text.trim();
    if (time.isEmpty) {
      setState(() => _error = 'Informe o horário do gol.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _scorerPlayerId!,
        (_assistPlayerId?.isNotEmpty == true) ? _assistPlayerId : null,
        time,
        _isOwnGoal,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = extractDioError(e, 'Erro ao salvar gol');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.onDark : AppColors.slate900;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : AppColors.onDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(children: [
              Text(
                widget.editing != null ? 'Editar gol' : 'Adicionar gol',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: labelColor),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ]),
            const SizedBox(height: 16),

            // Scorer
            _PlayerDropdown(
              label: 'Marcador *',
              players: widget.players,
              icons: widget.icons,
              selectedId: _scorerPlayerId,
              onChanged: _setScorer,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Time
            TextField(
              controller: _timeCtrl,
              decoration: InputDecoration(
                labelText: 'Horário (HH:mm)',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                labelStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              keyboardType: TextInputType.datetime,
              style: TextStyle(fontSize: 14, color: labelColor),
            ),
            const SizedBox(height: 4),

            // Own goal checkbox
            CheckboxListTile(
              value: _isOwnGoal,
              onChanged: (v) => _setOwnGoal(v ?? false),
              title: const Text('Gol contra', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Assist — só aparece quando um marcador está selecionado e há candidatos
            if (_scorerPlayerId != null && _assistCandidates.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PlayerDropdown(
                label: _isOwnGoal
                    ? 'Quem forçou o gol contra (opcional)'
                    : 'Assistência (opcional)',
                players: _assistCandidates,
                icons: widget.icons,
                selectedId: _assistPlayerId,
                onChanged: (id) => setState(() => _assistPlayerId = id),
                isDark: isDark,
                nullable: true,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.rose500, fontSize: 12)),
            ],
            const SizedBox(height: 12),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onDark))
                  : Text(widget.editing != null
                      ? 'Salvar alterações'
                      : 'Adicionar gol'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDropdown extends StatelessWidget {
  final String label;
  final List<MatchPlayer> players;
  final GroupIcons icons;
  final String? selectedId;
  final void Function(String?) onChanged;
  final bool isDark;
  final bool nullable;

  const _PlayerDropdown({
    required this.label,
    required this.players,
    required this.icons,
    required this.selectedId,
    required this.onChanged,
    required this.isDark,
    this.nullable = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        labelStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.slate400 : AppColors.slate500),
      ),
      items: [
        if (nullable)
          DropdownMenuItem<String?>(
            value: null,
            child: Text('— Nenhum —',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.slate400 : AppColors.slate500)),
          ),
        ...players.map((p) => DropdownMenuItem<String?>(
              value: p.playerId,
              child: PlayerNameWithIcon(
                name: p.playerName,
                isGoalkeeper: p.isGoalkeeper,
                icons: icons,
                iconSize: 14,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.onDark : AppColors.slate900,
                ),
              ),
            )),
      ],
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 14, color: isDark ? AppColors.onDark : AppColors.slate900),
      dropdownColor: isDark ? AppColors.slate800 : AppColors.onDark,
    );
  }
}
