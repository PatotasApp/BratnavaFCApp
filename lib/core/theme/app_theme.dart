import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkApp : AppColors.lightApp;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final subtle = isDark ? AppColors.darkSubtle : AppColors.lightSubtle;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBorder =
        isDark ? AppColors.darkInputBorder : AppColors.lightInputBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accent = isDark ? AppColors.accent : AppColors.accentLight;
    final accentBackground =
        isDark ? AppColors.accentBackground : AppColors.accentBackgroundLight;
    const onAccent = Colors.white;
    final success =
        isDark ? AppColors.prototypeSuccess : AppColors.prototypeSuccessLight;
    final danger =
        isDark ? AppColors.prototypeDanger : AppColors.prototypeDangerLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: accentBackground,
      onPrimaryContainer:
          isDark ? AppColors.accentText : AppColors.accentTextLight,
      secondary: secondary,
      onSecondary: surface,
      secondaryContainer: subtle,
      onSecondaryContainer: text,
      tertiary: success,
      onTertiary: surface,
      error: danger,
      onError: surface,
      errorContainer:
          isDark ? AppColors.dangerBackground : AppColors.dangerBackgroundLight,
      onErrorContainer: danger,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: secondary,
      surfaceDim: background,
      surfaceBright: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: subtle,
      surfaceContainer: surface,
      surfaceContainerHigh:
          isDark ? AppColors.darkElevated : AppColors.lightSubtle,
      surfaceContainerHighest:
          isDark ? AppColors.darkElevated : AppColors.lightCard,
      outline: inputBorder,
      outlineVariant: border,
      shadow: isDark ? AppColors.darkApp : AppColors.lightText,
      scrim: AppColors.darkApp,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      canvasColor: background,
      disabledColor: muted,
      dividerColor: isDark ? AppColors.darkSeparator : AppColors.lightSeparator,
      focusColor: accent.withValues(alpha: .14),
      hoverColor: accent.withValues(alpha: .08),
      highlightColor: accent.withValues(alpha: .10),
      splashColor: accent.withValues(alpha: .12),
      primaryTextTheme: base.textTheme.apply(
        fontFamily: GoogleFonts.poppins().fontFamily,
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkIcon : AppColors.lightIcon,
          size: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? .12 : .06),
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSubtle : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        hintStyle: TextStyle(
          color:
              isDark ? AppColors.darkPlaceholder : AppColors.lightPlaceholder,
          fontSize: 13,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 12),
        floatingLabelStyle: TextStyle(color: accent, fontSize: 12),
        helperStyle: TextStyle(color: secondary, fontSize: 11),
        errorStyle: TextStyle(color: danger, fontSize: 11),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: secondary,
        ),
        // .proto-label — 11px, não 10. É o estilo das seções em caixa alta
        // ("ETAPA 1 DE 7", "PATOTA ATIVA") e aparece em quase toda tela.
        labelSmall: GoogleFonts.poppins(
          fontSize: 11,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: .77, // .07em em 11px
          color: muted,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: border,
          disabledForegroundColor: muted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: isDark ? Colors.transparent : Colors.white,
          foregroundColor: accent,
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: accent,
          textStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          maximumSize: const Size(44, 44),
          foregroundColor: secondary,
          backgroundColor: surface,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: subtle,
        selectedColor: accent,
        side: BorderSide(color: inputBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: onAccent,
        ),
        iconTheme: IconThemeData(color: secondary, size: 16),
        deleteIconColor: secondary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightText,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        actionTextColor: AppColors.primaryHover,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkElevated : AppColors.lightText,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: secondary,
        indicatorColor: accent,
        dividerColor: border,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? accent : surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? onAccent : text),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkSeparator : AppColors.lightSeparator,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: isDark
            ? AppColors.accentBackground
            : AppColors.accentBackgroundLight,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 20,
              color: states.contains(WidgetState.selected)
                  ? colorScheme.onPrimaryContainer
                  : muted,
            )),
        labelTextStyle:
            WidgetStateProperty.resolveWith((states) => GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: states.contains(WidgetState.selected) ? accent : muted,
                )),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Colors.black.withValues(alpha: .60),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: inputBorder,
        dragHandleSize: const Size(38, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: accent,
        headerForegroundColor: onAccent,
        todayForegroundColor: WidgetStatePropertyAll(accent),
        todayBorder: BorderSide(color: accent),
        dayForegroundColor: WidgetStatePropertyAll(text),
        yearForegroundColor: WidgetStatePropertyAll(text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: subtle,
        dialHandColor: accent,
        hourMinuteColor: subtle,
        hourMinuteTextColor: text,
        dayPeriodColor: subtle,
        dayPeriodTextColor: text,
        entryModeIconColor: secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accent
                : Colors.transparent),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : inputBorder),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: inputBorder,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: .12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .28),
        selectionHandleColor: accent,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : inputBorder),
        thumbColor: WidgetStatePropertyAll(onAccent),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: secondary,
        textColor: text,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        subtitleTextStyle:
            GoogleFonts.poppins(fontSize: 11, height: 1.4, color: muted),
      ),
    );
  }
}
