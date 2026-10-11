import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/painting.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../s1/measure/frame_stats.dart' show nearestRank;
import '../s1/measure/text_checks.dart'
    show keptProblems, measurePageMark, measureScales, measureWidths;
import '../s1/render/render_checks.dart' show lineStretch, surahParagraph;
import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_paragraph.dart';
import 'gesture_target.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

// S7's measurements of tap targets and tap rules over whole surahs (D-095,
// AX-02): the same code on the synthetic pack and, in CI, on the real text.
// Every result and problem holds numbers, rule names and addresses only,
// never text.

/// Radii of the probes around each target's centre, in logical pixels.
const probeRadii = [6.0, 12.0, 18.0];

/// Probes per radius, at k x 45 degrees.
const probeDirections = 8;

/// The grid's rows, as fractions of each line band's height.
const gridRows = [0.1, 0.3, 0.5, 0.7, 0.9];

/// The grid's first column and its step, in logical pixels.
const gridFirstX = 4.0;
const gridStepX = 8.0;

/// One target in this many has its tap timed.
const timingEvery = 50;

/// How far above and below a tap its geometry reaches: BlockGestures'.
const tapReach = AppSizes.targetMin;

/// Examples kept per list; the counts are always complete.
const firstKept = 20;

/// A line-start mark box narrower than this, in logical pixels, is
/// counted apart.
const thinMarkBox = 1.0;

/// The percentiles reported, by nearest rank.
const lowRank = 0.05;
const midRank = 0.5;
const highRank = 0.95;

/// The kinds of problem that make a run fail.
enum GeometryProblem { layout, counts, wordCentre, markCentre }

/// What a target is, for sizes and probes.
enum TargetKind { word, mark, marker }

/// How a tap at a point resolves: against one geometry, a band's, or the
/// per-tap one.
typedef TapResolve = GestureTarget Function(Offset p, TapRule rule);

typedef _Target = ({TargetKind kind, GestureTarget target, Rect rect});

/// The centre of a target and [probeDirections] points at each of
/// [probeRadii] around it: 25 points.
List<Offset> probePoints(Offset centre) => [
  centre,
  for (final radius in probeRadii)
    for (var k = 0; k < probeDirections; k++)
      centre + Offset.fromDirection(k * 2 * math.pi / probeDirections, radius),
];

/// The grid points of [band]: a row at each of [gridRows] of its height,
/// from [gridFirstX] every [gridStepX] while under [width].
List<Offset> gridPoints(Rect band, double width) => [
  for (final fraction in gridRows)
    for (var x = gridFirstX; x < width; x += gridStepX)
      Offset(x, band.top + fraction * band.height),
];

/// The index of the band of [bands], which tile top to bottom, holding
/// [y]; null off every band. `TargetGeometry.bandAt` by halving.
int? bandIndexAt(List<Rect> bands, double y) {
  var low = 0;
  var high = bands.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (bands[middle].bottom <= y) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low < bands.length && bands[low].top <= y ? low : null;
}

/// The target at [p] as BlockGestures resolves a tap: the geometry of the
/// lines within [tapReach] of it, then [resolveTap].
GestureTarget resolvePerTap(SurahParagraph paragraph, Offset p, TapRule rule) =>
    resolveTap(
      p,
      TargetGeometry.of(
        paragraph,
        within: Rect.fromLTRB(
          0,
          p.dy - tapReach,
          paragraph.width,
          p.dy + tapReach,
        ),
      ),
      rule,
    );

/// Resolves points on a band against one geometry of the lines within
/// [tapReach] of that band, made once per band; a point off every band
/// goes [resolvePerTap]'s way.
final class BandResolver {
  BandResolver(this.paragraph, this.geometry);

  final SurahParagraph paragraph;

  /// The whole paragraph's geometry.
  final TargetGeometry geometry;
  final _bands = <int, TargetGeometry>{};

