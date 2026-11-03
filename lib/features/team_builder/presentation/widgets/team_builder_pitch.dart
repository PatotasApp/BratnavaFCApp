import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/team_builder_models.dart';
import '../../domain/team_builder_format.dart';

/// Campo do Monte seu Time: goleiro embaixo, jogadores de linha por quantidade.
///
/// Tem altura própria (AspectRatio sobre a largura), então pode ficar numa
/// Column dentro de scroll sem achatar. Tudo escala pela largura.
class TeamBuilderPitch extends StatelessWidget {
  const TeamBuilderPitch({
    super.key,
    required this.players,
    this.sub,
    this.onPlayerTap,
    this.onEmptyTap,
    this.aspectRatio = 4 / 5,
    this.radius = 18,
  });

  final List<TeamBuilderPlayer> players;

  /// Texto pequeno embaixo do nome (ex.: "54%").
  final String Function(TeamBuilderPlayer)? sub;
  final void Function(TeamBuilderPlayer)? onPlayerTap;

  /// Com isso, mostra vagas vazias tocáveis.
  final VoidCallback? onEmptyTap;
  final double aspectRatio;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final slotW = w * .26;
          final slots = pitchSlots(players, withEmpty: onEmptyTap != null);
          return Stack(
            children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _StripedPitchPainter())),
              for (final s in slots)
                Positioned(
                  left: s.x * w - slotW / 2,
                  top: s.y * h - w * .12,
                  width: slotW,
                  child: s.player == null
                      ? _EmptySlot(
                          w: w, goalkeeper: s.goalkeeper, onTap: onEmptyTap)
                      : _PlayerSlot(
                          w: w,
                          player: s.player!,
                          goalkeeper: s.goalkeeper,
                          sub: sub?.call(s.player!) ?? '',
                          onTap: onPlayerTap == null
                              ? null
                              : () => onPlayerTap!(s.player!),
                        ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({
    required this.w,
    required this.player,
    required this.goalkeeper,
    required this.sub,
    this.onTap,
  });

  final double w;
  final TeamBuilderPlayer player;
  final bool goalkeeper;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = w * .15;
    final face = goalkeeper ? AppColors.goalkeeperYellow : AppColors.onDark;
    return Semantics(
      button: onTap != null,
      label: player.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatar,
              height: avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: face,
                shape: BoxShape.circle,
                border: Border.all(color: face, width: w * .008),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadow34,
                      blurRadius: w * .03,
                      offset: Offset(0, w * .01))
                ],
              ),
              child: Text(
                initialsOf(player.name),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: w * .05,
                    color: AppColors.slate900),
              ),
            ),
            SizedBox(height: w * .012),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: w * .02, vertical: w * .006),
              decoration: BoxDecoration(
                  color: AppColors.shadow54,
                  borderRadius: BorderRadius.circular(w * .02)),
              child: Text(
                player.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: w * .034,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onDark,
                    height: 1.2),
              ),
            ),
            if (sub.isNotEmpty) ...[
              SizedBox(height: w * .006),
              Text(sub,
                  style: TextStyle(
                      fontSize: w * .029,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onDark.withAlpha(230),
                      height: 1.2)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.w, required this.goalkeeper, this.onTap});

  final double w;
  final bool goalkeeper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = w * .15;
    return Semantics(
      button: true,
      label: goalkeeper ? 'Adicionar goleiro' : 'Adicionar jogador',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatar,
              height: avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.onDark12,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onDark60, width: w * .006),
              ),
              child: Icon(Icons.add_rounded,
                  size: w * .07, color: AppColors.onDark),
            ),
            SizedBox(height: w * .012),
            Text(
              goalkeeper ? 'goleiro' : 'adicionar',
              style: TextStyle(
                  fontSize: w * .029,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onDark.withAlpha(230)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixas de grama e marcações de meio campo (o time ataca para cima).
class _StripedPitchPainter extends CustomPainter {
  const _StripedPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stripe = h / 10;
    for (var i = 0; i < 10; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripe, w, stripe + .5),
        Paint()
          ..color = i.isEven ? AppColors.pitchStripe : AppColors.pitchStripeAlt,
      );
    }

    // Mesma geometria do protótipo: viewBox 100 × 125.
    final sx = w / 100;
    final sy = h / 125;
    final line = Paint()
      ..color = AppColors.onDark.withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5 * sx;
    Rect r(double x, double y, double rw, double rh) =>
        Rect.fromLTWH(x * sx, y * sy, rw * sx, rh * sy);

    canvas.drawRRect(
        RRect.fromRectAndRadius(r(4, 4, 92, 117), Radius.circular(sx)), line);
    canvas.drawOval(r(38, -8, 24, 24), line);
    canvas.drawRect(r(26, 99, 48, 22), line);
    canvas.drawRect(r(38, 111, 24, 10), line);
    canvas.drawArc(r(40, 91, 20, 16), 3.14159, 3.14159, false, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
