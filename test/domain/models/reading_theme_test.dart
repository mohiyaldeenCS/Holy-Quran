import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';

void main() {
  test('theme names equal the identity theme ids', () {
    expect(ReadingTheme.values.map((t) => t.name), [
      'paper',
      'night',
      'sepia',
      'contrast',
    ]);
  });

  group('ThemePreference', () {
    test('defaults to paper without following the system', () {
      const preference = ThemePreference();
      expect(preference.theme, ReadingTheme.paper);
      expect(preference.followSystemDark, isFalse);
    });

    test('equal values are equal and share a hash code', () {
      const a = ThemePreference(
        theme: ReadingTheme.sepia,
        followSystemDark: true,
      );
      const b = ThemePreference(
        theme: ReadingTheme.sepia,
        followSystemDark: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when either field differs', () {
      const base = ThemePreference();
      expect(base, isNot(const ThemePreference(theme: ReadingTheme.night)));
      expect(base, isNot(const ThemePreference(followSystemDark: true)));
    });

    test('copyWith replaces only the given fields', () {
      const base = ThemePreference(
        theme: ReadingTheme.contrast,
        followSystemDark: true,
      );
      expect(base.copyWith(), base);
      expect(
        base.copyWith(theme: ReadingTheme.sepia),
        const ThemePreference(
          theme: ReadingTheme.sepia,
          followSystemDark: true,
        ),
      );
      expect(
        base.copyWith(followSystemDark: false),
        const ThemePreference(theme: ReadingTheme.contrast),
      );
    });

    group('resolve (D-050, D-053)', () {
      const cases = <(ReadingTheme, bool, bool, ReadingTheme)>[
        (ReadingTheme.paper, false, false, ReadingTheme.paper),
        (ReadingTheme.paper, false, true, ReadingTheme.paper),
        (ReadingTheme.paper, true, false, ReadingTheme.paper),
        (ReadingTheme.paper, true, true, ReadingTheme.night),
        (ReadingTheme.night, false, false, ReadingTheme.night),
        (ReadingTheme.night, false, true, ReadingTheme.night),
        (ReadingTheme.night, true, false, ReadingTheme.night),
        (ReadingTheme.night, true, true, ReadingTheme.night),
        (ReadingTheme.sepia, false, false, ReadingTheme.sepia),
        (ReadingTheme.sepia, false, true, ReadingTheme.sepia),
        (ReadingTheme.sepia, true, false, ReadingTheme.sepia),
        (ReadingTheme.sepia, true, true, ReadingTheme.night),
        (ReadingTheme.contrast, false, false, ReadingTheme.contrast),
        (ReadingTheme.contrast, false, true, ReadingTheme.contrast),
        (ReadingTheme.contrast, true, false, ReadingTheme.contrast),
        (ReadingTheme.contrast, true, true, ReadingTheme.contrast),
      ];

      for (final (theme, follow, systemIsDark, expected) in cases) {
        test('${theme.name}, follow $follow, system dark $systemIsDark '
            '-> ${expected.name}', () {
          final preference = ThemePreference(
            theme: theme,
            followSystemDark: follow,
          );
          expect(preference.resolve(systemIsDark: systemIsDark), expected);
        });
      }

      test('the table covers every theme', () {
        expect(cases.map((c) => c.$1).toSet(), ReadingTheme.values.toSet());
        expect(cases, hasLength(ReadingTheme.values.length * 4));
      });
    });
  });
}
