import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Espaçamentos e dimensões aprovados no protótipo Pixel 5.
/// Métricas espelhadas de `src/extensions.css` do protótipo. Quando divergirem,
/// o protótipo é a fonte da verdade.
abstract final class PrototypeLayout {
  static const horizontalPadding = 16.0; // .proto-scroll
  static const contentTopPadding = 16.0; // .proto-scroll
  static const contentBottomPadding = 110.0; // .proto-scroll
  static const cardRadius = 16.0; // .proto-card
  static const cardPadding = 14.0; // .proto-card
  static const controlRadius = 12.0; // .proto-icon-btn
  static const minimumTouchTarget = 44.0; // .proto-icon-btn / .proto-chip
  static const bottomNavigationHeight = 84.0; // .proto-bottom-nav
  static const topBarHeight = 72.0; // .proto-topbar

  /// .proto-list-row — o raio é 13, não 12: fica visivelmente mais macio que os
  /// controles e um pouco mais fechado que o card.
  static const listRowRadius = 13.0;
  static const listRowMinHeight = 56.0;
  static const listRowPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  static const sheetRadius = 22.0; // .proto-sheet
  static const chipHeight = 44.0; // button.proto-chip
  static const kpiRadius = 12.0; // .proto-kpi

  /// .proto-stack{gap:12px} e .proto-row{gap:10px} — os dois espaçamentos que
  /// aparecem em praticamente toda tela do protótipo.
  static const stackGap = 12.0;
  static const rowGap = 10.0;

  /// .proto-avatar — quadrado arredondado, não círculo.
  static const avatarSize = 34.0;
  static const avatarRadius = 12.0;
}

/// `.proto-segment`: trilho claro com um botão por opção, todos da mesma
/// largura, e o ativo virando um "pill" elevado.
///
/// Métricas do CSS: trilho com raio 12, padding 4 e gap 4; botões com raio 9 e
/// altura mínima de 44 (o alvo de toque mínimo do protótipo).
class PrototypeSegmented extends StatelessWidget {
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  /// Rótulo do grupo para leitores de tela.
  final String semanticLabel;

  const PrototypeSegmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.semanticLabel = 'Opções',
  });

  @override
  Widget build(BuildContext context) {
    // Valores conferidos com tools/resolve-style.mjs do protótipo. No tema
    // claro: trilho --bg-subtle #f4f5f7, borda --border-card #e4e6ea, ativo
    // --bg-card #ffffff sobre --text-primary #1a1d24, inativo --text-muted
    // #626873. A escala `slate` do app é próxima mas não é a mesma paleta.
    final trackColor = context.appSurfaceSubtle;
    final borderColor = context.appBorder;
    final activeBg = context.appSurface;
    final activeFg = context.appTextPrimary;
    final idleFg = context.appTextSecondary;

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(PrototypeLayout.controlRadius),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _SegmentButton(
                  label: items[i],
                  selected: items[i] == value,
                  activeBg: activeBg,
                  activeFg: activeFg,
                  idleFg: idleFg,
                  onTap: () => onChanged(items[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeBg;
  final Color activeFg;
  final Color idleFg;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.activeBg,
    required this.activeFg,
    required this.idleFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(
              minHeight: PrototypeLayout.minimumTouchTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: selected
              ? BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: .08),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                )
              : null,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? activeFg : idleFg,
            ),
          ),
        ),
      ),
    );
  }
}

class PrototypeScrollView extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  const PrototypeScrollView({
    super.key,
    required this.child,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(
      PrototypeLayout.horizontalPadding,
      PrototypeLayout.contentTopPadding,
      PrototypeLayout.horizontalPadding,
      PrototypeLayout.contentBottomPadding,
    ),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: child,
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

class PrototypeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const PrototypeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = PrototypeLayout.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.surface;
    final resolvedBorder = borderColor ?? theme.colorScheme.outlineVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: resolvedBorder),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: resolvedColor, shape: shape),
        child: Padding(padding: padding, child: child),
      );
    }

    return Material(
      color: resolvedColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PrototypeSectionTitle extends StatelessWidget {
  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PrototypeSectionTitle({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          PrototypeBadge(label: count!),
        ],
        if (actionLabel != null) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

enum PrototypeBadgeTone { neutral, accent, success, danger }

class PrototypeBadge extends StatelessWidget {
  final String label;
  final PrototypeBadgeTone tone;
  final Widget? icon;

  const PrototypeBadge({
    super.key,
    required this.label,
    this.tone = PrototypeBadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, border, foreground) = switch (tone) {
      PrototypeBadgeTone.accent => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.primary,
          theme.colorScheme.onPrimaryContainer,
        ),
      PrototypeBadgeTone.success => (
          context.appSuccessContainer,
          context.appSuccess,
          context.appSuccess,
        ),
      PrototypeBadgeTone.danger => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.error,
          theme.colorScheme.error,
        ),
      PrototypeBadgeTone.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.outline,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(size: 13, color: foreground),
              child: icon!,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PrototypeIconBox extends StatelessWidget {
  final Widget icon;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double size;

  const PrototypeIconBox({
    super.key,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final background = backgroundColor ?? theme.colorScheme.primaryContainer;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: IconTheme(
        data: IconThemeData(size: 18, color: foreground),
        child: icon,
      ),
    );
  }
}

class PrototypeMenuTile extends StatelessWidget {
  final Widget icon;
  final String title;

  /// Opcional: sem ele o tile fica com uma linha só.
  final String? subtitle;

  final VoidCallback onTap;
  final int badgeCount;

  const PrototypeMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // 76 era a altura de duas linhas de texto. Sem subtítulo o tile fica
          // com um bloco de vazio embaixo do título, então a altura mínima
          // acompanha o conteúdo: 56 é o mesmo mínimo das linhas de lista do
          // protótipo e continua acima do alvo de toque de 44.
          constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 76),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    PrototypeIconBox(icon: icon),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Sem este respiro títulos longos ("Monte seu Time")
                    // encostam na seta.
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  // Encostado no topo e à direita, o badge cobria a seta no
                  // tile de uma linha só. Deslocado para fora dela.
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrototypeHeaderBand extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PrototypeHeaderBand({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: context.appSurface,
        border: Border.all(color: context.appBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _PrototypeDotPainter(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .16),
        ),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: context.appTextPrimary),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PrototypeDotPainter extends CustomPainter {
  final Color color;

  const _PrototypeDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 1; x < size.width; x += 16) {
      for (double y = 1; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PrototypeDotPainter oldDelegate) =>
      oldDelegate.color != color;
}
