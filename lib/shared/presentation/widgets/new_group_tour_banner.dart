import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Coach overlay usado no primeiro acesso a uma patota.
///
/// O painel se recolhe ao tocar no conteúdo ao fundo. Assim, a apresentação da
/// etapa fica evidente sem bloquear a edição e a rolagem da tela guiada.
class NewGroupTourOverlay extends StatefulWidget {
  final int step;
  final String title;
  final String description;
  final String? status;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final VoidCallback onSkip;

  const NewGroupTourOverlay({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    required this.onSkip,
    this.status,
    this.actionEnabled = true,
  }) : assert(step >= 1 && step <= 3);

  @override
  State<NewGroupTourOverlay> createState() => _NewGroupTourOverlayState();
}

class _NewGroupTourOverlayState extends State<NewGroupTourOverlay> {
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant NewGroupTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedStage = oldWidget.step != widget.step ||
        oldWidget.title != widget.title ||
        oldWidget.status != widget.status ||
        oldWidget.actionLabel != widget.actionLabel;
    if (changedStage) _expanded = true;
  }

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  void _expand() {
    if (!_expanded) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (!_expanded) return _buildCompactButton(bottomInset);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ColoredBox(
            color: AppColors.darkApp.withValues(alpha: isDark ? .72 : .58),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TapRegion(
                onTapOutside: (_) => _collapse(),
                child: Material(
                  elevation: 24,
                  shadowColor: AppColors.darkApp,
                  color: isDark ? AppColors.slate900 : AppColors.onDark,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 560),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: .55),
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        _buildBody(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton(double bottomInset) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Material(
            elevation: 10,
            shadowColor: AppColors.darkApp,
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(99),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _expand,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.onDark,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Tour ${widget.step}/3',
                      style: const TextStyle(
                        color: AppColors.onDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.expand_less_rounded,
                      color: AppColors.onDark,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: .24),
            AppColors.accent.withValues(alpha: .06),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.accent.withValues(alpha: .2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.onDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOUR GUIADO · ETAPA ${widget.step} DE 3',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (widget.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                widget.status!,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            onPressed: _collapse,
            tooltip: 'Recolher e editar a tela',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: TextStyle(
              height: 1.4,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: AppColors.accent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Toque fora do painel para editar e navegar pela tela.',
                  style: TextStyle(
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < widget.step
                        ? AppColors.accent
                        : (isDark ? AppColors.slate700 : AppColors.slate200),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              TextButton(
                onPressed: widget.onSkip,
                child: const Text('Pular tour'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.actionEnabled ? widget.onAction : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
