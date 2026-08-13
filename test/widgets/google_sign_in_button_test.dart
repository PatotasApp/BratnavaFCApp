import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/presentation/widgets/google_sign_in_button.dart';

void main() {
  testWidgets('o "G" oficial do Google renderiza a partir do asset SVG',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(onPressed: () {}),
        ),
      ),
    );

    // O SVG carrega de forma assíncrona; sem isso o teste passaria antes de o
    // parser tocar no arquivo, que é justamente o que se quer verificar.
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);

    // Um SVG malformado só falha em runtime, não na análise estática. Este teste
    // existe para o asset não quebrar em silêncio se alguém mexer no arquivo ou
    // renomear o caminho.
    expect(tester.takeException(), isNull);
  });
}
