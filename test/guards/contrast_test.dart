import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// WCAG 2.x contrast of the colour pairs in docs/DESIGN_SYSTEM.md,
/// "Contrast", and of the pairs the M0.2 widgets draw.
typedef _Pick = Color Function(AppColors colors);

final Map<String, _Pick> _colours = {
  'ground': (c) => c.ground,
  'surface': (c) => c.surface,
  'surface-sunk': (c) => c.surfaceSunk,
  'line': (c) => c.line,
  'line-strong': (c) => c.lineStrong,
  'ink': (c) => c.ink,
  'ink-muted': (c) => c.inkMuted,
  'brand-ink': (c) => c.brandInk,
  'quran-ink': (c) => c.quranInk,
  'primary': (c) => c.primary,
  'on-primary': (c) => c.onPrimary,
  'primary-soft': (c) => c.primarySoft,
  'on-primary-soft': (c) => c.onPrimarySoft,
  'accent': (c) => c.accent,
  'ornament': (c) => c.ornament,
  'player': (c) => c.player,
  'on-player': (c) => c.onPlayer,
  'on-player-muted': (c) => c.onPlayerMuted,
  'player-accent': (c) => c.playerAccent,
  'highlight-word-line': (c) => c.highlightWordLine,
  'selection-line': (c) => c.selectionLine,
  'success': (c) => c.success,
  'warning': (c) => c.warning,
  'warning-soft': (c) => c.warningSoft,
  'error': (c) => c.error,
  'info': (c) => c.info,
  'focus': (c) => c.focus,
  'tj-ghunna': (c) => c.tjGhunna,
  'tj-idgham': (c) => c.tjIdgham,
  'tj-ikhfa': (c) => c.tjIkhfa,
  'tj-iqlab': (c) => c.tjIqlab,
  'tj-qalqala': (c) => c.tjQalqala,
  'tj-madd-tabii': (c) => c.tjMaddTabii,
  'tj-madd-wajib': (c) => c.tjMaddWajib,
  'tj-madd-lazim': (c) => c.tjMaddLazim,
  'emerald-700': (_) => Ramps.emerald700,
  'emerald-950': (_) => Ramps.emerald950,
  'gold-100': (_) => Ramps.gold100,
  'gold-400': (_) => Ramps.gold400,
  'gold-text-strong': (_) => Ramps.goldTextStrong,
  'paper-100': (_) => Ramps.paper100,
  'night-ink': (_) => AppColors.night.ink,
};

enum _Use { text, nonText }

typedef _Pair = ({String fg, String bg, _Use use});

List<_Pair> _each(List<String> fgs, List<String> bgs, _Use use) => [
  for (final fg in fgs)
    for (final bg in bgs) (fg: fg, bg: bg, use: use),
];

const _tajweed = [
  'tj-ghunna',
  'tj-idgham',
  'tj-ikhfa',
  'tj-iqlab',
  'tj-qalqala',
  'tj-madd-tabii',
  'tj-madd-wajib',
  'tj-madd-lazim',
];

final List<_Pair> _pairs = [
  ..._each(['ink'], ['ground', 'surface', 'surface-sunk'], _Use.text),
  ..._each(
    ['ink-muted', 'quran-ink', 'primary', 'accent', 'success', 'error', 'info'],
    ['ground', 'surface'],
    _Use.text,
  ),
  ..._each(['brand-ink'], ['ground'], _Use.text),
  ..._each(['on-primary'], ['primary'], _Use.text),
  ..._each(['on-primary-soft'], ['primary-soft'], _Use.text),
  ..._each(
    ['on-player', 'on-player-muted', 'player-accent'],
    ['player'],
    _Use.text,
  ),
  ..._each(['player'], ['on-player'], _Use.text),
  ..._each(['emerald-950'], ['player-accent', 'ornament'], _Use.text),
  ..._each(['gold-text-strong'], ['gold-100'], _Use.text),
  ..._each(['ink'], ['warning-soft'], _Use.text),
  ..._each(['ink-muted'], ['surface-sunk'], _Use.text),
  ..._each(_tajweed, ['ground', 'surface'], _Use.text),
  ..._each(
    [
      'warning',
      'ornament',
      'line-strong',
      'selection-line',
      'highlight-word-line',
    ],
    ['ground', 'surface'],
    _Use.nonText,
  ),
  ..._each(['focus'], ['ground', 'surface', 'surface-sunk'], _Use.nonText),
  // M0.2 widgets: the active TabBar label sits on the bar's surface.
  ..._each(['on-primary-soft'], ['surface'], _Use.text),
  // Lockup on the emerald brand surface.
  ..._each(['paper-100'], ['emerald-700'], _Use.text),
  // Switch off track (WCAG 1.4.11).
  ..._each(['line'], ['ground', 'surface'], _Use.nonText),
  // Switch knob when off, on its track.
  ..._each(['surface'], ['line'], _Use.nonText),
  // Tint IconButton: the icon on its sunk disc.
  ..._each(['primary'], ['surface-sunk'], _Use.nonText),
  // Mark graphics. The paper mark (ornament, brand-ink on ground) and the
  // emerald book (paper-100 on emerald-700) are covered above, the latter at
  // the stricter text threshold.
  ..._each(['gold-400'], ['emerald-700', 'emerald-950'], _Use.nonText),
  ..._each(['night-ink'], ['emerald-950'], _Use.nonText),
];

