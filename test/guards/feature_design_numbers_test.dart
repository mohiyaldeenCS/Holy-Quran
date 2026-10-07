import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

/// Feature code writes no design number: sizes, spacing, radii, durations and
/// type come from the tokens, the widgets and the metrics files of
/// `lib/ui/core/` (docs/DESIGN_SYSTEM.md, "Metrics that are not tokens").
final _number = RegExp(
  r'(?<![\w$.])(?:0[xX][0-9A-Fa-f_]+|'
  r'(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?)',
);
final _designNames = RegExp(
  r'\bfontFamily\w*|\bfontSize\w*|\bTextStyle\s*\(|\bDuration\s*\(|'
  r'\bBorderRadius\w*|\bRadius\s*\.|\bEdgeInsets\w*',
);

num _valueOf(String literal) {
  final digits = literal.replaceAll('_', '');
  return digits.toLowerCase().startsWith('0x')
      ? int.parse(digits.substring(2), radix: 16)
      : double.parse(digits);
}

/// Broken rules, as `path:line: what`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (path.startsWith('lib/ui/features/'))
      ..._violationsIn(path, ScannedSource(source)),
];

Iterable<String> _violationsIn(String path, ScannedSource source) sync* {
  final found = [
    for (final match in _number.allMatches(source.code))
      if (_valueOf(match[0]!) case final value when value != 0 && value != 1)
        match,
    ..._designNames.allMatches(source.code),
  ]..sort((a, b) => a.start.compareTo(b.start));
  for (final match in found) {
    yield '$path:${source.lineOf(match.start)}: '
        '${match[0]!.replaceAll(RegExp(r'\s'), '')}';
  }
}

void main() {
  test('lib/ui/features/ writes no design number', () {
    final sources = dartSources('lib/ui/features');
    expect(sources, isNotEmpty);
    expect(_violations(sources), isEmpty);
  });

  group('the checker', () {
    const file = 'lib/ui/features/home/views/home_screen.dart';

    test('flags numbers other than 0 and 1', () {
      expect(
        _violations({
          file: '''
final a = 2;
final b = 16.0;
final c = .5;
final d = 0x10;
final e = 1_000;
final f = 1e3;
final g = -24;
final h = [0, 1, 0.0, 1.0, 0x0, 1e0];
''',
        }),
        [
          '$file:1: 2',
          '$file:2: 16.0',
          '$file:3: .5',
          '$file:4: 0x10',
          '$file:5: 1_000',
          '$file:6: 1e3',
          '$file:7: 24',
        ],
      );
    });

    test('flags type, duration, radius and padding values', () {
      expect(
        _violations({
          file: '''
final a = TextStyle(color: c);
final b = style.copyWith(fontSize: size);
final c = style.copyWith(fontFamily: family, fontFamilyFallback: f);
const d = Duration(milliseconds: 0);
final e = BorderRadius.circular(r);
final f = Radius.circular(r);
final g = EdgeInsets.all(s);
final h = EdgeInsetsDirectional.only(start: s);
final i = BorderRadiusDirectional.zero;
''',
        }),
        [
          '$file:1: TextStyle(',
          '$file:2: fontSize',
          '$file:3: fontFamily',
          '$file:3: fontFamilyFallback',
          '$file:4: Duration(',
          '$file:5: BorderRadius',
          '$file:6: Radius.',
          '$file:7: EdgeInsets',
          '$file:8: EdgeInsetsDirectional',
          '$file:9: BorderRadiusDirectional',
        ],
      );
    });

    test('ignores comments, strings, identifiers and token names', () {
      expect(
        _violations({
          file: r'''
// Padding of 24, see EdgeInsets.
/* fontSize: 17 */
final a = AppSpacing.space4;
final b = Ramps.emerald950;
final c = record.$2;
final d = 'Duration(seconds: 3) and 42';
final e = AppTextStyles.body.height;
final f = list[0] + 1;
''',
        }),
        isEmpty,
      );
    });

    test('applies only under lib/ui/features/', () {
      expect(
        _violations({'lib/ui/core/widgets/button.dart': 'const a = 52;'}),
        isEmpty,
      );
    });
  });
}
