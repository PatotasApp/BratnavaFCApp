import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/shared/presentation/widgets/avatar_widget.dart';

void main() {
  testWidgets('foto de usuário nunca fica com cantos quadrados',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarWidget(
            name: 'Usuário',
            photoUrl: 'https://example.com/photo.jpg',
            size: 40,
            borderRadius: 0,
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    final radius = clip.borderRadius.resolve(TextDirection.ltr).topLeft.x;

    expect(radius, greaterThan(0));
    expect(radius, lessThan(20));
  });
}