  GestureTarget resolve(Offset p, TapRule rule) {
    final k = bandIndexAt(geometry.lineBands, p.dy);
    if (k == null) return resolvePerTap(paragraph, p, rule);
    final band = geometry.lineBands[k];
    final near = _bands.putIfAbsent(
      k,
      () => TargetGeometry.of(
        paragraph,
        within: Rect.fromLTRB(
          0,
          band.top - tapReach,
          paragraph.width,
          band.bottom + tapReach,
        ),
      ),
    );
    return resolveTap(p, near, rule);
  }
}

/// A target as results name it: its address, `hafs:2:3 mark 1`,
/// `hafs:2:3 marker` or `margin`.
String targetName(GestureTarget target) => switch (target) {
  WordTarget(:final word) => '$word',
  WaqfMarkTarget(:final ayah, :final mark) => '$ayah mark $mark',
  MarkerTarget(:final ayah) => '$ayah marker',
  MarginTarget() => 'margin',
};

String _kindName(GestureTarget target) => switch (target) {
  WordTarget() => TargetKind.word.name,
  WaqfMarkTarget() => TargetKind.mark.name,
  MarkerTarget() => TargetKind.marker.name,
  MarginTarget() => _margin,
};

const _margin = 'margin';
const _outcomes = ['word', 'mark', 'marker', _margin];

bool _positive(Rect rect) => rect.width > 0 && rect.height > 0;

/// Positive word rects, mark boxes and markers, in that order.
List<_Target> _targetsOf(TargetGeometry g) => [
  for (final MapEntry(key: word, value: rects) in g.words.entries)
    for (final rect in rects)
      if (_positive(rect))
        (kind: TargetKind.word, target: WordTarget(word), rect: rect),
  for (final MapEntry(key: (ayah, mark), value: rect) in g.marks.entries)
    (kind: TargetKind.mark, target: WaqfMarkTarget(ayah, mark), rect: rect),
  for (final MapEntry(key: ayah, value: rect) in g.markers.entries)
    (kind: TargetKind.marker, target: MarkerTarget(ayah), rect: rect),
];

Rect _zoneOf(Rect rect) => Rect.fromCenter(
  center: rect.center,
  width: math.max(rect.width, AppSizes.targetMin),
  height: math.max(rect.height, AppSizes.targetMin),
);

double _round(double x) => (x * 100).round() / 100;

double? _rank(List<double> sorted, double fraction) =>
    sorted.isEmpty ? null : _round(nearestRank(sorted, fraction));

double _share(int count, int of) => of == 0 ? 0 : count / of;

final class _Sizes {
  final widths = <double>[];
  final heights = <double>[];
  var widthUnder = 0;
  var heightUnder = 0;
  var bothAtLeast = 0;
  double? widthMin;
  String? widthMinAt;

  void add(Rect rect, String name) {
    widths.add(rect.width);
    heights.add(rect.height);
    final narrow = rect.width < AppSizes.targetMin;
    final low = rect.height < AppSizes.targetMin;
    if (narrow) widthUnder++;
    if (low) heightUnder++;
    if (!narrow && !low) bothAtLeast++;
    if (widthMin == null || rect.width < widthMin!) {
      widthMin = rect.width;
      widthMinAt = name;
    }
  }

  Map<String, Object?> toJson() {
    final w = [...widths]..sort();
    final h = [...heights]..sort();
    return {
      'count': widths.length,
      'widthUnder48': widthUnder,
      'heightUnder48': heightUnder,
      'bothAtLeast48': bothAtLeast,
      'widthMin': widthMin == null ? null : _round(widthMin!),
      'widthMinAt': widthMinAt,
      'widthP5': _rank(w, lowRank),
      'widthP50': _rank(w, midRank),
      'widthP95': _rank(w, highRank),
      'heightP5': _rank(h, lowRank),
      'heightP50': _rank(h, midRank),
    };
  }
}

