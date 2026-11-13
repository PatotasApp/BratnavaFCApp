import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/shared/presentation/widgets/field_label_layout.dart';

void main() {
  test('separa verticalmente nomes próximos de qualquer equipe', () {
    const style = TextStyle(fontSize: 9, height: 1.15);
    final rects = resolveFieldLabelRects(
      anchors: const [
        FieldLabelAnchor(
          center: Offset(100, 80),
          text: 'Guilherme Ademir',
        ),
        FieldLabelAnchor(
          center: Offset(106, 80),
          text: 'Pedro Roweder',
        ),
      ],
      fieldSize: const Size(300, 200),
      labelWidth: 72,
      pinRadius: 14,
      textStyle: style,
    );

    expect(rects, hasLength(2));
    expect(rects[0].overlaps(rects[1].inflate(2)), isFalse);
    expect(rects[0].height, greaterThan(12));
  });
}
