import 'package:flutter/material.dart';

/// Estado vazio padrão para áreas que dependem de uma patota ativa.
///
/// A tela "Minha patota" não utiliza este componente: ela é justamente o
/// ponto em que o usuário cria, aceita ou seleciona uma patota.
class NoActiveGroupView extends StatelessWidget {
  final String message;

  const NoActiveGroupView({
    super.key,
    this.message = 'Selecione uma patota para continuar.',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          ],
        ),
      ),
    );
  }
}
