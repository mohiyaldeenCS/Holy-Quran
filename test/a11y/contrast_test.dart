import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

// AX-03 and NF-17 (WCAG 1.4.3, 1.4.11): the colours the screens read text
// and focus in, on the grounds they sit on, in the four themes. Flutter's
// `textContrastGuideline` is not used per screen: it samples rendered pixels
// and fails on the tab bar and the 14 px greeting, whose token pairs pass
// (D-169, 2). `test/guards/contrast_test.dart` stays the authority over every
// pair of every widget and its documented exceptions; this holds the core.
double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

typedef _Pick = Color Function(AppColors colors);

void main() {
  final text = <String, _Pick>{
    'ink': (c) => c.ink,
    'ink-muted': (c) => c.inkMuted,
    'quran-ink': (c) => c.quranInk,
    'brand-ink': (c) => c.brandInk,
    'error': (c) => c.error,
  };
  final grounds = <String, _Pick>{
    'ground': (c) => c.ground,
    'surface': (c) => c.surface,
  };

  for (final MapEntry(key: theme, value: colors) in AppColors.byId.entries) {
    final minimum = theme == 'contrast' ? 7.0 : 4.5;
    for (final MapEntry(key: fg, value: pickFg) in text.entries) {
      for (final MapEntry(key: bg, value: pickBg) in grounds.entries) {
        test('$theme: $fg on $bg is at least $minimum', () {
          expect(
            _ratio(pickFg(colors), pickBg(colors)),
            greaterThanOrEqualTo(minimum),
          );
        });
      }
    }

    test('$theme: the label on a primary button is at least $minimum', () {
      expect(
        _ratio(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(minimum),
      );
    });

    for (final MapEntry(key: bg, value: pickBg) in {
      ...grounds,
      'surface-sunk': (AppColors c) => c.surfaceSunk,
    }.entries) {
      test('$theme: the focus ring on $bg is at least 3', () {
        expect(_ratio(colors.focus, pickBg(colors)), greaterThanOrEqualTo(3));
      });
    }
  }
}
