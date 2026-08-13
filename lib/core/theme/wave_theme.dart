import 'package:flutter/material.dart';

import 'appearance_preferences.dart';

abstract final class WaveColors {
  static const primary = Color(0xFF5B8DEF);
  static const primaryStrong = Color(0xFF315FAD);
  static const primaryContainer = Color(0xFFE8F0FE);
  static const background = Color(0xFFF5F8FC);
  static const ink = Color(0xFF1D2A3A);
  static const muted = Color(0xFF69788C);
  static const expense = Color(0xFFD86464);
  static const income = Color(0xFF3F8F70);
  static const savings = Color(0xFF269CA3);
  static const warning = Color(0xFFC28732);
}

abstract final class WaveTheme {
  static ThemeData forChoice(WaveThemeChoice choice) => switch (choice) {
    WaveThemeChoice.oceanLight => _build(
      brightness: Brightness.light,
      primary: WaveColors.primary,
      primaryStrong: WaveColors.primaryStrong,
      primaryContainer: WaveColors.primaryContainer,
      background: WaveColors.background,
      surface: Colors.white,
      ink: WaveColors.ink,
      border: const Color(0xFFDCE5F2),
    ),
    WaveThemeChoice.deepBlue => _build(
      brightness: Brightness.light,
      primary: const Color(0xFF3977D5),
      primaryStrong: const Color(0xFF173F7A),
      primaryContainer: const Color(0xFFDCEAFF),
      background: const Color(0xFFECF3FC),
      surface: const Color(0xFFF8FBFF),
      ink: const Color(0xFF132B4C),
      border: const Color(0xFFC8D9EF),
    ),
    WaveThemeChoice.calmNight => _build(
      brightness: Brightness.dark,
      primary: const Color(0xFF82B1FF),
      primaryStrong: const Color(0xFFBBD4FF),
      primaryContainer: const Color(0xFF203A60),
      background: const Color(0xFF101A29),
      surface: const Color(0xFF182538),
      ink: const Color(0xFFE8F1FF),
      border: const Color(0xFF30425B),
    ),
  };

  static ThemeData get light => forChoice(WaveThemeChoice.oceanLight);

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color primaryStrong,
    required Color primaryContainer,
    required Color background,
    required Color surface,
    required Color ink,
    required Color border,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: brightness == Brightness.dark
              ? const Color(0xFF092044)
              : Colors.white,
          primaryContainer: primaryContainer,
          onPrimaryContainer: primaryStrong,
          surface: surface,
          onSurface: ink,
          error: WaveColors.expense,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
