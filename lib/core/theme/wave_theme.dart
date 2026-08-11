import 'package:flutter/material.dart';

abstract final class WaveColors {
  static const primary = Color(0xFF5B8DEF);
  static const primaryStrong = Color(0xFF315FAD);
  static const primaryContainer = Color(0xFFE8F0FE);
  static const background = Color(0xFFF5F8FC);
  static const ink = Color(0xFF1D2A3A);
  static const muted = Color(0xFF69788C);
  static const expense = Color(0xFFD86464);
  static const income = Color(0xFF3F8F70);
  static const warning = Color(0xFFC28732);
}

abstract final class WaveTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: WaveColors.primary,
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: WaveColors.primary,
          onPrimary: Colors.white,
          primaryContainer: WaveColors.primaryContainer,
          onPrimaryContainer: WaveColors.primaryStrong,
          surface: Colors.white,
          onSurface: WaveColors.ink,
          error: WaveColors.expense,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: WaveColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: WaveColors.background,
        foregroundColor: WaveColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFDCE5F2)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFDCE5F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFDCE5F2)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: WaveColors.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
