import 'package:flutter/material.dart';

/// Tailwind CSS slate palette — espelha o design system do site.
class AppColors {
  AppColors._();

  // Paleta do protótipo aprovado.
  static const lightApp = Color(0xFFF4F6F8);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSubtle = Color(0xFFF8FAFB);
  static const lightBorder = Color(0xFFE3E7EB);
  static const lightInputBorder = Color(0xFFE3E7EB);
  static const lightText = Color(0xFF1E2329);
  // Contraste reforçado para leitura em telas móveis. Os tons anteriores
  // ficavam muito suaves em textos pequenos no Android.
  static const lightTextSecondary = Color(0xFF6E7680);
  static const lightTextMuted = Color(0xFFA2ABB5);
  static const lightIcon = Color(0xFF2A3138);
  static const lightPlaceholder = Color(0xFF98A2AD);
  static const lightSeparator = Color(0xFFECEFF2);

  // Tema escuro: paleta oficial do PatotasApp.
  static const darkApp = Color(0xFF0D0D0F);
  static const darkCard = Color(0xFF202225);
  static const darkSubtle = Color(0xFF1A1A1D);
  static const darkElevated = Color(0xFF2A2D31);
  static const darkBorder = Color(0xFF33373C);
  static const darkInputBorder = Color(0xFF33373C);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFC8CDD2);
  static const darkTextMuted = Color(0xFF8D949C);
  static const darkIcon = Color(0xFFD9DEE3);
  static const darkPlaceholder = Color(0xFF6F7680);
  static const darkSeparator = Color(0xFF2C2F34);

  static const accent = Color(0xFF3CB043);
  static const accentLight = Color(0xFF3CB043);
  static const accentBackground = Color(0xFF1E7D2B);
  static const accentBackgroundLight = Color(0xFFE6F5E8);
  static const accentText = Color(0xFFFFFFFF);
  static const accentTextLight = Color(0xFF1E7D2B);

  static const prototypeSuccess = Color(0xFF3CB043);
  static const prototypeSuccessLight = Color(0xFF2E9836);
  static const prototypeDanger = Color(0xFFD64545);
  static const prototypeDangerLight = Color(0xFFD64545);
  static const notification = Color(0xFFD64545);

  static const primaryHover = Color(0xFF49C84C);
  static const primaryPressed = Color(0xFF2E9836);
  static const warning = Color(0xFFF5B700);
  static const warningLight = Color(0xFFE9A700);
  static const info = Color(0xFF3A86FF);
  static const infoLight = Color(0xFF2F7BFF);

  // Cores utilitárias centralizadas. Mantê-las aqui evita que overlays,
  // vídeos e ilustrações declarem `Colors.white/black` diretamente.
  static const transparent = Color(0x00000000);
  static const onDark = darkText;
  static const onDark04 = Color(0x0AFFFFFF);
  static const onDark10 = Color(0x1AFFFFFF);
  static const onDark12 = Color(0x1FFFFFFF);
  static const onDark24 = Color(0x3DFFFFFF);
  static const onDark30 = Color(0x4DFFFFFF);
  static const onDark38 = Color(0x61FFFFFF);
  static const onDark54 = Color(0x8AFFFFFF);
  static const onDark60 = Color(0x99FFFFFF);
  static const onDark70 = Color(0xB3FFFFFF);
  static const shadow12 = Color(0x1F0D0D0F);
  static const shadow08 = Color(0x140D0D0F);
  static const shadow18 = Color(0x2E0D0D0F);
  static const shadow20 = Color(0x330D0D0F);
  static const shadow22 = Color(0x380D0D0F);
  static const shadow25 = Color(0x400D0D0F);
  static const shadow26 = Color(0x420D0D0F);
  static const shadow34 = Color(0x570D0D0F);
  static const shadow38 = Color(0x610D0D0F);
  static const shadow40 = Color(0x660D0D0F);
  static const shadow45 = Color(0x730D0D0F);
  static const shadow54 = Color(0x8A0D0D0F);
  static const shadow67 = Color(0xAA0D0D0F);
  static const shadow87 = Color(0xDE0D0D0F);
  static const accent12 = Color(0x1F3CB043);
  static const accent16 = Color(0x293CB043);
  static const accent42 = Color(0x6B3CB043);
  static const success67 = Color(0xAA3CB043);

  // ── Tokens que faltavam em relação ao protótipo ────────────────────────────
  // O protótipo define estes em `:root` / `[data-theme="white"]`; sem eles as
  // telas acabam usando hex solto e o tema claro fica fora do padrão.

  /// Cor do texto sobre o accent. No claro é quase preto — texto branco sobre
  /// laranja não passa em contraste.
  static const onAccent = Color(0xFFFFFFFF);
  static const onAccentLight = Color(0xFFFFFFFF);

  /// Fundos de estado (chips, badges, células de pagamento).
  static const successBackground = Color(0xFF0F2B22);
  static const successBackgroundLight = Color(0xFFE3F5E8);
  static const dangerBackground = Color(0xFF2E1C1C);
  static const dangerBackgroundLight = Color(0xFFFBE3E3);

  /// Estado neutro — usado em badges "encerrado" e mensalidade não gerada.
  static const neutral = Color(0xFF8B909A);
  static const neutralBackground = Color(0xFF2A2F3A);
  static const neutralBackgroundLight = Color(0xFFECEEF1);

  /// Borda tracejada dos estados vazios.
  static const borderDashed = Color(0xFF2F3542);
  static const borderDashedLight = Color(0xFFD8DAE0);

  /// Badge de notificação. O valor escuro sobre fundo branco não passa em
  /// contraste, por isso o protótipo define um vermelho mais fechado no claro.
  static const notificationLight = Color(0xFFB42318);

  /// Azul de time, usado nos indicadores de escalação.
  static const teamBlue = Color(0xFF3B9FD4);

  // ── Resolvedores por brilho ────────────────────────────────────────────────
  // Evitam o `isDark ? X : Y` repetido em cada widget.

  static Color onAccentOf(Brightness b) =>
      b == Brightness.dark ? onAccent : onAccentLight;
  static Color successOf(Brightness b) =>
      b == Brightness.dark ? prototypeSuccess : prototypeSuccessLight;
  static Color successBgOf(Brightness b) =>
      b == Brightness.dark ? successBackground : successBackgroundLight;
  static Color dangerOf(Brightness b) =>
      b == Brightness.dark ? prototypeDanger : prototypeDangerLight;
  static Color dangerBgOf(Brightness b) =>
      b == Brightness.dark ? dangerBackground : dangerBackgroundLight;
  static Color neutralBgOf(Brightness b) =>
      b == Brightness.dark ? neutralBackground : neutralBackgroundLight;
  static Color borderDashedOf(Brightness b) =>
      b == Brightness.dark ? borderDashed : borderDashedLight;
  static Color notificationOf(Brightness b) =>
      b == Brightness.dark ? notification : notificationLight;
  static Color accentOf(Brightness b) =>
      b == Brightness.dark ? accent : accentLight;
  static Color accentBgOf(Brightness b) =>
      b == Brightness.dark ? accentBackground : accentBackgroundLight;
  static Color accentTextOf(Brightness b) =>
      b == Brightness.dark ? accentText : accentTextLight;

  static const slate50 = Color(0xFFF8FAFB);
  static const slate100 = Color(0xFFECEFF2);
  static const slate200 = Color(0xFFE3E7EB);
  static const slate300 = Color(0xFFC8CDD2);
  // Tons usados diretamente por várias telas para informações secundárias.
  // Mais escuros para manter leitura nítida no display do Android.
  static const slate400 = Color(0xFF98A2AD);
  static const slate500 = Color(0xFF8D949C);
  static const slate600 = Color(0xFF6E7680);
  static const slate700 = Color(0xFF33373C);
  static const slate800 = Color(0xFF202225);
  static const slate900 = Color(0xFF1E2329);
  static const slate950 = Color(0xFF0D0D0F);

  // Emerald – sucesso
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald500 = Color(0xFF3CB043);
  static const emerald700 = Color(0xFF2E9836);

  // Green – pagamento / sucesso
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green200 = Color(0xFFBBF7D0);
  static const green400 = Color(0xFF49C84C);
  static const green500 = Color(0xFF3CB043);
  static const green600 = Color(0xFF2E9836);
  static const green700 = Color(0xFF2E9836);

  // Rose – perigo
  static const rose50 = Color(0xFFFFF1F2);
  static const rose200 = Color(0xFFFFCDD2);
  static const rose400 = Color(0xFFD64545);
  static const rose500 = Color(0xFFD64545);
  static const rose600 = Color(0xFFD64545);

  // Amber – aviso
  static const amber50 = Color(0xFFFFFBEB);
  static const amber200 = Color(0xFFFDE68A);
  static const amber400 = Color(0xFFF5B700);
  static const amber500 = Color(0xFFF5B700);

  // Blue – informação
  static const blue50 = Color(0xFFEFF6FF);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue500 = Color(0xFF3A86FF);
  static const blue600 = Color(0xFF2F7BFF);

  // Violet – times/match
  static const violet50 = Color(0xFFF5F3FF);
  static const violet200 = Color(0xFFDDD6FE);
  static const violet600 = Color(0xFF3A86FF);
  static const violet700 = Color(0xFF2F7BFF);

  // Orange – pós-jogo
  static const orange50 = Color(0xFFFFF7ED);
  static const orange200 = Color(0xFFFED7AA);
  static const orange700 = Color(0xFFE9A700);

  // Gradientes de avatar (determinísticos por nome)
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF8B5CF6), Color(0xFF6366F1)], // violet → indigo
    [Color(0xFF0EA5E9), Color(0xFF22D3EE)], // sky → cyan
    [Color(0xFF10B981), Color(0xFF14B8A6)], // emerald → teal
    [Color(0xFFFB923C), Color(0xFFF43F5E)], // orange → rose
    [Color(0xFFEC4899), Color(0xFFD946EF)], // pink → fuchsia
    [Color(0xFFFBBF24), Color(0xFFF97316)], // amber → orange
  ];

  static List<Color> gradientForName(String name) {
    if (name.isEmpty) return avatarGradients[0];
    final idx =
        name.codeUnits.fold(0, (s, c) => s + c) % avatarGradients.length;
    return avatarGradients[idx];
  }
}

