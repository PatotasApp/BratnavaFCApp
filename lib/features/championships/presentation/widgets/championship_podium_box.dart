import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../history/domain/entities/history_match.dart';

/// Pódio do campeonato no lugar do placar: a mesma caixa escura do placar,
/// com a cor e a posição de cada time (1º a 3º). O campeão tem o contorno
/// dourado. Sem pódio, mostra só o troféu.
class ChampionshipPodiumBox extends StatelessWidget {
  final List<HistoryPodiumTeam> podium;

  /// Versão menor, do tamanho do placar do card de últimas partidas.
  final bool compact;

  const ChampionshipPodiumBox({
    super.key,
    required this.podium,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = podium.take(3).toList();
    final first = compact ? 13.0 : 16.0;
    final other = compact ? 10.0 : 13.0;
    return Semantics(
      label: top.map((t) => '${t.position}º ${t.teamName}').join(', '),
      child: Container(
        constraints: BoxConstraints(minWidth: compact ? 0 : 60),
        height: compact ? null : 46,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.darkApp,
          borderRadius: BorderRadius.circular(compact ? 10 : 13),
          boxShadow: compact
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.shadow20,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: top.isEmpty
            ? Icon(Icons.emoji_events_outlined,
                color: AppColors.onDark, size: compact ? 16 : 20)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) SizedBox(width: compact ? 6 : 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: i == 0 ? first : other,
                          height: i == 0 ? first : other,
                          decoration: BoxDecoration(
                            color: _color(top[i].colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == 0
                                  ? AppColors.amber500
                                  : AppColors.onDark.withValues(alpha: .35),
                              width: i == 0 ? 2 : 1,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 3 : 4),
                        Text(
                          '${top[i].position}º',
                          style: TextStyle(
                            color: i == 0
                                ? AppColors.amber500
                                : AppColors.darkTextMuted,
                            fontSize: compact ? 9 : 10,
                            height: 1,
                            fontWeight: FontWeight.w900,
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

  static Color _color(String? hex) {
    final value = hex == null
        ? null
        : int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16);
    return value == null ? AppColors.darkTextMuted : Color(value);
  }
}

/// Pódio a partir dos campos do histórico; sem pódio, usa só o campeão.
List<HistoryPodiumTeam> podiumOrChampion({
  required List<HistoryPodiumTeam> podium,
  String? championTeamName,
  String? championTeamColorHex,
}) =>
    podium.isNotEmpty
        ? podium
        : [
            if (championTeamName != null)
              HistoryPodiumTeam(
                position: 1,
                teamName: championTeamName,
                colorHex: championTeamColorHex,
              ),
          ];
