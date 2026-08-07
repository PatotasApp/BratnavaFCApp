import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/poll_summary.dart';

class PollCard extends StatelessWidget {
  final PollSummary poll;
  final VoidCallback onTap;

  const PollCard({super.key, required this.poll, required this.onTap});

  String? _formatDeadline() {
    if (poll.deadlineDate == null) return null;
    final parts = poll.deadlineDate!.split('-');
    if (parts.length != 3) return poll.deadlineDate;
    final d = '${parts[2]}/${parts[1]}/${parts[0]}';
    return poll.deadlineTime != null ? '$d às ${poll.deadlineTime}' : d;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deadline = _formatDeadline();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Status dot ──
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    poll.isOpen ? AppColors.primaryHover : AppColors.slate300,
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          poll.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? AppColors.onDark : AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (poll.hasVoted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.blue50),
                          ),
                          child: Text(
                            'Votou',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.infoLight),
                          ),
                        ),
                      ],
                      // Badge "vinculado à partida"
                      if (poll.linkedMatchId != null &&
                          poll.linkedMatchId!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emerald500.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.emerald500.withValues(alpha: .3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.sports_soccer_rounded,
                                size: 9, color: AppColors.emerald700),
                            const SizedBox(width: 3),
                            Text('Partida',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.emerald700)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                  if (poll.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      poll.description!,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _Meta(
                          '${poll.optionCount} opç${poll.optionCount != 1 ? 'ões' : 'ão'}',
                          isDark),
                      _Dot(isDark),
                      _Meta(
                          '${poll.totalVoters} votante${poll.totalVoters != 1 ? 's' : ''}',
                          isDark),
                      if (poll.allowMultipleVotes) ...[
                        _Dot(isDark),
                        _Meta('Múltipla', isDark,
                            icon: Icons.check_box_outlined),
                      ],
                      if (poll.showVotes) ...[
                        _Dot(isDark),
                        _Meta('Público', isDark,
                            icon: Icons.visibility_outlined),
                      ],
                      if (deadline != null) ...[
                        _Dot(isDark),
                        _Meta(
                          poll.deadlinePassed ? 'Prazo encerrado' : deadline,
                          isDark,
                          icon: Icons.schedule,
                          color: poll.deadlinePassed
                              ? AppColors.prototypeDanger
                              : AppColors.warningLight,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right,
                size: 16,
                color: isDark ? AppColors.slate600 : AppColors.slate300),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final bool isDark;
  final IconData? icon;
  final Color? color;
  const _Meta(this.label, this.isDark, {this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? AppColors.slate500 : AppColors.slate400);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 2)
        ],
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool isDark;
  const _Dot(this.isDark);
  @override
  Widget build(BuildContext context) => Text('·',
      style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.slate500 : AppColors.slate400));
}
