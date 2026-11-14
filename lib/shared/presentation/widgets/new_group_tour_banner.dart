import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Coach overlay usado no primeiro acesso a uma patota.
///
/// O véu visual não captura toques: os campos ao fundo continuam interativos,
/// enquanto o painel permanece fixo e inequívoco como um tour.
class NewGroupTourOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
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
                                    'TOUR GUIADO · ETAPA $step DE 3',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (status != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  status!,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: TextStyle(
                                height: 1.4,
                                color: isDark
                                    ? AppColors.slate300
                                    : AppColors.slate700,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Row(
                              children: List.generate(
                                3,
                                (index) => Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(
                                      right: index == 2 ? 0 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: index < step
                                          ? AppColors.accent
                                          : (isDark
                                              ? AppColors.slate700
                                              : AppColors.slate200),
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
                                  onPressed: onSkip,
                                  child: const Text('Pular tour'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: actionEnabled ? onAction : null,
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                    label: Text(actionLabel),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
