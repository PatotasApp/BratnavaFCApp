import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

enum AppPageHeaderVariant { main, detail }

/// Cabeçalho único das páginas do aplicativo.
///
/// [AppPageHeaderVariant.main] é reservado às abas principais (Partidas,
/// Minha patota e Histórico): ícone e título, sem botão voltar.
/// [AppPageHeaderVariant.detail] identifica fluxos internos: voltar, ícone,
/// título, explicação curta e ações opcionais.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final AppPageHeaderVariant variant;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget? iconWidget;
  final Widget? footer;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.variant = AppPageHeaderVariant.detail,
    this.actions = const [],
    this.onBack,
    this.iconWidget,
    this.footer,
  });

  const AppPageHeader.main({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.actions = const [],
    this.iconWidget,
    this.footer,
  })  : variant = AppPageHeaderVariant.main,
        onBack = null;

  bool get _showBack => variant == AppPageHeaderVariant.detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            variant == AppPageHeaderVariant.main ? 12 : 14,
            16,
            footer == null ? 14 : 10,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_showBack) ...[
                    _HeaderButton(
                      tooltip: 'Voltar',
                      onPressed: onBack ??
                          () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/app');
                            }
                          },
                      icon: Icons.arrow_back_rounded,
                    ),
                    const SizedBox(width: 10),
                  ],
                  iconWidget ??
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.appSurfaceSubtle,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: context.appBorder),
                        ),
                        child: Icon(icon, size: 21),
                      ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                        ),
                        if (subtitle?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.appTextSecondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...actions,
                  ],
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão visualmente consistente para ações do cabeçalho.
class AppPageHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  const AppPageHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => _HeaderButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        destructive: destructive,
      );
}

enum AppPageHeaderButtonTone { primary, secondary, destructive }

/// Barra padronizada para ações que precisam manter um rótulo visível.
/// Use no [AppPageHeader.footer] e prefira no máximo duas ações.
/// Uma ação ocupa toda a largura; duas ou mais dividem o espaço igualmente.
class AppPageHeaderActionBar extends StatelessWidget {
  final List<Widget> actions;

  const AppPageHeaderActionBar({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: actions[index]),
        ],
      ],
    );
  }
}

class AppPageHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppPageHeaderButtonTone tone;

  const AppPageHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = AppPageHeaderButtonTone.secondary,
  });

  @override
  Widget build(BuildContext context) {
    if (tone == AppPageHeaderButtonTone.primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: tone == AppPageHeaderButtonTone.destructive
          ? OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            )
          : null,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool destructive;

  const _HeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(42),
        maximumSize: const Size.square(42),
        foregroundColor: destructive ? scheme.error : scheme.onSurface,
        backgroundColor:
            destructive ? scheme.errorContainer : context.appSurfaceSubtle,
        side: BorderSide(
          color: destructive ? scheme.error : context.appBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
