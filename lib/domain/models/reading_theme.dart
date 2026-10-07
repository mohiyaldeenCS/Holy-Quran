enum ReadingTheme { paper, night, sepia, contrast }

final class ThemePreference {
  const ThemePreference({
    this.theme = ReadingTheme.paper,
    this.followSystemDark = false,
  });

  final ReadingTheme theme;
  final bool followSystemDark;

  /// With [followSystemDark] on and the system dark, `paper` and `sepia` show
  /// as `night`; `night` and `contrast` never change (D-050, D-053).
  ReadingTheme resolve({required bool systemIsDark}) {
    if (!followSystemDark || !systemIsDark) return theme;
    return switch (theme) {
      ReadingTheme.paper || ReadingTheme.sepia => ReadingTheme.night,
      ReadingTheme.night || ReadingTheme.contrast => theme,
    };
  }

  ThemePreference copyWith({ReadingTheme? theme, bool? followSystemDark}) =>
      ThemePreference(
        theme: theme ?? this.theme,
        followSystemDark: followSystemDark ?? this.followSystemDark,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemePreference &&
      other.theme == theme &&
      other.followSystemDark == followSystemDark;

  @override
  int get hashCode => Object.hash(theme, followSystemDark);
}
