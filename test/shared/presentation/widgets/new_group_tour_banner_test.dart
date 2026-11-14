import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/shared/presentation/widgets/new_group_tour_banner.dart';

void main() {
  testWidgets('mostra progresso e permite avançar ou pular o tour',
      (tester) async {
    var advanced = false;
    var skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewGroupTourOverlay(
            step: 2,
            title: 'Cadastre dois uniformes',
            description: 'Escolha as duas cores da patota.',
            status: '1/2',
            actionLabel: 'Cadastrar 2º uniforme',
            onAction: () => advanced = true,
            onSkip: () => skipped = true,
          ),
        ),
      ),
    );

    expect(find.text('TOUR GUIADO · ETAPA 2 DE 3'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.text('Cadastrar 2º uniforme'));
    await tester.tap(find.text('Pular tour'));

    expect(advanced, isTrue);
    expect(skipped, isTrue);
  });

  testWidgets('desabilita a ação enquanto a etapa não pode avançar',
      (tester) async {
    var advanced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewGroupTourOverlay(
            step: 2,
            title: 'Uniformes',
            description: 'Cadastre dois uniformes.',
            actionLabel: 'Continuar',
            actionEnabled: false,
            onAction: () => advanced = true,
            onSkip: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continuar'));
    expect(advanced, isFalse);
  });

  testWidgets('mantém o conteúdo ao fundo interativo fora do painel',
      (tester) async {
    var backgroundTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: FilledButton(
                  onPressed: () => backgroundTapped = true,
                  child: const Text('Campo ao fundo'),
                ),
              ),
              NewGroupTourOverlay(
                step: 1,
                title: 'Configurações',
                description: 'Ajuste os campos ao fundo.',
                actionLabel: 'Próxima',
                onAction: () {},
                onSkip: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Campo ao fundo'));
    expect(backgroundTapped, isTrue);
  });
}
