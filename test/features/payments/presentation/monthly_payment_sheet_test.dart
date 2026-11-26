import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/payments/domain/entities/payment_entities.dart';
import 'package:patotas_app/features/payments/presentation/widgets/monthly_payment_sheet.dart';

void main() {
  testWidgets('pagamento mensal não exibe avaliação do jogador',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const row = PlayerRow(
      playerId: 'player-1',
      playerName: 'Ademir',
      months: [
        MonthlyCell(
          month: 11,
          status: 0,
          amount: 45,
          discount: 0,
          hasProof: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MonthlyPaymentSheet(
              groupId: '',
              row: row,
              month: 11,
              isAdmin: true,
              onSubmit: (_) async {},
              onSaved: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Comprovante (opcional)'), findsOneWidget);
    expect(find.text('Avaliação'), findsNothing);
    expect(find.text('Avaliação do jogador'), findsNothing);
    expect(find.text('Nível estimado (1–5 estrelas)'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);
  });
}
