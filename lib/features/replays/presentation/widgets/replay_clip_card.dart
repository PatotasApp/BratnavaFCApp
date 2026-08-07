import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/replay_clip.dart';

class ReplayClipCard extends StatelessWidget {
  final ReplayClip clip;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback? onDelete;

  const ReplayClipCard({
    super.key,
    required this.clip,
    required this.isAdmin,
    required this.onTap,
    required this.onLike,
    required this.onFavorite,
    this.onDelete,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _formattedDate {
    try {
      final dt = AppDateUtils.parseOrNow(clip.matchDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return clip.matchDate;
    }
  }

  String get _eventLabel {
    final parts = <String>[];
    if (clip.scorerName != null) parts.add(clip.scorerName!);
    if (clip.assistName != null) parts.add('ass: ${clip.assistName}');
    if (parts.isEmpty && clip.eventType != null) parts.add(clip.eventType!);
    return parts.join(' · ');
  }

  String get _eventEmoji {
    switch ((clip.eventType ?? '').toLowerCase()) {
      case 'gol':
        return '⚽';
      case 'defesa':
        return '🧤';
      case 'falta':
        return '🟨';
      default:
        return '🎬';
    }
  }

  String get _minuteLabel => clip.minute != null ? "${clip.minute}'" : '';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? AppColors.slate800 : AppColors.onDark;
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final textPrimary = isDark ? AppColors.onDark : AppColors.slate900;
    final textSecond = isDark ? AppColors.onDark54 : AppColors.slate500;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                bottomLeft: Radius.circular(9),
              ),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppColors.lightText),
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.onDark.withValues(alpha: .15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.onDark30),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 18, color: AppColors.onDark),
                      ),
                    ),
                    // minute badge
                    if (clip.minute != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.darkApp.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _minuteLabel,
                            style: const TextStyle(
                                color: AppColors.onDark,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Date + place
                    Text(
                      '$_formattedDate · ${clip.matchPlace}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (_eventLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$_eventEmoji $_eventLabel',
                        style: TextStyle(fontSize: 11, color: textSecond),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                    if (clip.teamName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        clip.teamName!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Like
                  _MiniBtn(
                    icon: clip.isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        clip.isLiked ? AppColors.prototypeDanger : textSecond,
                    label: clip.likeCount > 0 ? '${clip.likeCount}' : null,
                    onTap: onLike,
                  ),
                  // Favourite
                  _MiniBtn(
                    icon: clip.isFavorited
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: clip.isFavorited ? AppColors.warning : textSecond,
                    onTap: onFavorite,
                  ),
                  // Delete (admin only)
                  if (isAdmin && onDelete != null)
                    _MiniBtn(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.prototypeDanger.withValues(alpha: .75),
                      onTap: onDelete!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact action button ─────────────────────────────────────────────────────

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icon,
    required this.color,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label != null)
              Text(
                label!,
                style: TextStyle(fontSize: 9, color: color),
              ),
          ],
        ),
      ),
    );
  }
}