Map<String, int> _counter(List<String> keys) => {for (final k in keys) k: 0};

/// Sizes (against `target-min`), probes, the grid, zones and the centre
/// invariants of the geometries [add] is given, which may be hand-built.
final class TargetTally {
  TargetTally(this._report);

  final void Function(GeometryProblem kind, String problem) _report;
  final _sizes = {for (final kind in TargetKind.values) kind: _Sizes()};

  static const _radii = [0.0, ...probeRadii];
  final _probes = {
    for (final rule in TapRule.values)
      rule: {
        for (final kind in TargetKind.values)
          kind: [
            for (final _ in _radii) _counter(['probes', 'self', ..._outcomes]),
          ],
      },
  };
  final _grid = {
    for (final rule in TapRule.values)
      rule: _counter(['points', ..._outcomes, 'insideWord', 'notThatWord']),
  };
  final _zones = _counter([
    'count',
    'overlapping',
    'markMark',
    'markMarker',
    'markerMarker',
    'wordRects',
    'wordCentresInZones',
  ]);

  /// Adds [g], whose points [resolve] resolves; [width] bounds its grid,
  /// [where] starts its problems, and [linesStartingAtMark] are the band
  /// indices whose line starts at a stored mark.
  void add(
    TargetGeometry g, {
    required double width,
    required TapResolve resolve,
    required String where,
    Set<int> linesStartingAtMark = const {},
  }) {
    final targets = _targetsOf(g);
    for (final t in targets) {
      _sizes[t.kind]!.add(t.rect, targetName(t.target));
    }
    _probe(g, targets, resolve, where, linesStartingAtMark);
    _gridOf(g, targets, width, resolve);
    _zonesOf(targets);
  }

  void _probe(
    TargetGeometry g,
    List<_Target> targets,
    TapResolve resolve,
    String where,
    Set<int> linesStartingAtMark,
  ) {
    for (final t in targets) {
      final points = probePoints(t.rect.center);
      for (final rule in TapRule.values) {
        final byRadius = _probes[rule]![t.kind]!;
        for (final (i, p) in points.indexed) {
          final got = resolve(p, rule);
          final counts = byRadius[i == 0 ? 0 : 1 + (i - 1) ~/ probeDirections];
          counts['probes'] = counts['probes']! + 1;
          final outcome = got == t.target ? 'self' : _kindName(got);
          counts[outcome] = counts[outcome]! + 1;
          if (i > 0 || got == t.target) continue;
          if (t.kind != TargetKind.word) {
            _report(
              GeometryProblem.markCentre,
              '$where ${targetName(t.target)} ${rule.name}: gave '
              '${targetName(got)}',
            );
          } else if (rule == TapRule.exact || rule == TapRule.nearestOnLine) {
            final line = bandIndexAt(g.lineBands, p.dy);
            String yes(bool b) => b ? 'yes' : 'no';
            _report(
              GeometryProblem.wordCentre,
              '$where ${targetName(t.target)} on line $line ${rule.name}: '
              'gave ${targetName(got)}; a mark starts its line '
              '${yes(linesStartingAtMark.contains(line))}, the next '
              '${yes(line != null && linesStartingAtMark.contains(line + 1))}',
            );
          }
        }
      }
    }
  }

  void _gridOf(
    TargetGeometry g,
    List<_Target> targets,
    double width,
    TapResolve resolve,
  ) {
    final wordsOnBand = [for (final _ in g.lineBands) <_Target>[]];
    for (final t in targets) {
      if (t.kind != TargetKind.word) continue;
      final k = bandIndexAt(g.lineBands, t.rect.center.dy);
      if (k != null) wordsOnBand[k].add(t);
    }
    for (final (k, band) in g.lineBands.indexed) {
      for (final p in gridPoints(band, width)) {
        final inside = {
          for (final t in wordsOnBand[k])
            if (t.rect.contains(p)) t.target,
        };
        for (final rule in TapRule.values) {
          final got = resolve(p, rule);
          final counts = _grid[rule]!;
          counts['points'] = counts['points']! + 1;
          final kind = _kindName(got);
          counts[kind] = counts[kind]! + 1;
          if (inside.isEmpty) continue;
          counts['insideWord'] = counts['insideWord']! + 1;
          if (!inside.contains(got)) {
            counts['notThatWord'] = counts['notThatWord']! + 1;
          }
        }
      }
    }
  }

