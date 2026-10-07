import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// WCAG 2.x contrast of the colour pairs in docs/DESIGN_SYSTEM.md,
/// "Contrast", and of the pairs the M0.2 and M0.5 widgets draw.
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
  'paper-100@14': (_) => Ramps.paper100.withValues(alpha: 0.14),
  'paper-100@22': (_) => Ramps.paper100.withValues(alpha: 0.22),
  'night-ink': (_) => AppColors.night.ink,
  'paper-ground': (_) => AppColors.paper.ground,
  'paper-accent': (_) => AppColors.paper.accent,
  'paper-ornament': (_) => AppColors.paper.ornament,
};

enum _Use { text, nonText }

/// [over] is the opaque colour a translucent [bg] is composited onto,
/// source-over in sRGB as a browser paints it.
typedef _Pair = ({String fg, String bg, String? over, _Use use});

List<_Pair> _each(
  List<String> fgs,
  List<String> bgs,
  _Use use, {
  String? over,
}) => [
  for (final fg in fgs)
    for (final bg in bgs) (fg: fg, bg: bg, over: over, use: use),
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
  // M0.5 widgets. MiniPlayer speed chip.
  ..._each(['on-player'], ['paper-100@14'], _Use.text, over: 'player'),
  // Player-tone ProgressBar: fill against its track.
  ..._each(['player-accent'], ['paper-100@22'], _Use.nonText, over: 'player'),
  // Primary ProgressBar: fill against its track.
  ..._each(['primary'], ['line'], _Use.nonText),
  // The dot of the continue-reading badge.
  ..._each(['ornament'], ['primary-soft'], _Use.nonText),
  // Selected Tag fill.
  ..._each(['primary-soft'], ['surface', 'ground'], _Use.nonText),
];

/// Fixed card designs keep their colours in every app theme and are judged
/// as the exported image, at 4.5:1 (D-089, 3), so they are measured once.
const _card = 'card';

final List<_Pair> _cardPairs = [
  // Emerald share card: the reference line.
  ..._each(['gold-400'], ['emerald-700'], _Use.text),
  // Paper share card: the reference line, and the frames.
  ..._each(['paper-accent'], ['paper-ground'], _Use.text),
  ..._each(['paper-ornament'], ['paper-ground'], _Use.nonText),
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
  // M0.5, added to O-12 (D-089, 8): the player-tone progress fill.
  'paper: player-accent on paper-100@22 over player': 2.35,
  'sepia: player-accent on paper-100@22 over player': 2.35,
  // M0.5, O-12: the primary progress fill in the contrast theme.
  'contrast: primary on line': 1.41,
  // Decorative: the dot of the continue-reading badge.
  'paper: ornament on primary-soft': 2.54,
  // Selected Tag fill: the check mark and the weight carry the state
  // (D-089, 6).
  'paper: primary-soft on surface': 1.23,
  'paper: primary-soft on ground': 1.14,
  'night: primary-soft on surface': 1.35,
  'night: primary-soft on ground': 1.52,
  'sepia: primary-soft on surface': 1.14,
  'sepia: primary-soft on ground': 1.03,
  'contrast: primary-soft on surface': 1.42,
  'contrast: primary-soft on ground': 1.72,
  // O-12: the emerald share card's gold reference line.
  'card: gold-400 on emerald-700': 3.90,
  // Decorative: the paper share card's frames.
  'card: paper-ornament on paper-ground': 2.90,
};

/// Pairs that pass, held at their ratio so that any change shows.
const Map<String, double> _pinned = {
  'paper: on-player on paper-100@14 over player': 5.23,
  'night: on-player on paper-100@14 over player': 8.55,
  'sepia: on-player on paper-100@14 over player': 5.00,
  'contrast: on-player on paper-100@14 over player': 15.92,
  'night: player-accent on paper-100@22 over player': 4.10,
  'contrast: player-accent on paper-100@22 over player': 8.64,
  'paper: primary on line': 5.37,
  'night: primary on line': 5.89,
  'sepia: primary on line': 4.78,
  'night: ornament on primary-soft': 5.95,
  'sepia: ornament on primary-soft': 3.56,
  'contrast: ornament on primary-soft': 8.65,
  'card: paper-accent on paper-ground': 4.90,
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

/// The background as painted, and whether it is opaque as the pair says:
/// a translucent layer over an opaque colour, or opaque on its own.
(Color, bool) _background(AppColors colors, _Pair pair) {
  final bg = _colours[pair.bg]!(colors);
  final over = pair.over;
  if (over == null) return (bg, bg.a == 1);
  final base = _colours[over]!(colors);
  return (Color.alphaBlend(bg, base), bg.a < 1 && base.a == 1);
}

_Result _measure(String theme, AppColors colors, _Pair pair) {
  final (bg, opaqueBackground) = _background(colors, pair);
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
    opaqueBackground: opaqueBackground,
  );
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;

String _name(_Pair pair) =>
    '${pair.fg} on ${pair.bg}${pair.over == null ? '' : ' over ${pair.over}'}';

String _key(String theme, _Pair pair) => '$theme: ${_name(pair)}';

final List<_Result> _results = [
  for (final MapEntry(key: theme, value: colors) in AppColors.byId.entries)
    for (final pair in _pairs) _measure(theme, colors, pair),
  for (final pair in _cardPairs) _measure(_card, AppColors.paper, pair),
];

String _report() {
  final lines = ['theme     ${'pair'.padRight(49)}ratio  min'];
  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    final status = _exceptions.containsKey(key)
        ? '  known exception'
        : r.ratio < r.threshold
        ? '  BELOW'
        : '';
    lines.add(
      '${r.theme.padRight(10)}'
      '${_name(r.pair).padRight(49)}'
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
    for (final pair in [..._pairs, ..._cardPairs]) {
      expect(_colours, contains(pair.fg));
      expect(_colours, contains(pair.bg));
      if (pair.over != null) expect(_colours, contains(pair.over));
    }
  });

  test('card pairs use colours that do not change with the theme', () {
    for (final pair in _cardPairs) {
      for (final name in [pair.fg, pair.bg]) {
        final values = {
          for (final colors in AppColors.byId.values) _colours[name]!(colors),
        };
        expect(values, hasLength(1), reason: name);
      }
    }
  });

  test('every known exception and pinned ratio is a tested pair', () {
    final tested = {for (final r in _results) _key(r.theme, r.pair)};
    expect(tested, containsAll(_exceptions.keys));
    expect(tested, containsAll(_pinned.keys));
    expect(
      _exceptions.keys.toSet().intersection(_pinned.keys.toSet()),
      isEmpty,
    );
  });

  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    test(key, () {
      expect(r.opaqueBackground, isTrue, reason: 'nothing to composite over');
      final documented = _exceptions[key];
      final pinned = _pinned[key];
      if (pinned != null) expect(r.ratio, closeTo(pinned, 0.005));
      if (documented == null) {
        expect(r.ratio, greaterThanOrEqualTo(r.threshold));
      } else {
        expect(r.ratio, closeTo(documented, 0.005));
        expect(r.ratio, lessThan(r.threshold));
      }
    });
  }
}
