import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/poll_summary.dart';
import 'participation_status_badge.dart';

class EventCard extends StatelessWidget {
  final PollSummary poll;
  final VoidCallback onTap;

  const EventCard({super.key, required this.poll, required this.onTap});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String? _formatDeadline() {
    if (poll.deadlineDate == null) return null;
    final d = _formatDate(poll.deadlineDate);
    return poll.deadlineTime != null ? '$d às ${poll.deadlineTime}' : d;
  }

  String? _formatCost() {
    if (poll.costType == null || poll.costType!.isEmpty) return null;
    final label = poll.costType == 'individual' ? 'por pessoa' : 'rateio grupo';
    if (poll.costAmount != null) {
      return 'R\$ ${poll.costAmount!.toStringAsFixed(2)} $label';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = poll.eventIcon ?? '📅';
    final cost = _formatCost();
    final deadline = _formatDeadline();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon + date ──
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                  if (poll.eventDate != null) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatDate(poll.eventDate),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poll.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.onDark : AppColors.slate900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ParticipationStatusBadge(hasVoted: poll.hasVoted),
                      _StatusBadge(isOpen: poll.isOpen),
                      if (poll.allowGuests)
                        const _Pill(
                          label: 'Convidados',
                          color: AppColors.info,
                          bg: AppColors.violet50,
                        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (poll.eventLocation != null)
                        _MetaChip(
                            icon: Icons.location_on_outlined,
                            label: poll.eventLocation!),
                      if (cost != null)
                        _MetaChip(
                            icon: Icons.attach_money,
                            label: cost,
                            color: AppColors.warningLight),
                      if (deadline != null)
                        _MetaChip(
                          icon: Icons.schedule,
                          label: poll.deadlinePassed
                              ? 'Prazo encerrado'
                              : 'Prazo: $deadline',
                          color: poll.deadlinePassed
                              ? AppColors.prototypeDanger
                              : AppColors.warningLight,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Right ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.group_outlined,
                        size: 12,
                        color:
                            isDark ? AppColors.slate500 : AppColors.slate400),
                    const SizedBox(width: 2),
                    Text(
                      '${poll.totalVoters}',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? AppColors.slate500 : AppColors.slate400),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right,
                    size: 16,
                    color: isDark ? AppColors.slate600 : AppColors.slate300),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internal helpers ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.green50 : AppColors.slate100,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isOpen ? AppColors.green200 : AppColors.slate200),
      ),
      child: Text(
        isOpen ? 'Aberto' : 'Encerrado',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOpen ? AppColors.primaryPressed : AppColors.slate500,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Pill({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.slate500
            : AppColors.slate400);
    return Row(
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: c),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