  void _zonesOf(List<_Target> targets) {
    final zones = [
      for (final t in targets)
        if (t.kind != TargetKind.word) (kind: t.kind, zone: _zoneOf(t.rect)),
    ]..sort((a, b) => a.zone.top.compareTo(b.zone.top));
    final overlapping = <int>{};
    void inc(String key) => _zones[key] = _zones[key]! + 1;
    for (var i = 0; i < zones.length; i++) {
      final a = zones[i];
      for (var j = i + 1; j < zones.length; j++) {
        final b = zones[j];
        if (b.zone.top >= a.zone.bottom) break;
        if (!a.zone.overlaps(b.zone)) continue;
        overlapping.addAll([i, j]);
        final marks = [a.kind, b.kind].where((k) => k == TargetKind.mark);
        inc(switch (marks.length) {
          2 => 'markMark',
          1 => 'markMarker',
          _ => 'markerMarker',
        });
      }
    }
    final centres = [
      for (final t in targets)
        if (t.kind == TargetKind.word) t.rect.center,
    ]..sort((a, b) => a.dy.compareTo(b.dy));
    final inZone = <int>{};
    for (final (kind: _, :zone) in zones) {
      var low = 0;
      var high = centres.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (centres[middle].dy < zone.top) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      for (
        var i = low;
        i < centres.length && centres[i].dy < zone.bottom;
        i++
      ) {
        if (zone.contains(centres[i])) inZone.add(i);
      }
    }
    _zones['count'] = _zones['count']! + zones.length;
    _zones['overlapping'] = _zones['overlapping']! + overlapping.length;
    _zones['wordRects'] = _zones['wordRects']! + centres.length;
    _zones['wordCentresInZones'] =
        _zones['wordCentresInZones']! + inZone.length;
  }

  Map<String, Object?> toJson() => {
    'sizes': {
      for (final MapEntry(:key, :value) in _sizes.entries)
        key.name: value.toJson(),
    },
    'probes': {
      for (final MapEntry(key: rule, value: kinds) in _probes.entries)
        rule.name: {
          for (final MapEntry(key: kind, value: byRadius) in kinds.entries)
            kind.name: {
              for (final (i, counts) in byRadius.indexed)
                '${_radii[i].round()}': {...counts},
            },
        },
    },
    'grid': {
      for (final MapEntry(key: rule, value: counts) in _grid.entries)
        rule.name: {
          ...counts,
          for (final outcome in _outcomes)
            '${outcome}Share': _round(
              100 * _share(counts[outcome]!, counts['points']!),
            ),
        },
    },
    'zones': {..._zones},
  };
}

final class _Listed {
  var count = 0;
  final first = <String>[];

  void add(String name) {
    count++;
    if (first.length < firstKept) first.add(name);
  }

  Map<String, Object?> toJson() => {'count': count, 'first': first};
}

/// One width and scale over every surah.
final class _ConfigRun {
  _ConfigRun(this.width, this.scale, this.report)
    : key = '${width.toInt()}/${scale}x',
      tally = TargetTally(report);

  final double width;
  final double scale;
  final String key;
  final void Function(GeometryProblem kind, String problem) report;
  final TargetTally tally;

