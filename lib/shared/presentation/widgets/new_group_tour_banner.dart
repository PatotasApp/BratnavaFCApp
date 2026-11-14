import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class NewGroupTourBanner extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final String? status;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final VoidCallback? onSkip;

  const NewGroupTourBanner({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    this.status,
    this.actionLabel,
    this.onAction,
    this.actionEnabled = true,
    this.onSkip,
  }) : assert(step >= 1 && step <= 3);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.emerald50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: isDark ? .55 : .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Primeiros passos · $step de 3',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.emerald500
                            : AppColors.emerald700,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != null)
                Text(
                  status!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              height: 1.35,
              color: isDark ? AppColors.slate300 : AppColors.slate700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < step
                        ? AppColors.accent
                        : (isDark ? AppColors.slate700 : AppColors.slate200),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          if (actionLabel != null || onSkip != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    child: const Text('Pular tour'),
                  ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: actionEnabled ? onAction : null,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
