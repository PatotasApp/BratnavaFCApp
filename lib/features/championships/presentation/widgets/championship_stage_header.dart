import 'package:flutter/material.dart';
import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../domain/entities/championship_enums.dart';
import '../../domain/entities/championship_models.dart';

/// Etapas do campeonato, na mesma régua da partida (Criada → Aceitação →
/// Formação → Jogo → Pós-jogo → Final). A formação da partida vira duas etapas:
/// Sorteio (TeamDraw sem times) e Times (TeamDraw com times).
enum ChampionshipStage {
  created('Criado', 'Regras e convite'),
  acceptation('Presença', 'Confirmar quem vai'),
  draw('Sorteio', 'Goleiros, método e cores'),
  teams('Times', 'Ver e ajustar os times'),
  games('Jogos', 'Confrontos e classificação'),
  postGame('Pós-jogo', 'MVP e conferência'),
  finalized('Final', 'Campeonato finalizado'),
  cancelled('Cancelado', 'Campeonato cancelado');

  const ChampionshipStage(this.label, this.subtitle);
  final String label;
  final String subtitle;

  static const flow = [
    created,
    acceptation,
    draw,
    teams,
    games,
    postGame,
    finalized,
  ];

  int get number => flow.indexOf(this) + 1;
}

ChampionshipStage championshipStageOf(ChampionshipDetails details) =>
    switch (details.status) {
      ChampionshipStatus.created => ChampionshipStage.created,
      ChampionshipStatus.acceptation => ChampionshipStage.acceptation,
      ChampionshipStatus.teamDraw => details.teams.isEmpty
          ? ChampionshipStage.draw
          : ChampionshipStage.teams,
      ChampionshipStatus.inProgress => ChampionshipStage.games,
      ChampionshipStatus.postGame => ChampionshipStage.postGame,
      ChampionshipStatus.finalized => ChampionshipStage.finalized,
      ChampionshipStatus.cancelled => ChampionshipStage.cancelled,
    };

/// Cabeçalho de etapa igual ao `MatchStepperHeader`: "ETAPA x DE 7", nome,
/// subtítulo, barra de progresso e "Ver etapas".
class ChampionshipStageHeader extends StatelessWidget {
  const ChampionshipStageHeader({super.key, required this.stage});

  final ChampionshipStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = ChampionshipStage.flow;
    final cancelled = stage == ChampionshipStage.cancelled;
    final progress = cancelled ? 0.0 : stage.number / steps.length;

    return PrototypeCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cancelled
                          ? 'CAMPEONATO'
                          : 'ETAPA ${stage.number} DE ${steps.length}',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.label,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(stage.subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              if (!cancelled) ...[
                const SizedBox(width: 10),
                Container(
                  constraints:
                      const BoxConstraints(minWidth: 54, minHeight: 42),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stage.number}/${steps.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: theme.colorScheme.outlineVariant,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _showStages(context),
              child: const Text('Ver etapas'),
            ),
          ),
        ],
      ),
    );
  }

  void _showStages(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        children: [
          Text('Etapas do campeonato', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          for (final step in ChampionshipStage.flow)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: step == stage
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                child: step.number < stage.number
                    ? Icon(Icons.check_rounded,
                        size: 16, color: theme.colorScheme.primary)
                    : Text(
                        '${step.number}',
                        style: TextStyle(
                          color: step == stage
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
              ),
              title: Text(step.label),
              subtitle: Text(step.subtitle),
              trailing: step == stage
                  ? const PrototypeBadge(
                      label: 'Atual',
                      tone: PrototypeBadgeTone.accent,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