  var lines = 0;
  var centringRetries = 0;
  var wordsPositive = 0;
  final wordsNonPositive = _Listed();
  final wordsNone = _Listed();
  var marksWithBox = 0;
  var marksWithoutBox = 0;
  var markers = 0;
  final groups = {
    for (final group in ['lineStart', 'ayahOpening', 'lineAbove', 'other'])
      group: _Listed(),
  };
  final lineStartWithBox = _Listed();
  var lineStartThin = 0;
  final tokensPerLine = <double>[];
  final times = {for (final rule in TapRule.values) rule: <double>[]};
  final timesAt = {for (final rule in TapRule.values) rule: <String>[]};
  var timed = 0;

  void measure(SpikeSurahText surah) {
    SurahParagraph paragraph;
    final scaler = TextScaler.linear(scale);
    try {
      paragraph = surahParagraph(
        surah,
        width: width,
        textScaler: scaler,
        pageMarkSize: measurePageMark,
      );
    } on StateError {
      centringRetries++;
      paragraph = surahParagraph(
        surah,
        width: width,
        textScaler: scaler,
        pageMarkSize: measurePageMark,
        centreLastLine: false,
      );
    }
    try {
      _measure(surah, paragraph);
    } finally {
      paragraph.dispose();
    }
  }

  void _measure(SpikeSurahText surah, SurahParagraph paragraph) {
    final number = surah.firstAyah.surah;
    final g = TargetGeometry.of(paragraph);
    lines += paragraph.visibleLineCount;
    QuranAddress ayahAt(int i) =>
        QuranAddress(surah.firstAyah.riwaya, number, surah.firstAyah.ayah + i);

    var positive = 0;
    var nonPositive = 0;
    var none = 0;
    var words = 0;
    for (var i = 0; i < surah.ayat.length; i++) {
      final ayah = ayahAt(i);
      for (final word in surah.words[i]) {
        words++;
        final address = QuranAddress(
          ayah.riwaya,
          ayah.surah,
          ayah.ayah,
          word.number,
        );
        final rects = g.words[address];
        if (rects == null) {
          none++;
          wordsNone.add('$address');
        } else if (rects.any(_positive)) {
          positive++;
        } else {
          nonPositive++;
          wordsNonPositive.add('$address');
        }
      }
    }
    wordsPositive += positive;
    final marks = surah.marks.fold(0, (n, m) => n + m.length);
    marksWithBox += g.marks.length;
    marksWithoutBox += g.marksWithoutBox.length;
    markers += g.markers.length;
    if (positive + nonPositive + none != words ||
        positive + nonPositive != g.words.length) {
      report(
        GeometryProblem.counts,
        '$key surah $number: words positive $positive + only non-positive '
        '$nonPositive + none $none of $words; the geometry lists '
        '${g.words.length}',
      );
    }
    if (g.marks.length + g.marksWithoutBox.length != marks) {
      report(
        GeometryProblem.counts,
        '$key surah $number: marks with a box ${g.marks.length} + without '
        '${g.marksWithoutBox.length} of $marks',
      );
    }
    if (g.markers.length != surah.ayat.length) {
      report(
        GeometryProblem.counts,
        '$key surah $number: markers ${g.markers.length} of '
        '${surah.ayat.length}',
      );
    }

    // The marks whose first code unit starts a shown line, and those lines.
    final startingMarks = <(QuranAddress, int)>{};
    final startingLines = <int>{};
    for (final (k, start) in paragraph.lineStartPositions.indexed) {
      final i = start.ayah - surah.firstAyah.ayah;
      if (i < 0 || i >= surah.marks.length) continue;
      for (final mark in surah.marks[i]) {
        if (mark.start != start.offset) continue;
        startingMarks.add((ayahAt(i), mark.number));
        startingLines.add(k);
      }
    }
    for (final (ayah, n) in g.marksWithoutBox) {
      final mark = surah.marks[ayah.ayah - surah.firstAyah.ayah].firstWhere(
        (m) => m.number == n,
      );
      final line = paragraph.markBoxOf(ayah, n)?.line;
      final group = startingMarks.contains((ayah, n))
          ? 'lineStart'
          : mark.afterWord == 0
          ? 'ayahOpening'
          : line != null && startingLines.contains(line + 1)
          ? 'lineAbove'
          : 'other';
      groups[group]!.add('$ayah mark $n');
    }
    for (final mark in startingMarks) {
      final box = g.marks[mark];
      if (box == null) continue;
      lineStartWithBox.add('${mark.$1} mark ${mark.$2}');
      if (box.width < thinMarkBox) lineStartThin++;
    }
    for (final line in lineStretch(paragraph)) {
      tokensPerLine.add((line.words + line.marks).toDouble());
    }

    tally.add(
      g,
      width: width,
      resolve: BandResolver(paragraph, g).resolve,
      where: key,
      linesStartingAtMark: startingLines,
    );

    for (final t in _targetsOf(g)) {
      if (timed++ % timingEvery != 0) continue;
      for (final rule in TapRule.values) {
        final watch = Stopwatch()..start();
        resolvePerTap(paragraph, t.rect.center, rule);
        watch.stop();
        times[rule]!.add(watch.elapsedTicks * 1e6 / watch.frequency);
        timesAt[rule]!.add(targetName(t.target));
      }
    }
  }

