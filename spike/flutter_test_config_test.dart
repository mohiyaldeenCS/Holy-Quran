import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

// Checks that spike/flutter_test_config.dart ran: this file never loads a
// font itself. The test font gives every glyph the same advance, so two
// synthetic strings of different letters measure the same in it and
// differently in a real font.

double _width(String text, String family) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: family, fontSize: 40),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

const _narrow = 'iiiiiiii';
const _wide = 'WWWWWWWW';
const _narrowArabicScript = '\u{627}\u{627}\u{627}\u{627}';
const _wideArabicScript = '\u{645}\u{645}\u{645}\u{645}';

void main() {
  test('a family that is not loaded measures like the test font', () {
    const family = 'Synthetic family that is not loaded';
    expect(_width(_narrow, family), _width(_wide, family));
    expect(
      _width(_narrowArabicScript, family),
      _width(_wideArabicScript, family),
    );
  });

  test('the app fonts are loaded for tests under spike/', () {
    for (final family in [AppFonts.sans, AppFonts.kufi]) {
      expect(
        _width(_narrow, family),
        lessThan(_width(_wide, family)),
        reason: family,
      );
    }
    for (final family in [AppFonts.quran, AppFonts.sans, AppFonts.kufi]) {
      expect(
        _width(_narrowArabicScript, family),
        isNot(_width(_wideArabicScript, family)),
        reason: family,
      );
    }
  });
}
