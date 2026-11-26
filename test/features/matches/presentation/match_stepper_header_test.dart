import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/features/matches/domain/entities/match_models.dart';
import 'package:patotas_app/features/matches/presentation/widgets/match_stepper_header.dart';

void main() {
  testWidgets('oculta etapa tecnica de encerramento', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MatchStepperHeader(currentStep: MatchStep.ended),
        ),
      ),
    );

    expect(find.text('ETAPA 5 DE 6'), findsOneWidget);
    expect(find.text('Pós-jogo'), findsOneWidget);
    expect(find.text('Encerramento'), findsNothing);
  });
}
