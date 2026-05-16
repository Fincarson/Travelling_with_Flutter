import 'package:flutter/material.dart';

class AppColors {
  static const Color aquaBlue = Color(0xff11c7df);
  static const Color aquaBlueSoft = Color(0xffd8f8fd);
  static const Color deepOcean = Color(0xff075a78);
  static const Color midnightBlue = Color(0xff04384f);
  static const Color appWhite = Color(0xffffffff);
  static const Color signalCyan = Color(0xff62f4ff);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
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
