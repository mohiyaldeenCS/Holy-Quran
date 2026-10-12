import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'contrast_pairs.dart';

/// WCAG 2.x contrast of the colour pairs in docs/DESIGN_SYSTEM.md,
/// "Contrast", and of the pairs each widget draws, listed under
/// test/guards/allow/contrast/.
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

/// The pairs, their known shortfalls and their pinned ratios, one pair per
/// entry. Any new shortfall, and any change to a listed ratio, fails the test.
final _entries = ContrastEntries.load('test/guards/allow/contrast');

/// Fixed card designs keep their colours in every app theme and are judged
/// as the exported image, at 4.5:1 (D-089, 3), so they are measured once.
const _card = 'card';

double _threshold(String theme, ContrastUse use) => switch (use) {
  ContrastUse.nonText => 3,
  ContrastUse.text => theme == 'contrast' ? 7 : 4.5,
};

typedef _Result = ({
  String theme,
  ContrastPair pair,
  double ratio,
  double threshold,
  bool composited,
  bool opaqueBackground,
});

/// The background as painted, and whether it is opaque as the pair says:
/// a translucent layer over an opaque colour, or opaque on its own.
(Color, bool) _background(AppColors colors, ContrastPair pair) {
  final bg = _colours[pair.bg]!(colors);
  final over = pair.over;
  if (over == null) return (bg, bg.a == 1);
  final base = _colours[over]!(colors);
  return (Color.alphaBlend(bg, base), bg.a < 1 && base.a == 1);
}

_Result _measure(String theme, AppColors colors, ContrastPair pair) {
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

String _key(String theme, ContrastPair pair) => '$theme: ${contrastName(pair)}';

final List<_Result> _results = [
  for (final MapEntry(key: theme, value: colors) in AppColors.byId.entries)
    for (final pair in _entries.pairs) _measure(theme, colors, pair),
  for (final pair in _entries.cardPairs) _measure(_card, AppColors.paper, pair),
];

String _report() {
  final lines = ['theme     ${'pair'.padRight(49)}ratio  min'];
  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    final status = _entries.exceptions.containsKey(key)
        ? '  known exception'
        : r.ratio < r.threshold
        ? '  BELOW'
        : '';
    lines.add(
      '${r.theme.padRight(10)}'
      '${contrastName(r.pair).padRight(49)}'
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
    for (final pair in [..._entries.pairs, ..._entries.cardPairs]) {
      expect(_colours, contains(pair.fg));
      expect(_colours, contains(pair.bg));
      if (pair.over != null) expect(_colours, contains(pair.over));
    }
  });

  test('card pairs use colours that do not change with the theme', () {
    for (final pair in _entries.cardPairs) {
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
    expect(tested, containsAll(_entries.exceptions.keys));
    expect(tested, containsAll(_entries.pinned.keys));
    expect(
      _entries.exceptions.keys.toSet().intersection(
        _entries.pinned.keys.toSet(),
      ),
      isEmpty,
    );
  });

  for (final r in _results) {
    final key = _key(r.theme, r.pair);
    test(key, () {
      expect(r.opaqueBackground, isTrue, reason: 'nothing to composite over');
      final documented = _entries.exceptions[key];
      final pinned = _entries.pinned[key];
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
