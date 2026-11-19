import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/auth/presentation/widgets/legal_notice.dart';

void main() {
  testWidgets('aviso de aceite cita os termos e a política', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: LegalNotice())));

    expect(
      find.text(
          'Ao continuar, você concorda com os Termos de Uso e a Política de Privacidade.',
          findRichText: true),
      findsOneWidget,
    );
  });
}
