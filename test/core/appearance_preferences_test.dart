import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/theme/appearance_preferences.dart';
import 'package:wave/core/theme/wave_theme.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/providers.dart';

void main() {
  test('all Wave themes expose the expected brightness', () {
    expect(
      WaveTheme.forChoice(WaveThemeChoice.oceanLight).brightness,
      Brightness.light,
    );
    expect(
      WaveTheme.forChoice(WaveThemeChoice.deepBlue).brightness,
      Brightness.light,
    );
    expect(
      WaveTheme.forChoice(WaveThemeChoice.calmNight).brightness,
      Brightness.dark,
    );
  });

  test('appearance controller persists theme and motion choices', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = AppearanceController(database);

    await controller.setTheme(WaveThemeChoice.calmNight);
    await controller.setGentleMotion(false);

    expect(
      await database.preference(AppearanceController.themeKey),
      'calmNight',
    );
    expect(await database.preference(AppearanceController.motionKey), 'false');

    final restored = AppearanceController(database);
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.theme, WaveThemeChoice.calmNight);
    expect(restored.state.gentleMotion, isFalse);
  });
}
