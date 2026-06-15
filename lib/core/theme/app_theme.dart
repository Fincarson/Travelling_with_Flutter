import 'package:flutter/material.dart';

class AppColors {
  static const Color aquaBlue = Color(0xff11c7df);
  static const Color aquaBlueSoft = Color(0xffd8f8fd);
  static const Color deepOcean = Color(0xff075a78);
  static const Color midnightBlue = Color(0xff04384f);
  static const Color appWhite = Color(0xffffffff);
  static const Color signalCyan = Color(0xff62f4ff);
}

class TravelAgentColors {
  static const Color primary = Color(0xFF355872);
  static const Color secondary = Color(0xFF7AAACE);
  static const Color accent = Color(0xFF9CD5FF);
  static const Color background = Color(0xFFF7F8F0);
}

class AppFontSource {
  static const String assetDirectory = 'assets/fonts/';

  // Keep null to use Flutter's default platform font. Add a font family in
  // pubspec.yaml and set this value when a custom asset font is available.
  static const String? family = null;
}

class TravelAgentTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: TravelAgentColors.primary,
          brightness: Brightness.light,
          primary: TravelAgentColors.primary,
          secondary: TravelAgentColors.secondary,
          surface: Colors.white,
        ).copyWith(
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFCFDF8),
          surfaceContainer: const Color(0xFFF5F7F2),
          surfaceContainerHigh: const Color(0xFFEDF2F3),
          surfaceContainerHighest: const Color(0xFFE3EBEE),
          outlineVariant: const Color(0xFFD9E2E5),
        );
    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: TravelAgentColors.background,
    );
  }

  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: TravelAgentColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF9CD5FF),
          onPrimary: const Color(0xFF082A3A),
          primaryContainer: const Color(0xFF244A61),
          onPrimaryContainer: const Color(0xFFD8EEFF),
          secondary: const Color(0xFF9DC8E8),
          onSecondary: const Color(0xFF102C3B),
          surface: const Color(0xFF101A20),
          onSurface: const Color(0xFFEAF2F6),
          onSurfaceVariant: const Color(0xFFB8C8D0),
          surfaceContainerLowest: const Color(0xFF0B1419),
          surfaceContainerLow: const Color(0xFF18242B),
          surfaceContainer: const Color(0xFF1D2B33),
          surfaceContainerHigh: const Color(0xFF263740),
          surfaceContainerHighest: const Color(0xFF30434D),
          outline: const Color(0xFF82949D),
          outlineVariant: const Color(0xFF3C505A),
        );
    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: const Color(0xFF101A20),
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: colorScheme.surface,
      fontFamily: AppFontSource.family,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}

class MaterialTheme {
  const MaterialTheme(this.textTheme);

  final TextTheme textTheme;

  static ColorScheme lightScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.aquaBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.midnightBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xffcbeef7),
      onPrimaryContainer: const Color(0xff002c3f),
      secondary: AppColors.aquaBlue,
      onSecondary: const Color(0xff002f38),
      secondaryContainer: AppColors.aquaBlueSoft,
      onSecondaryContainer: const Color(0xff003942),
      tertiary: AppColors.deepOcean,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xffbdeeff),
      onTertiaryContainer: const Color(0xff003545),
      surface: AppColors.appWhite,
      onSurface: const Color(0xff102027),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xfff2fbfd),
      surfaceContainerHigh: const Color(0xffe4f6fb),
      surfaceContainerHighest: const Color(0xffd3edf5),
      outline: const Color(0xff6f858d),
      outlineVariant: const Color(0xffb8d2da),
    );
  }

  static ColorScheme darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.aquaBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.signalCyan,
      onPrimary: const Color(0xff003642),
      primaryContainer: AppColors.deepOcean,
      onPrimaryContainer: const Color(0xffbdf5ff),
      secondary: const Color(0xff84dbea),
      onSecondary: const Color(0xff003640),
      secondaryContainer: const Color(0xff164f60),
      onSecondaryContainer: const Color(0xffc8f5ff),
      tertiary: const Color(0xff9bdff2),
      onTertiary: const Color(0xff003545),
      tertiaryContainer: const Color(0xff04384f),
      onTertiaryContainer: const Color(0xffbdf5ff),
      surface: const Color(0xff071b22),
      onSurface: const Color(0xffe7f7fb),
      surfaceContainerLowest: const Color(0xff031216),
      surfaceContainerLow: const Color(0xff0b252d),
      surfaceContainer: const Color(0xff0f2e38),
      surfaceContainerHigh: const Color(0xff173944),
      surfaceContainerHighest: const Color(0xff214650),
      outline: const Color(0xff86a6af),
      outlineVariant: const Color(0xff345762),
    );
  }

  ThemeData light() => _theme(lightScheme());

  ThemeData dark() => _theme(darkScheme());

  ThemeData _theme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      fontFamily: AppFontSource.family,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: isDark
            ? colorScheme.primary.withValues(alpha: 0.24)
            : colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant;

          return TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