  /// The configuration's results, and a counts problem when its totals do
  /// not partition [expected].
  Map<String, Object?> finish(_Totals expected) {
    final words = wordsPositive + wordsNonPositive.count + wordsNone.count;
    final marks = marksWithBox + marksWithoutBox;
    final grouped = groups.values.fold(0, (n, g) => n + g.count);
    if (words != expected.words ||
        marks != expected.marks ||
        markers != expected.ayat ||
        grouped != marksWithoutBox) {
      report(
        GeometryProblem.counts,
        '$key: words $words of ${expected.words}, marks $marks of '
        '${expected.marks}, markers $markers of ${expected.ayat}, grouped '
        '$grouped of $marksWithoutBox',
      );
    }
    final tokens = [...tokensPerLine]..sort();
    return {
      'lines': lines,
      'centringRetries': centringRetries,
      'words': {
        'positive': wordsPositive,
        'onlyNonPositive': wordsNonPositive.toJson(),
        'none': wordsNone.toJson(),
      },
      'marks': {'withBox': marksWithBox, 'withoutBox': marksWithoutBox},
      'markers': markers,
      'withoutBoxGroups': {
        for (final MapEntry(:key, :value) in groups.entries)
          key: value.toJson(),
      },
      'lineStartWithBox': {
        ...lineStartWithBox.toJson(),
        'under1px': lineStartThin,
      },
      'tokensPerLine': {
        'linesButEachSurahsLast': tokens.length,
        'p5': _rank(tokens, lowRank),
        'p50': _rank(tokens, midRank),
        'p95': _rank(tokens, highRank),
      },
      ...tally.toJson(),
      'tapUs': {for (final rule in TapRule.values) rule.name: _timing(rule)},
    };
  }

  Map<String, Object?> _timing(TapRule rule) {
    final all = times[rule]!;
    final sorted = [...all]..sort();
    var at = -1;
    for (var i = 0; i < all.length; i++) {
      if (at < 0 || all[i] > all[at]) at = i;
    }
    return {
      'samples': all.length,
      'p50': _rank(sorted, midRank),
      'p95': _rank(sorted, highRank),
      'max': at < 0 ? null : _round(all[at]),
      'maxAt': at < 0 ? null : timesAt[rule]![at],
    };
  }
}

typedef _Totals = ({int surahs, int ayat, int words, int marks});

/// The results of [run] and its problems: counted in full and kept up to
/// [keptProblems] per kind.
final class GeometryMeasurement {
  final Map<String, Object?> results = {};
  final Map<GeometryProblem, List<String>> problems = {
    for (final kind in GeometryProblem.values) kind: [],
  };
  final Map<GeometryProblem, int> problemCounts = {
    for (final kind in GeometryProblem.values) kind: 0,
  };

