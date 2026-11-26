import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patotas_app/core/theme/theme_mode_provider.dart';

void main() {
  test('alterna os três temas em ciclo e exibe os rótulos corretos', () {
    expect(nextThemeMode(ThemeMode.system), ThemeMode.light);
    expect(nextThemeMode(ThemeMode.light), ThemeMode.dark);
    expect(nextThemeMode(ThemeMode.dark), ThemeMode.system);

    expect(themeModeLabel(ThemeMode.system), 'Sistema');
    expect(themeModeLabel(ThemeMode.light), 'Claro');
    expect(themeModeLabel(ThemeMode.dark), 'Escuro');
  });
}
