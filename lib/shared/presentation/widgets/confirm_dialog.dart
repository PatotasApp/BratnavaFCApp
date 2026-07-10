import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String message,
  String? title,
  String confirmLabel = 'Confirmar',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final iconBg = danger
          ? (isDark
              ? AppColors.rose600.withValues(alpha: 0.18)
              : AppColors.rose50)
          : (isDark ? AppColors.slate800 : AppColors.slate100);
      final iconColor = danger ? AppColors.rose500 : AppColors.slate500;

      return AlertDialog(
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                danger
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title ?? 'Confirmar acao',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isDark ? AppColors.slate300 : AppColors.slate600,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AppColors.rose600 : AppColors.slate900,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