  void _report(GeometryProblem kind, String problem) {
    problemCounts[kind] = problemCounts[kind]! + 1;
    final kept = problems[kind]!;
    if (kept.length < keptProblems) kept.add(problem);
  }

  /// Lays out each of [surahs] at every one of [widths] and [scales] and
  /// measures its targets and the tap rules on them, calling [progress]
  /// after each surah with its number. A surah that does not lay out is a
  /// layout problem, and the run goes on.
  void run(
    List<SpikeSurahText> surahs, {
    List<double> widths = measureWidths,
    List<double> scales = measureScales,
    void Function(int surah)? progress,
  }) {
    final clock = Stopwatch()..start();
    final totals = (
      surahs: surahs.length,
      ayat: surahs.fold(0, (n, s) => n + s.ayat.length),
      words: surahs.fold(
        0,
        (n, s) => n + s.words.fold(0, (m, w) => m + w.length),
      ),
      marks: surahs.fold(
        0,
        (n, s) => n + s.marks.fold(0, (m, k) => m + k.length),
      ),
    );
    results
      ..['format'] = 1
      ..['platform'] = Platform.operatingSystem
      ..['mode'] = kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'
      ..['plan'] = {
        'widths': widths,
        'scales': scales,
        'pageMark': [measurePageMark.width, measurePageMark.height],
        'markerDiameter': AppSizes.ayahMarker,
        'targetMin': AppSizes.targetMin,
        'rules': [for (final rule in TapRule.values) rule.name],
        'probeRadii': probeRadii,
        'probeDirections': probeDirections,
        'gridRows': gridRows,
        'gridFirstX': gridFirstX,
        'gridStepX': gridStepX,
        'timingEvery': timingEvery,
        'tapReach': tapReach,
        'firstKept': firstKept,
        'thinMarkBox': thinMarkBox,
        'ranks': [lowRank, midRank, highRank],
        'keptProblems': keptProblems,
      }
      ..['measured'] = {
        'surahs': totals.surahs,
        'ayat': totals.ayat,
        'words': totals.words,
        'marks': totals.marks,
      };

    final runs = [
      for (final width in widths)
        for (final scale in scales) _ConfigRun(width, scale, _report),
    ];
    for (final surah in surahs) {
      for (final run in runs) {
        try {
          run.measure(surah);
        } on Object catch (e) {
          // The spike's own errors hold no text; another's might.
          final why = e is StateError ? e.message : '${e.runtimeType}';
          _report(
            GeometryProblem.layout,
            '${run.key} surah ${surah.firstAyah.surah}: stopped: $why',
          );
        }
      }
      progress?.call(surah.firstAyah.surah);
    }
    results['configs'] = {for (final run in runs) run.key: run.finish(totals)};
    results['problemCounts'] = {
      for (final MapEntry(:key, :value) in problemCounts.entries)
        key.name: value,
    };
    results['elapsedMs'] = clock.elapsedMilliseconds;
  }
}

