import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ParticipationStatusBadge extends StatelessWidget {
  final bool hasVoted;

  const ParticipationStatusBadge({
    super.key,
    required this.hasVoted,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = hasVoted ? context.appSuccess : context.appWarning;
    final background =
        hasVoted ? context.appSuccessContainer : context.appWarningContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasVoted ? Icons.check_rounded : Icons.schedule_rounded,
            size: 11,
            color: foreground,
          ),
          const SizedBox(width: 3),
          Text(
            hasVoted ? 'Já votou' : 'Pendente',
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
