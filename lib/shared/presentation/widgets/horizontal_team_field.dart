import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class FieldPlayer {
  final String id;
  final String name;
  final bool isGoalkeeper;
  final bool dimmed;

  const FieldPlayer({
    required this.id,
    required this.name,
    this.isGoalkeeper = false,
    this.dimmed = false,
  });
}

// ── Position tables (ported from web TOP_OUT) ─────────────────────────────────

const _kTopOut = <int, List<Offset>>{
  0: [],
  1: [Offset(0.50, 0.35)],
  2: [Offset(0.25, 0.35), Offset(0.75, 0.35)],
  3: [Offset(0.50, 0.24), Offset(0.20, 0.38), Offset(0.80, 0.38)],
  4: [
    Offset(0.28, 0.24),
    Offset(0.72, 0.24),
    Offset(0.20, 0.40),
    Offset(0.80, 0.40)
  ],
  5: [
    Offset(0.50, 0.22),
    Offset(0.20, 0.30),
    Offset(0.80, 0.30),
    Offset(0.22, 0.43),
    Offset(0.78, 0.43),
  ],
  6: [
    Offset(0.18, 0.19),
    Offset(0.50, 0.23),
    Offset(0.82, 0.19),
    Offset(0.18, 0.38),
    Offset(0.50, 0.44),
    Offset(0.82, 0.38),
  ],
  7: [
    Offset(0.18, 0.19),
    Offset(0.36, 0.25),
    Offset(0.64, 0.25),
    Offset(0.82, 0.19),
    Offset(0.18, 0.37),
    Offset(0.50, 0.44),
    Offset(0.82, 0.37),
  ],
};

List<Offset> _buildHalf(List<FieldPlayer> players, double gkY, bool flipY) {
  if (players.isEmpty) return [];
  final res = List<Offset>.filled(players.length, Offset.zero);
  final gkI = players.indexWhere((p) => p.isGoalkeeper);
  if (gkI >= 0) res[gkI] = Offset(0.50, gkY);
  final outIs =
      List.generate(players.length, (i) => i).where((i) => i != gkI).toList();
  if (outIs.isEmpty) return res;
  final n = math.min(outIs.length, 7);
  final tbl = _kTopOut[n] ?? _kTopOut[7]!;
  for (var i = 0; i < outIs.length; i++) {
    final p = tbl[math.min(i, tbl.length - 1)];
    res[outIs[i]] = flipY ? Offset(p.dx, 1 - p.dy) : p;
  }
  return res;
}

// 90° CCW rotation: vertical (portrait) → horizontal (landscape)
Offset _toH(Offset p) => Offset(p.dy, 1 - p.dx);

// ── Widget ────────────────────────────────────────────────────────────────────

class HorizontalTeamField extends StatelessWidget {
  final List<FieldPlayer> teamA;
  final List<FieldPlayer> teamB;
  final Color teamAColor;
  final Color teamBColor;
  final BorderRadius? borderRadius;
  final bool canInteract;
  final String? sel1Id;
  final String? sel2Id;
  final void Function(String id, bool isTeamA)? onPlayerClick;

  const HorizontalTeamField({
    super.key,
    required this.teamA,
    required this.teamB,
    this.teamAColor = AppColors.info,
    this.teamBColor = AppColors.lightPlaceholder,
    this.borderRadius,
    this.canInteract = false,
    this.sel1Id,
    this.sel2Id,
    this.onPlayerClick,
  });

  @override
  Widget build(BuildContext context) {
    final posA = _buildHalf(teamA, 0.10, false).map(_toH).toList();
    final posB = _buildHalf(teamB, 0.90, true).map(_toH).toList();

    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                // Field markings
                CustomPaint(
                  size: Size(w, h),
                  painter: _HorizontalFieldPainter(),
                ),

                // Team A pins
                for (var i = 0; i < teamA.length; i++)
                  _PlayerPin(
                    name: teamA[i].name,
                    color: teamAColor,
                    pos: posA[i],
                    dimmed: teamA[i].dimmed,
                    width: w,
                    height: h,
                    isSelected: canInteract &&
                        (sel1Id == teamA[i].id || sel2Id == teamA[i].id),
                    onTap: canInteract && onPlayerClick != null
                        ? () => onPlayerClick!(teamA[i].id, true)
                        : null,
                  ),

                // Team B pins
                for (var i = 0; i < teamB.length; i++)
                  _PlayerPin(
                    name: teamB[i].name,
                    color: teamBColor,
                    pos: posB[i],
                    dimmed: teamB[i].dimmed,
                    width: w,
                    height: h,
                    isSelected: canInteract &&
                        (sel1Id == teamB[i].id || sel2Id == teamB[i].id),
                    onTap: canInteract && onPlayerClick != null
                        ? () => onPlayerClick!(teamB[i].id, false)
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Field Painter (300×200 coordinate space, landscape) ───────────────────────

class _HorizontalFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 300;
    final scaleY = size.height / 200;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final grass = Paint()..color = AppColors.primaryPressed;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 200), grass);

