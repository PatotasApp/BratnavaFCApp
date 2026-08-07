import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/prototype_ui.dart';
import '../../domain/entities/match_models.dart';

class MatchStepperHeader extends StatelessWidget {
  final MatchStep currentStep;
  final MatchStep? previewStep;
  final void Function(MatchStep)? onStepTap;

  const MatchStepperHeader({
    super.key,
    required this.currentStep,
    this.previewStep,
    this.onStepTap,
  });

  static const _steps = MatchStep.values;

  MatchStep get _viewedStep => previewStep ?? currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewed = _viewedStep;
    final isPreview = viewed != currentStep;
    final progress = (currentStep.index + 1) / _steps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: PrototypeCard(
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
                        isPreview
                            ? 'PRÉVIA · ETAPA ${viewed.stepNumber}'
                            : 'ETAPA ${currentStep.stepNumber} DE ${_steps.length}',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        viewed.label,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(viewed),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 54,
                    minHeight: 42,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${viewed.stepNumber}/${_steps.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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
            const SizedBox(height: 14),
            // Anterior/Próxima saíram do protótipo: navegar etapa a etapa por
            // botão confundia com o avanço real do fluxo. Sobra "Ver etapas",
            // que abre a lista completa e é onde se salta de propósito.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _showStages(context),
                child: const Text('Ver etapas'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStages(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Etapas da partida',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Acompanhe o fluxo completo.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: _steps.length,
                  separatorBuilder: (_, __) => Divider(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    final isCurrent = step == currentStep;
                    final isDone = step.index < currentStep.index;
                    final canOpen = onStepTap != null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      enabled: canOpen,
                      onTap: !canOpen
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              onStepTap!(step);
                            },
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: isDone
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              )
                            : Text(
                                '${step.stepNumber}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: isCurrent
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                      ),
                      title: Text(step.label),
                      subtitle: Text(_subtitle(step)),
                      trailing: isCurrent
                          ? const PrototypeBadge(
                              label: 'Atual',
                              tone: PrototypeBadgeTone.accent,
                            )
                          : const Icon(Icons.chevron_right_rounded, size: 18),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _subtitle(MatchStep step) {
    return switch (step) {
      MatchStep.create => 'Nova partida',
      MatchStep.accept => 'Aceitar ou recusar',
      MatchStep.teams => 'Times, cores e trocas',
      MatchStep.playing => 'Partida iniciada',
      MatchStep.ended => 'Fim do jogo',
      MatchStep.post => 'MVP, gols e placar',
      MatchStep.done => 'Partida finalizada',
    };
  }
}