/// [results] of [GeometryMeasurement.run] as lines of numbers, rule names
/// and addresses, for a log.
List<String> geometrySummaryLines(Map<String, Object?> results) {
  Map<String, Object?> map(Object? value) => value! as Map<String, Object?>;
  int count(Object? value) => map(value)['count']! as int;
  String percent(int n, int of) => '${_round(100 * _share(n, of))}%';

  final lines = <String>[];
  final measured = map(results['measured']);
  if (results['pack'] case final Map<String, Object?> pack) {
    lines.add(
      'pack ${pack['id']} ${pack['version']}: surahs ${pack['surahs']}, '
      'ayat ${pack['ayat']}, words ${pack['words']}, marks '
      '${pack['marks']}; text.sqlite '
      '${(pack['textSqliteSha256']! as String).substring(0, 16)}',
    );
  }
  final problems = map(
    results['problemCounts'],
  ).entries.map((e) => '${e.key} ${e.value}').join(', ');
  lines.add(
    'measured surahs ${measured['surahs']}, ayat ${measured['ayat']}, words '
    '${measured['words']}, marks ${measured['marks']}; mode '
    '${results['mode']} on ${results['platform']}, elapsed '
    '${results['elapsedMs']} ms; problems: $problems',
  );
  for (final MapEntry(key: config, :value) in map(results['configs']).entries) {
    final c = map(value);
    final words = map(c['words']);
    final marks = map(c['marks']);
    final groups = map(c['withoutBoxGroups']);
    final starting = map(c['lineStartWithBox']);
    final tokens = map(c['tokensPerLine']);
    lines
      ..add(
        '$config: ${c['lines']} lines (${c['centringRetries']} laid out '
        'uncentred); words ${words['positive']} with a positive rect, '
        '${count(words['onlyNonPositive'])} only non-positive, '
        '${count(words['none'])} none; marks ${marks['withBox']} with a box, '
        '${marks['withoutBox']} without (${[for (final MapEntry(:key, :value) in groups.entries) '$key ${count(value)}'].join(', ')}); '
        'markers ${c['markers']}',
      )
      ..add(
        '  line-start marks with a box ${starting['count']} (under 1 px '
        '${starting['under1px']}); tokens per line p5/p50/p95 '
        '${tokens['p5']}/${tokens['p50']}/${tokens['p95']}',
      );
    for (final MapEntry(key: group, :value) in groups.entries) {
      final first = map(value)['first']! as List<Object?>;
      if (first.isNotEmpty) lines.add('    $group: ${first.join(', ')}');
    }
    for (final MapEntry(key: kind, :value) in map(c['sizes']).entries) {
      final s = map(value);
      final n = s['count']! as int;
      lines.add(
        '  $kind ${s['count']}: under 48 wide '
        '${percent(s['widthUnder48']! as int, n)}, high '
        '${percent(s['heightUnder48']! as int, n)}, both at least 48 '
        '${percent(s['bothAtLeast48']! as int, n)}; width min '
        '${s['widthMin']} (${s['widthMinAt']}), p5/p50/p95 '
        '${s['widthP5']}/${s['widthP50']}/${s['widthP95']}; height p5/p50 '
        '${s['heightP5']}/${s['heightP50']}',
      );
    }
    for (final MapEntry(key: rule, :value) in map(c['probes']).entries) {
      final grid = map(map(c['grid'])[rule]);
      final kinds = [
        for (final MapEntry(key: kind, :value) in map(value).entries)
          '$kind ${[for (final r in map(value).values) percent(map(r)['self']! as int, map(r)['probes']! as int)].join('/')}',
      ];
      lines.add(
        '  $rule: self at 0/6/12/18 px: ${kinds.join(', ')}; grid word/mark/'
        'marker/margin ${grid['wordShare']}/${grid['markShare']}/'
        '${grid['markerShare']}/${grid['marginShare']}%, inside a word but '
        'not it ${grid['notThatWord']} of ${grid['insideWord']}',
      );
    }
    final zones = map(c['zones']);
    lines.add(
      '  zones ${zones['count']}: overlapping ${zones['overlapping']} '
      '(mark-mark ${zones['markMark']}, mark-marker ${zones['markMarker']}, '
      'marker-marker ${zones['markerMarker']}); word centres in a zone '
      '${zones['wordCentresInZones']} of ${zones['wordRects']}',
    );
    final taps = [
      for (final MapEntry(key: rule, :value) in map(c['tapUs']).entries)
        _tapLine(rule, map(value)),
    ];
    lines.add('  tap us p50/p95/max: ${taps.join(', ')}');
  }
  return lines;
}

String _tapLine(String rule, Map<String, Object?> t) =>
    '$rule ${t['p50']}/${t['p95']}/${t['max']} (${t['maxAt']})';
