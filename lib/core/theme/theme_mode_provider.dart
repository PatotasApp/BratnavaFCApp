import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../providers/core_providers.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPreferencesProvider));
});

ThemeMode nextThemeMode(ThemeMode current) => switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
    };

class ThemeModeController extends StateNotifier<ThemeMode> {
  final SharedPreferences _preferences;

  ThemeModeController(SharedPreferences preferences)
      : _preferences = preferences,
        super(_readInitialMode(preferences));

  static ThemeMode _readInitialMode(SharedPreferences preferences) {
    return switch (preferences.getString(AppConstants.themeStorageKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _preferences.setString(AppConstants.themeStorageKey, mode.name);
  }
}
