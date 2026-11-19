import 'package:flutter/material.dart';

class FieldLabelAnchor {
  final Offset center;
  final String text;

  const FieldLabelAnchor({required this.center, required this.text});
}

/// Posiciona rótulos completos ao redor dos pinos, evitando sobreposição.
///
/// A primeira tentativa fica abaixo do jogador; em caso de colisão, tenta
/// acima e depois aumenta gradualmente a distância vertical. Todos os nomes
/// são calculados juntos, portanto a regra também vale entre times adversários.
List<Rect> resolveFieldLabelRects({
  required List<FieldLabelAnchor> anchors,
  required Size fieldSize,
  required double labelWidth,
  required double pinRadius,
  required TextStyle textStyle,
  double horizontalPadding = 4,
  double verticalPadding = 1,
  double gap = 2,
}) {
  if (anchors.isEmpty) return const [];

  final heights = anchors.map((anchor) {
    final painter = TextPainter(
      text: TextSpan(text: anchor.text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelWidth - horizontalPadding * 2);
    return painter.height + verticalPadding * 2;
  }).toList(growable: false);

  final result = List<Rect?>.filled(anchors.length, null);
  final occupied = <Rect>[];
  final order = List<int>.generate(anchors.length, (index) => index)
    ..sort((a, b) {
      final byX = anchors[a].center.dx.compareTo(anchors[b].center.dx);
      return byX != 0
          ? byX
          : anchors[a].center.dy.compareTo(anchors[b].center.dy);
    });

  for (final index in order) {
    final anchor = anchors[index];
    final height = heights[index];
    final left = (anchor.center.dx - labelWidth / 2)
        .clamp(0.0, (fieldSize.width - labelWidth).clamp(0.0, double.infinity))
        .toDouble();
    final below = anchor.center.dy + pinRadius + gap;
    final above = anchor.center.dy - pinRadius - gap - height;
    final candidates = <Rect>[];

    for (var step = 0; step < 8; step++) {
      final distance = step * (height + gap);
      for (final top in [below + distance, above - distance]) {
        final clampedTop = top
            .clamp(0.0, (fieldSize.height - height).clamp(0.0, double.infinity))
            .toDouble();
        final candidate = Rect.fromLTWH(left, clampedTop, labelWidth, height);
        if (!candidates.contains(candidate)) candidates.add(candidate);
      }
    }

    Rect? chosen;
    var bestScore = double.infinity;
    for (final candidate in candidates) {
      var score = 0.0;
      for (final other in occupied) {
        final paddedOther = other.inflate(gap);
        if (!candidate.overlaps(paddedOther)) continue;
        final intersection = candidate.intersect(paddedOther);
        score += intersection.width * intersection.height;
      }
      score += (candidate.top - below).abs() * .001;
      if (score < bestScore) {
        bestScore = score;
        chosen = candidate;
        if (score < .01) break;
      }
    }

    chosen ??= Rect.fromLTWH(left, below, labelWidth, height);
    result[index] = chosen;
    occupied.add(chosen);
  }

  return result.cast<Rect>();
}
