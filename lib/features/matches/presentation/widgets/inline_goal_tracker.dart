import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/presentation/widgets/group_icon_renderer.dart';
import '../../domain/entities/match_models.dart';

class InlineGoalTracker extends StatelessWidget {
  final int minute;
  final String? scorerMpId;
  final String? assistMpId;
  final bool isOwnGoal;
  final bool isEditing;
  final List<MatchPlayerInfo> participants;
  final List<MatchPlayerInfo> teamAPlayers;
  final List<MatchPlayerInfo> teamBPlayers;
  final String teamAName;
  final String teamBName;
  final Color? teamAColor;
  final Color? teamBColor;
  final bool mutating;
  final GroupIcons icons;
  final bool isAdmin;
  final ValueChanged<int> onMinuteChanged;
  final ValueChanged<String?> onScorerChanged;
  final ValueChanged<String?> onAssistChanged;
  final ValueChanged<bool> onOwnGoalChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const InlineGoalTracker({
    super.key,
    required this.minute,
    required this.scorerMpId,
    required this.assistMpId,
    required this.isOwnGoal,
    this.isEditing = false,
    this.participants = const [],
    required this.teamAPlayers,
    required this.teamBPlayers,
    required this.teamAName,
    required this.teamBName,
    this.teamAColor,
    this.teamBColor,
    required this.mutating,
    this.icons = GroupIcons.defaults,
    this.isAdmin = false,
    required this.onMinuteChanged,
    required this.onScorerChanged,
    required this.onAssistChanged,
    required this.onOwnGoalChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final teamA = participants.isNotEmpty
        ? participants.where((p) => p.team == 1).toList()
        : teamAPlayers;
    final teamB = participants.isNotEmpty
        ? participants.where((p) => p.team == 2).toList()
        : teamBPlayers;
    final allPlayers = [...teamA, ...teamB];
    final scorer =
        allPlayers.where((p) => p.matchPlayerId == scorerMpId).firstOrNull;
    final scorerIsTeamA = scorer != null &&
        teamA.any((p) => p.matchPlayerId == scorer.matchPlayerId);
    final assistPlayers = scorer == null
        ? <MatchPlayerInfo>[]
        : (isOwnGoal
                ? (scorerIsTeamA ? teamB : teamA)
                : (scorerIsTeamA ? teamA : teamB))
            .where((p) => p.matchPlayerId != scorer.matchPlayerId)
            .toList();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Editar gol' : 'Gols da partida',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Tempo:',
                    style: TextStyle(fontSize: 13, color: AppColors.slate600)),
                const SizedBox(width: 12),
                Container(
                  width: 82,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate200),
                    color: AppColors.slate50,
                  ),
                  child: Text(
                    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  children: [
                    _MinuteButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressed: () =>
                          onMinuteChanged((minute + 1) % (24 * 60)),
                    ),
                    const SizedBox(height: 2),
                    _MinuteButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onPressed: () =>
                          onMinuteChanged((minute - 1 + 24 * 60) % (24 * 60)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PlayerColumn(
                    label: teamAName,
                    color: teamAColor,
                    players: teamA,
                    selectedId: scorerMpId,
                    icons: icons,
                    onTap: onScorerChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PlayerColumn(
                    label: teamBName,
                    color: teamBColor,
                    players: teamB,
                    selectedId: scorerMpId,
                    icons: icons,
                    onTap: onScorerChanged,
                  ),
                ),
              ],
            ),
            if (scorer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.emerald200),
                  color: AppColors.emerald50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Marcou o gol:',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.slate500)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        renderGroupIcon(icons.goal, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _displayName(scorer),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        renderGroupIcon(
                          scorer.isGoalkeeper ? icons.goalkeeper : icons.player,
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: isOwnGoal,
                          onChanged: (v) {
                            onOwnGoalChanged(v ?? false);
                            onAssistChanged(null);
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('Gol contra',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (assistPlayers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        isOwnGoal
                            ? 'Quem forçou o gol contra (opcional):'
                            : 'Assistência (opcional):',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 6),
                      _AssistGrid(
                        players: assistPlayers,
                        assistMpId: assistMpId,
                        icons: icons,
                        onTap: onAssistChanged,
                      ),
                    ],
                    const SizedBox(height: 12),
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
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.slate900),
                            child: mutating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(isEditing
                                    ? 'Atualizar gol'
                                    : isOwnGoal
                                        ? 'Adicionar gol contra'
                                        : 'Adicionar gol'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _displayName(MatchPlayerInfo player) {
  final name = player.playerName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.isNotEmpty) return name;

  final playerId = player.playerId.trim();
  if (playerId.isNotEmpty) {
    return 'Jogador ${playerId.substring(0, playerId.length < 4 ? playerId.length : 4)}';
  }

  final matchPlayerId = player.matchPlayerId.trim();
  if (matchPlayerId.isNotEmpty) {
    return 'Jogador ${matchPlayerId.substring(0, matchPlayerId.length < 4 ? matchPlayerId.length : 4)}';
  }

  return 'Jogador';
}

class _MinuteButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MinuteButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 24,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.slate200),
          color: AppColors.slate50,
        ),
        child: Icon(icon, size: 14, color: AppColors.slate500),
      ),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  final String label;
  final Color? color;
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
        Text(
          label.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: teamColor,
          ),
        ),
        const SizedBox(height: 6),
        if (players.isEmpty)
          const Text('-',
              style: TextStyle(fontSize: 12, color: AppColors.slate400))
        else
          ...players.map((p) {
            final isSelected = p.matchPlayerId == selectedId;
            final playerName = _displayName(p);
            final borderColor =
                isSelected ? AppColors.emerald500 : AppColors.slate200;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: double.infinity,
                height: 34,
                child: TextButton(
                  onPressed: () => onTap(isSelected ? null : p.matchPlayerId),
                  style: ButtonStyle(
                    alignment: Alignment.centerLeft,
                    minimumSize:
                        WidgetStateProperty.all(const Size.fromHeight(34)),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    backgroundColor: WidgetStateProperty.all(
                      isSelected ? AppColors.emerald50 : AppColors.slate50,
                    ),
                    foregroundColor: WidgetStateProperty.all(
                      isSelected ? AppColors.emerald700 : Colors.black,
                    ),
                    overlayColor: WidgetStateProperty.all(
                      AppColors.emerald50.withValues(alpha: 0.55),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: teamColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.emerald700
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AssistGrid extends StatelessWidget {
  final List<MatchPlayerInfo> players;
  final String? assistMpId;
  final GroupIcons icons;
  final ValueChanged<String?> onTap;

  const _AssistGrid({
    required this.players,
    required this.assistMpId,
    required this.icons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: players.map((p) {
        final isSelected = p.matchPlayerId == assistMpId;
        return GestureDetector(
          onTap: () => onTap(isSelected ? null : p.matchPlayerId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      isSelected ? AppColors.emerald500 : AppColors.slate200),
              color: isSelected ? AppColors.emerald50 : Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                renderGroupIcon(
                    p.isGoalkeeper ? icons.goalkeeper : icons.player,
                    size: 13),
                const SizedBox(width: 4),
                Text(
                  _displayName(p),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? AppColors.emerald700 : AppColors.slate700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
