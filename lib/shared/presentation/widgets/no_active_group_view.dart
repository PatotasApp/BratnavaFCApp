import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/discovery/presentation/providers/match_invites_provider.dart';

/// Estado vazio padrão para áreas que dependem de uma patota ativa.
///
/// A tela "Minha patota" não utiliza este componente: ela é justamente o
/// ponto em que o usuário cria, aceita ou seleciona uma patota.
class NoActiveGroupView extends ConsumerWidget {
  final String message;

  /// Atalho para "Convites para jogar": quem foi chamado só para uma partida
  /// não tem patota ativa, e é por lá que acompanha o jogo.
  final bool showMatchInvitesShortcut;

  const NoActiveGroupView({
    super.key,
    this.message = 'Selecione uma patota para continuar.',
    this.showMatchInvitesShortcut = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // O atalho só aparece se houver convite ou partida em andamento.
    final hasInProgress = showMatchInvitesShortcut &&
        (ref.watch(hasMatchInvitesInProgressProvider).valueOrNull ?? false);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 25,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhuma patota ativa',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            if (hasInProgress) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/app/match-invitations'),
                icon: const Icon(Icons.sports_soccer_outlined),
                label: const Text('Convites para jogar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
