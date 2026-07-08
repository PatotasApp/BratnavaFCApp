import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/match_models.dart';

class InlineGoalTracker extends StatelessWidget {
  final int     minute;
  final String? scorerMpId;
  final String? assistMpId;
  final bool    isOwnGoal;
  final bool    isEditing;
  final List<MatchPlayerInfo> teamAPlayers;
  final List<MatchPlayerInfo> teamBPlayers;
  final String  teamAName;
  final String  teamBName;
  final Color?  teamAColor;
  final Color?  teamBColor;
  final bool    mutating;
  final GroupIcons icons;
  final ValueChanged<int>     onMinuteChanged;
  final ValueChanged<String?> onScorerChanged;
  final ValueChanged<String?> onAssistChanged;
  final ValueChanged<bool>    onOwnGoalChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const InlineGoalTracker({
    super.key,
    required this.minute,
    required this.scorerMpId,
    required this.assistMpId,
    required this.isOwnGoal,
    this.isEditing = false,
    required this.teamAPlayers,
    required this.teamBPlayers,
    required this.teamAName,
    required this.teamBName,
    this.teamAColor,
    this.teamBColor,
    required this.mutating,
    this.icons = GroupIcons.defaults,
    required this.onMinuteChanged,
    required this.onScorerChanged,
    required this.onAssistChanged,
    required this.onOwnGoalChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.sports_soccer, size: 18, color: AppColors.slate500),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Editar Gol' : 'Registrar Gol',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Horário ────────────────────────────────────────────────────
            Row(
              children: [
                const Text('Horário:', style: TextStyle(fontSize: 13, color: AppColors.slate600)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => onMinuteChanged((minute - 1 + 24 * 60) % (24 * 60)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => onMinuteChanged((minute + 1) % (24 * 60)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Seleção de goleador (2 colunas) ───────────────────────────
            const Text(
              'GOLEADOR',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8, color: AppColors.slate400),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _PlayerColumn(
                  label:     teamAName,
                  color:     teamAColor,
                  players:   teamAPlayers,
                  selectedId: scorerMpId,
                  icons:     icons,
                  onTap:     onScorerChanged,
                )),
                const SizedBox(width: 8),
                if (teamBPlayers.isNotEmpty)
                  Expanded(child: _PlayerColumn(
                    label:     teamBName,
                    color:     teamBColor,
                    players:   teamBPlayers,
                    selectedId: scorerMpId,
                    icons:     icons,
                    onTap:     onScorerChanged,
                  )),
              ],
            ),

            if (scorerMpId != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // ── Gol contra ─────────────────────────────────────────────
              Row(
                children: [
                  Checkbox(
                    value: isOwnGoal,
                    onChanged: (v) => onOwnGoalChanged(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('Gol contra', style: TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),

              // ── Assistência ────────────────────────────────────────────
              const Text(
                'ASSISTÊNCIA (opcional)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: AppColors.slate400),
              ),
              const SizedBox(height: 8),
              _AssistGrid(
                allPlayers: teamAPlayers.any((p) => p.matchPlayerId == scorerMpId)
                    ? teamAPlayers
                    : teamBPlayers,
                scorerMpId: scorerMpId!,
                assistMpId: assistMpId,
                onTap:     onAssistChanged,
              ),
              const SizedBox(height: 12),

              // ── Botões ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: mutating ? null : onSave,
                      child: mutating
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Atualizar Gol' : 'Salvar Gol'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Coluna de jogadores ───────────────────────────────────────────────────────

class _PlayerColumn extends StatelessWidget {
  final String  label;
  final Color?  color;
  final List<MatchPlayerInfo> players;
  final String? selectedId;
  final GroupIcons icons;
  final ValueChanged<String?> onTap;

  const _PlayerColumn({
    required this.label,
    this.color,
    required this.players,
    required this.selectedId,
    this.icons = GroupIcons.defaults,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor = color ?? AppColors.slate400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: teamColor)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: teamColor)),
        ]),
        const SizedBox(height: 4),
        ...players.map((p) {
          final isSel = p.matchPlayerId == selectedId;
          return GestureDetector(
            onTap: () => onTap(isSel ? null : p.matchPlayerId),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSel ? teamColor : AppColors.slate200),
                color: isSel ? teamColor.withValues(alpha: 0.1) : AppColors.slate50,
              ),
              child: Row(children: [
                if (p.isGoalkeeper)
                  renderGroupIcon(icons.goalkeeper, size: 12, color: AppColors.slate400),
                if (p.isGoalkeeper) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p.playerName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel ? teamColor : AppColors.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSel) Icon(Icons.check_circle, size: 14, color: teamColor),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

// ── Grid de assistência ───────────────────────────────────────────────────────

class _AssistGrid extends StatelessWidget {
  final List<MatchPlayerInfo> allPlayers;
  final String  scorerMpId;
  final String? assistMpId;
  final ValueChanged<String?> onTap;

  const _AssistGrid({
    required this.allPlayers,
    required this.scorerMpId,
    required this.assistMpId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = allPlayers.where((p) => p.matchPlayerId != scorerMpId).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        GestureDetector(
          onTap: () => onTap(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: assistMpId == null ? AppColors.slate500 : AppColors.slate200),
              color: assistMpId == null ? AppColors.slate100 : Colors.transparent,
            ),
            child: const Text('—', style: TextStyle(fontSize: 12)),
          ),
        ),
        ...candidates.map((p) {
          final isSel = p.matchPlayerId == assistMpId;
          return GestureDetector(
            onTap: () => onTap(isSel ? null : p.matchPlayerId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSel ? AppColors.blue500 : AppColors.slate200),
                color: isSel ? AppColors.blue200.withValues(alpha: 0.3) : Colors.transparent,
              ),
              child: Text(
                p.playerName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  color: isSel ? AppColors.blue600 : AppColors.slate700,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
