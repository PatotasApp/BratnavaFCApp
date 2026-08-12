import 'package:patotas_app/shared/presentation/widgets/app_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  testWidgets('main header shows only its identity and no back button',
      (tester) async {
    await tester.pumpWidget(
      app(
        const AppPageHeader.main(
          title: 'Partidas',
          icon: Icons.sports_soccer_rounded,
        ),
      ),
    );

    expect(find.text('Partidas'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer_rounded), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail header exposes back, explanation and actions',
      (tester) async {
    var wentBack = false;
    var refreshed = false;

    await tester.pumpWidget(
      app(
        AppPageHeader(
          title: 'Pagamentos',
          subtitle: 'Mensalidades, cobranças e caixa',
          icon: Icons.payments_outlined,
          onBack: () => wentBack = true,
          actions: [
            AppPageHeaderAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Atualizar',
              onPressed: () => refreshed = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pagamentos'), findsOneWidget);
    expect(find.text('Mensalidades, cobranças e caixa'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.byTooltip('Atualizar'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.tap(find.byTooltip('Atualizar'));

    expect(wentBack, isTrue);
    expect(refreshed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail header fits a compact phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        const AppPageHeader(
          title: 'Aniversários',
          subtitle: 'Datas cadastradas pelos jogadores da patota',
          icon: Icons.cake_outlined,
          actions: [
            AppPageHeaderAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Atualizar',
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('labeled actions stay below the page identity on compact width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var created = false;
    await tester.pumpWidget(
      app(
        AppPageHeader(
          title: 'Votacoes',
          subtitle: 'Decisoes e enquetes da patota',
          icon: Icons.how_to_vote_outlined,
          footer: AppPageHeaderActionBar(
            actions: [
              AppPageHeaderButton(
                label: 'Nova votacao',
                icon: Icons.add_rounded,
                tone: AppPageHeaderButtonTone.primary,
                onPressed: () => created = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Votacoes'), findsOneWidget);
    expect(find.text('Nova votacao'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).width, 288);

    await tester.tap(find.text('Nova votacao'));
    expect(created, isTrue);
  });

  testWidgets('multiple labeled actions split all available width equally',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        AppPageHeader(
          title: 'Calendario',
          subtitle: 'Eventos da patota',
          icon: Icons.calendar_month_rounded,
          footer: AppPageHeaderActionBar(
            actions: [
              AppPageHeaderButton(
                label: 'Categorias',
                icon: Icons.tune_rounded,
                onPressed: () {},
              ),
              AppPageHeaderButton(
                label: 'Novo evento',
                icon: Icons.add_rounded,
                tone: AppPageHeaderButtonTone.primary,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final secondaryWidth = tester.getSize(find.byType(OutlinedButton)).width;
    final primaryWidth = tester.getSize(find.byType(FilledButton)).width;

    expect(secondaryWidth, primaryWidth);
    expect(secondaryWidth * 2 + 8, 328);
    expect(tester.takeException(), isNull);
  });
}
