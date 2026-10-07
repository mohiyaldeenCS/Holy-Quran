import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'dart_source.dart';

/// Colours come from the generated tokens, font families from `AppFonts`, and
/// Arabic text from `lib/l10n/` (CLAUDE.md, "Code style").
final _colourLiterals = RegExp(
  r'\bColor\s*\.\s*from\w*|\bColor\s*\(|\b(?:Cupertino)?Colors\s*\.|'
  r'\b0[xX][0-9A-Fa-f]{8}',
);

/// Every Arabic script block: Arabic, Supplement, Extended-B and -A, and
/// Presentation Forms-A and -B.
final _arabic = RegExp(
  '[\u0600-\u06FF\u0750-\u077F\u0870-\u089F\u08A0-\u08FF'
  '\uFB50-\uFDFF\uFE70-\uFEFF]',
);
const _fontFamilies = {AppFonts.quran, AppFonts.kufi, AppFonts.sans};

bool _scanned(String path) =>
    !path.endsWith('.g.dart') &&
    !RegExp(r'^lib/l10n/app_localizations[^/]*\.dart$').hasMatch(path);

/// Broken rules, as `path:line: what`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (_scanned(path)) ..._violationsIn(path, ScannedSource(source)),
];

Iterable<String> _violationsIn(String path, ScannedSource source) sync* {
  for (final match in _colourLiterals.allMatches(source.code)) {
    yield '$path:${source.lineOf(match.start)}: '
        '${match[0]!.replaceAll(RegExp(r'\s'), '')}';
  }
  for (final literal in source.strings) {
    if (_fontFamilies.contains(literal.value)) {
      yield '$path:${literal.line}: font family ${literal.value}';
    }
    if (!path.startsWith('lib/l10n/') && _arabic.hasMatch(literal.value)) {
      yield '$path:${literal.line}: Arabic text';
    }
  }
}

void main() {
  test('lib/ has no literal colour, font family or Arabic string', () {
    final sources = dartSources('lib');
    expect(sources, isNotEmpty);
    expect(_violations(sources), isEmpty);
  });

  group('the checker', () {
    const file = 'lib/ui/core/widgets/w.dart';
    final arabicLetter = String.fromCharCode(0x0628);

    test('flags every way of writing a colour', () {
      expect(
        _violations({
          file: '''
const a = Color(0xFF112233);
final b = Color.from(alpha: 1, red: 0, green: 0, blue: 0);
final c = Color.fromARGB(255, 0, 0, 0);
final d = Color.fromRGBO(0, 0, 0, 1);
final e = Colors.transparent;
final f = CupertinoColors.white;
const g = 0x80FFFFFF;
final h = Color .fromARGB(255, 0, 0, 0);
''',
        }),
        [
          '$file:1: Color(',
          '$file:1: 0xFF112233',
          '$file:2: Color.from',
          '$file:3: Color.fromARGB',
          '$file:4: Color.fromRGBO',
          '$file:5: Colors.',
          '$file:6: CupertinoColors.',
          '$file:7: 0x80FFFFFF',
          '$file:8: Color.fromARGB',
        ],
      );
    });

    test('flags a colour inside an interpolation', () {
      expect(_violations({file: r"final s = 'x ${Colors.red} y';"}), [
        '$file:1: Colors.',
      ]);
    });

    test('ignores colours in comments and strings, and token names', () {
      expect(
        _violations({
          file: '''
// Color(0xFF112233)
/* Colors.red /* nested Color.from */ still a comment */
/// Uses [Colors.white].
final s = 'Color(0xFF112233)';
final t = r"Colors.red";
final u = """
Color.fromARGB(255, 0, 0, 0)
""";
final v = AppColors.paper.ink;
final w = Color.lerp(a, b, 0.5);
final Color x = theme.primary;
const y = 0xFF;
''',
        }),
        isEmpty,
      );
    });

    test('flags a font family written as a string', () {
      expect(
        _violations({
          file:
              "const a = TextStyle(fontFamily: '${AppFonts.quran}');\n"
              'const b = "${AppFonts.kufi}";\n'
              "const c = r'${AppFonts.sans}';\n"
              'const d = AppFonts.sans;\n'
              "const e = 'Amiri';\n",
        }),
        [
          '$file:1: font family ${AppFonts.quran}',
          '$file:2: font family ${AppFonts.kufi}',
          '$file:3: font family ${AppFonts.sans}',
        ],
      );
    });

    test('flags Arabic in a string outside lib/l10n/', () {
      expect(
        _violations({
          file:
              "final a = 'x$arabicLetter';\n"
              '// $arabicLetter in a comment\n'
              "final b = '\\u0628';\n"
              "final c = '\\u{628}';\n"
              "final d = 'plain';\n",
          'lib/l10n/strings.dart': "final a = '$arabicLetter';\n",
        }),
        [
          '$file:1: Arabic text',
          '$file:3: Arabic text',
          '$file:4: Arabic text',
        ],
      );
    });

    test('flags every Arabic script block', () {
      const firstAndLast = [
        (0x0600, 0x06FF),
        (0x0750, 0x077F),
        (0x0870, 0x089F),
        (0x08A0, 0x08FF),
        (0xFB50, 0xFDFF),
        (0xFE70, 0xFEFF),
      ];
      final presentationForm = String.fromCharCode(0xFEFB);
      expect(
        _violations({
          file:
              "final a = '$presentationForm';\n"
              "final b = '\\uFDF2';\n"
              "final c = '${String.fromCharCode(0x0700)}';\n",
        }),
        ['$file:1: Arabic text', '$file:2: Arabic text'],
      );
      for (final (first, last) in firstAndLast) {
        for (final code in [first, last]) {
          final letter = String.fromCharCode(code);
          expect(
            _violations({file: "final a = '$letter';"}),
            ['$file:1: Arabic text'],
            reason: code.toRadixString(16),
          );
        }
        for (final code in [first - 1, last + 1]) {
          if (firstAndLast.any((r) => code >= r.$1 && code <= r.$2)) continue;
          expect(
            _violations({file: "final a = '${String.fromCharCode(code)}';"}),
            isEmpty,
            reason: code.toRadixString(16),
          );
        }
      }
    });

    test('skips generated files and the generated localizations', () {
      final source = "const a = Color(0xFF112233); const b = '$arabicLetter';";
      expect(
        _violations({
          'lib/ui/core/theme/tokens.g.dart': source,
          'lib/l10n/app_localizations.dart': source,
          'lib/l10n/app_localizations_ar.dart': source,
        }),
        isEmpty,
      );
    });
  });
}