    // Alternating stripes
    final stripeLight = Paint()..color = AppColors.onDark04;
    for (var i = 0; i < 6; i++) {
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(i * 50, 0, 50, 200), stripeLight);
      }
    }

    final line = Paint()
      ..color = AppColors.onDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // Outer boundary
    canvas.drawRect(const Rect.fromLTWH(8, 8, 284, 184), line);

    // Center line
    canvas.drawLine(const Offset(150, 8), const Offset(150, 192), line);

    // Center circle
    canvas.drawCircle(const Offset(150, 100), 28, line);
    canvas.drawCircle(const Offset(150, 100), 1.5,
        Paint()..color = AppColors.onDark.withValues(alpha: 0.55));

    // Left penalty area (Team A side)
    canvas.drawRect(const Rect.fromLTWH(8, 52, 54, 96), line);
    // Left goal area
    canvas.drawRect(const Rect.fromLTWH(8, 72, 22, 56), line);
    // Left penalty spot
    canvas.drawCircle(const Offset(44, 100), 1.5,
        Paint()..color = AppColors.onDark.withValues(alpha: 0.55));
    // Left goalpost
    final goalPost = Paint()
      ..color = AppColors.onDark.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(const Rect.fromLTWH(3, 82, 5, 36), goalPost);

    // Right penalty area (Team B side)
    canvas.drawRect(const Rect.fromLTWH(238, 52, 54, 96), line);
    // Right goal area
    canvas.drawRect(const Rect.fromLTWH(270, 72, 22, 56), line);
    // Right penalty spot
    canvas.drawCircle(const Offset(256, 100), 1.5,
        Paint()..color = AppColors.onDark.withValues(alpha: 0.55));
    // Right goalpost
    canvas.drawRect(const Rect.fromLTWH(292, 82, 5, 36), goalPost);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HorizontalFieldPainter old) => false;
}

// ── Player Pin ────────────────────────────────────────────────────────────────

class _PlayerPin extends StatelessWidget {
  final String name;
  final Color color;
  final Offset pos; // normalized 0..1
  final bool dimmed;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PlayerPin({
    required this.name,
    required this.color,
    required this.pos,
    required this.dimmed,
    required this.width,
    required this.height,
    this.isSelected = false,
    this.onTap,
  });

  static String _abbr(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const pinR = 11.0;
    const pinD = pinR * 2;
    const labelW = 62.0;

    final cx = pos.dx * width;
    final cy = pos.dy * height;

    // Clamp so the pin label never clips outside the field edges
    final left =
        (cx - labelW / 2).clamp(0.0, math.max(0.0, width - labelW)).toDouble();

    final uiColor = dimmed
        ? color.withValues(alpha: 0.35)
        : (color.computeLuminance() > 0.8
            ? AppColors.lightTextSecondary
            : color);

    final textColor =
        dimmed ? AppColors.onDark.withValues(alpha: 0.35) : AppColors.onDark;

    final borderColor = isSelected
        ? AppColors.warning // amber — "selected" ring
        : AppColors.onDark.withValues(alpha: dimmed ? 0.2 : 0.7);
    final borderWidth = isSelected ? 2.0 : 1.5;

    Widget pin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: pinD,
          height: pinD,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.warning : uiColor,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: dimmed
                ? []
                : [
                    BoxShadow(
                      color: (isSelected ? AppColors.warning : uiColor)
                          .withValues(alpha: 0.6),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              _abbr(name),
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.warning.withValues(alpha: 0.85)
                : AppColors.darkApp.withValues(alpha: dimmed ? 0.25 : 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 8.0,
              fontWeight: FontWeight.w700,
              color: AppColors.onDark.withValues(alpha: dimmed ? 0.45 : 1.0),
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    if (onTap != null) {
      pin = GestureDetector(onTap: onTap, child: pin);
    }

    return Positioned(
      left: left,
      top: cy - pinR,
      width: labelW,
      child: pin,
    );
  }
}
