import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/presentation/widgets/apple_sign_in_button.dart';

void main() {
  testWidgets('o logo da Apple renderiza a partir do asset SVG',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleSignInButton(onPressed: () {}),
        ),
      ),
    );

    // O SVG carrega de forma assíncrona; sem isso o teste passaria antes de o
    // parser tocar no arquivo.
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Continuar com Apple'), findsOneWidget);

    // SVG malformado ou caminho renomeado só falham em runtime.
    expect(tester.takeException(), isNull);
  });
}