/// Known shortfalls with their documented ratios, keyed `theme: fg on bg`.
/// Any new shortfall, and any change to one of these, fails the test.
/// Open with the owner (O-12) unless marked otherwise.
const Map<String, double> _exceptions = {
  // The identity's stated exception: decorative.
  'paper: ornament on ground': 2.90,
  'paper: player-accent on player': 3.90,
  'sepia: player-accent on player': 3.90,
  'sepia: emerald-950 on ornament': 3.10,
  'paper: tj-ghunna on ground': 4.43,
  'sepia: tj-ghunna on ground': 3.85,
  'sepia: tj-iqlab on ground': 4.22,
  'sepia: tj-madd-wajib on ground': 3.99,
  'sepia: tj-ghunna on surface': 4.24,
  'sepia: tj-madd-wajib on surface': 4.39,
  'paper: line on ground': 1.35,
  'paper: line on surface': 1.45,
  'night: line on ground': 1.54,
  'night: line on surface': 1.36,
  'sepia: line on ground': 1.31,
  'sepia: line on surface': 1.45,
  // Switch knob when off (WCAG 1.4.11), the same colours as the off track.
  'paper: surface on line': 1.45,
  'night: surface on line': 1.36,
  'sepia: surface on line': 1.45,
};

double _threshold(String theme, _Use use) => switch (use) {
  _Use.nonText => 3,
  _Use.text => theme == 'contrast' ? 7 : 4.5,
};

typedef _Result = ({
  String theme,
  _Pair pair,
  double ratio,
  double threshold,
  bool composited,
  bool opaqueBackground,
});

_Result _measure(String theme, AppColors colors, _Pair pair) {
  final bg = _colours[pair.bg]!(colors);
  final rawFg = _colours[pair.fg]!(colors);
  final composited = rawFg.a < 1;
  final fg = composited ? Color.alphaBlend(rawFg, bg) : rawFg;
  final lighter = [fg, bg].map((c) => c.computeLuminance()).reduce(_max);
  final darker = [fg, bg].map((c) => c.computeLuminance()).reduce(_min);
  return (
    theme: theme,
    pair: pair,
    ratio: (lighter + 0.05) / (darker + 0.05),
    threshold: _threshold(theme, pair.use),
    composited: composited,
    opaqueBackground: bg.a == 1,
  );
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;

String _key(String theme, _Pair pair) => '$theme: ${pair.fg} on ${pair.bg}';

final List<_Result> _results = [
  for (final MapEntry(key: theme, value: colors) in AppColors.byId.entries)
    for (final pair in _pairs) _measure(theme, colors, pair),
];

String _report() {
  final lines = ['theme     pair                                   ratio  min'];
  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    final status = _exceptions.containsKey(key)
        ? '  known exception'
        : r.ratio < r.threshold
        ? '  BELOW'
        : '';
    lines.add(
      '${r.theme.padRight(10)}'
      '${'${r.pair.fg} on ${r.pair.bg}'.padRight(39)}'
      '${r.ratio.toStringAsFixed(2).padLeft(5)}  '
      '${r.threshold.toString().padLeft(3)}'
      '${r.composited ? '  composited' : ''}$status',
    );
  }
  return lines.join('\n');
}

void main() {
  test('report', () {
    debugPrint(_report());
  });

  test('every token named by a pair exists', () {
    for (final pair in _pairs) {
      expect(_colours, contains(pair.fg));
      expect(_colours, contains(pair.bg));
    }
  });

  test('every known exception is a tested pair', () {
    final tested = {for (final r in _results) _key(r.theme, r.pair)};
    expect(tested, containsAll(_exceptions.keys));
  });

  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    test(key, () {
      expect(r.opaqueBackground, isTrue, reason: 'nothing to composite over');
      final documented = _exceptions[key];
      if (documented == null) {
        expect(r.ratio, greaterThanOrEqualTo(r.threshold));
      } else {
        expect(r.ratio, closeTo(documented, 0.005));
        expect(r.ratio, lessThan(r.threshold));
      }
    });
  }
}