/// Tokens semânticos resolvidos pelo tema ativo.
///
/// Widgets devem preferir estes getters (ou `Theme.of(context).colorScheme`)
/// em vez de escolher tons claros/escuros ou declarar hexadecimais. Assim a
/// troca da paleta fica restrita a [AppColors] e [AppTheme].
extension AppThemeColors on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get appColors => appTheme.colorScheme;
  bool get isDarkTheme => appTheme.brightness == Brightness.dark;

  Color get appBackground => appTheme.scaffoldBackgroundColor;
  Color get appSurface => appColors.surface;
  Color get appSurfaceSubtle => appColors.surfaceContainerLow;
  Color get appSurfaceElevated => appColors.surfaceContainerHighest;
  Color get appBorder => appColors.outlineVariant;
  Color get appInputBorder => appColors.outline;
  Color get appSeparator => appTheme.dividerColor;
  Color get appTextPrimary => appColors.onSurface;
  Color get appTextSecondary => appColors.onSurfaceVariant;
  Color get appTextDisabled => appTheme.disabledColor;
  Color get appIconColor =>
      isDarkTheme ? AppColors.darkIcon : AppColors.lightIcon;
  Color get appPlaceholder =>
      isDarkTheme ? AppColors.darkPlaceholder : AppColors.lightPlaceholder;

  Color get appSuccess => AppColors.successOf(appTheme.brightness);
  Color get appSuccessContainer => AppColors.successBgOf(appTheme.brightness);
  Color get appWarning =>
      isDarkTheme ? AppColors.warning : AppColors.warningLight;
  Color get appWarningContainer => isDarkTheme
      ? AppColors.warning.withValues(alpha: .14)
      : AppColors.amber50;
  Color get appDanger => appColors.error;
  Color get appDangerContainer => appColors.errorContainer;
  Color get appInfo => isDarkTheme ? AppColors.info : AppColors.infoLight;
  Color get appInfoContainer =>
      isDarkTheme ? AppColors.info.withValues(alpha: .14) : AppColors.blue50;
}
