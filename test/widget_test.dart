import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:patotas_app/core/theme/app_theme.dart';
import 'package:patotas_app/shared/presentation/widgets/app_button.dart';
import 'package:patotas_app/shared/presentation/widgets/group_icon_renderer.dart';
import 'package:patotas_app/shared/presentation/widgets/prototype_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'layout base cabe no Pixel 5 em tema ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(
              body: SafeArea(
                child: PrototypeScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PrototypeSectionTitle(
                        title: 'Próxima pelada',
                        count: '21',
                      ),
                      const SizedBox(height: 12),
                      PrototypeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PlayerNameWithIcon(
                              name: 'Jogador de exemplo',
                              isGoalkeeper: true,
                              icons: GroupIcons.defaults,
                              iconSize: 16,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                renderGroupIcon(GroupIcons.defaults.goal),
                                renderGroupIcon(GroupIcons.defaults.assist),
                                renderGroupIcon(GroupIcons.defaults.mvp),
                                renderGroupIcon(GroupIcons.defaults.rank1),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AppButton(
                              label: 'Continuar',
                              onPressed: () {},
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.widgetWithText(ElevatedButton, 'Continuar'))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(find.text('Jogador de exemplo'), findsOneWidget);
      },
    );
  }
}
