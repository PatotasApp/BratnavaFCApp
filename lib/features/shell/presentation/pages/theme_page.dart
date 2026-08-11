import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/presentation/widgets/app_page_header.dart';

class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(
              title: 'Tema',
              subtitle: 'Escolha a aparência do aplicativo',
              icon: Icons.palette_outlined,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ThemeChoice(
                    mode: ThemeMode.light,
                    selected: selected,
                    icon: Icons.light_mode_outlined,
                    title: 'Claro',
                    subtitle: 'Sempre usar o tema claro.',
                  ),
                  const SizedBox(height: 10),
                  _ThemeChoice(
                    mode: ThemeMode.dark,
                    selected: selected,
                    icon: Icons.dark_mode_outlined,
                    title: 'Escuro',
                    subtitle: 'Sempre usar o tema escuro.',
                  ),
                  const SizedBox(height: 10),
                  _ThemeChoice(
                    mode: ThemeMode.system,
                    selected: selected,
                    icon: Icons.settings_brightness_outlined,
                    title: 'Sistema',
                    subtitle: 'Seguir a configuração do aparelho.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends ConsumerWidget {
  final ThemeMode mode;
  final ThemeMode selected;
  final IconData icon;
  final String title;
  final String subtitle;

  const _ThemeChoice({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = mode == selected;
    final accent =
        AppColors.accentOf(isDark ? Brightness.dark : Brightness.light);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? accent.withAlpha(isDark ? 38 : 20)
                : (isDark ? AppColors.slate800 : AppColors.onDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? accent
                  : (isDark ? AppColors.slate700 : AppColors.slate200),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active
                      ? accent.withAlpha(32)
                      : (isDark ? AppColors.slate700 : AppColors.slate100),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon,
                    color: active
                        ? accent
                        : (isDark ? AppColors.slate300 : AppColors.slate600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.onDark
                                : AppColors.slate900)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500)),
                  ],
                ),
              ),
              if (active) Icon(Icons.check_circle_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
