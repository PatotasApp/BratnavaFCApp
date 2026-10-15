import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Aviso de que o login com Apple esbarrou numa conta existente e será
/// vinculado a ela no próximo login pelo método antigo.
class AppleLinkNotice extends StatelessWidget {
  const AppleLinkNotice({
    super.key,
    required this.email,
    required this.onCancel,
  });

  final String? email;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Já existe uma conta com ${email ?? 'este e-mail'}. Entre com o '
            'método que você já usa (Google ou e-mail e senha) para vincular '
            'a Apple a ela.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.lightText),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Cancelar vínculo'),
          ),
        ],
      ),
    );
  }
}
