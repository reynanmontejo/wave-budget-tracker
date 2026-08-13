enum WaveThemeChoice { oceanLight, deepBlue, calmNight }

final class AppearancePreferences {
  const AppearancePreferences({
    this.theme = WaveThemeChoice.oceanLight,
    this.gentleMotion = true,
  });

  final WaveThemeChoice theme;
  final bool gentleMotion;

  AppearancePreferences copyWith({
    WaveThemeChoice? theme,
    bool? gentleMotion,
  }) => AppearancePreferences(
    theme: theme ?? this.theme,
    gentleMotion: gentleMotion ?? this.gentleMotion,
  );
}
