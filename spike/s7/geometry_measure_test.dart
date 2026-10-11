import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../s1/measure/text_checks.dart' show measurePageMark;
import '../s1/render/render_checks.dart' show surahParagraph;
import '../s1/render/spike_surah_text.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'geometry_measure.dart';
import 'gesture_target.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

// S7's target and tap-rule measurements on hand-built geometries and on the
// synthetic pack's nonsense with marks (D-083). Results hold numbers, rule
// names and addresses only.

const _sublist = 80;
const _agreeEvery = 7;

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: {
    for (final MapEntry(:key, :value) in surah.pageStarts.entries)
      if (key.ayah <= ayat) key: value,
  },
);

QuranAddress _address(int ayah, [int? word]) =>
    QuranAddress('hafs', 1, ayah, word);

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

/// Whether [text] holds a code point of the Arabic blocks.
bool _hasArabic(String text) => text.runes.any(
  (c) =>
      (c >= 0x0600 && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0x08A0 && c <= 0x08FF) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF),
);

// Two bands 50 high and 100 wide. Band 0: words A (40 x 40) and B (50 x
// 40). Band 1: words C (30 x 40) and D (26 x 40), mark K (10 x 20) between
// them and marker M (20 x 26) at the left end.
final _a = _address(1, 1);
final _b = _address(1, 2);
final _c = _address(2, 1);
final _d = _address(2, 2);
final _bands = [
  const Rect.fromLTRB(0, 0, 100, 50),
  const Rect.fromLTRB(0, 50, 100, 100),
];
const _k = Rect.fromLTRB(40, 65, 50, 85);
const _m = Rect.fromLTRB(80, 62, 100, 88);
final _handBuilt = TargetGeometry(
  lineBands: _bands,
  words: {
    _a: [const Rect.fromLTRB(60, 5, 100, 45)],
    _b: [const Rect.fromLTRB(0, 5, 50, 45)],
    _c: [const Rect.fromLTRB(0, 55, 30, 95)],
    _d: [const Rect.fromLTRB(52, 55, 78, 95)],
  },
  marks: {(_address(2), 1): _k},
  markers: {_address(2): _m},
);

({TargetTally tally, List<(GeometryProblem, String)> problems}) _tallyOf(
  TargetGeometry g,
  double width,
) {
  final problems = <(GeometryProblem, String)>[];
  final tally = TargetTally((kind, problem) => problems.add((kind, problem)))
    ..add(
      g,
      width: width,
      resolve: (p, rule) => resolveTap(p, g, rule),
      where: 'hand',
    );
  return (tally: tally, problems: problems);
}

void main() {
  group('hand-built geometry', () {
    test('25 probes: the centre and 8 directions at 6, 12 and 18 px', () {
      const centre = Offset(100, 50);
      final points = probePoints(centre);
      expect(points, hasLength(25));
      expect(points.first, centre);
      for (final (r, radius) in probeRadii.indexed) {
        final ring = points.sublist(1 + 8 * r, 9 + 8 * r);
        for (final (k, p) in ring.indexed) {
          final d = p - centre;
          expect(d.distance, closeTo(radius, 1e-9));
          expect(d.direction, closeTo(_angle(k), 1e-9));
        }
      }
    });

    test('sizes against 48, probes, grid shares and zones', () {
      final (:tally, :problems) = _tallyOf(_handBuilt, 100);
      expect(problems, isEmpty);
      final json = tally.toJson();
      final sizes = _map(json['sizes']);
      expect(_map(sizes['word']), {
        'count': 4,
        'widthUnder48': 3,
        'heightUnder48': 4,
        'bothAtLeast48': 0,
        'widthMin': 26.0,
        'widthMinAt': '$_d',
        'widthP5': 26.0,
        'widthP50': 30.0,
        'widthP95': 50.0,
        'heightP5': 40.0,
        'heightP50': 40.0,
      });
      expect(_map(sizes['mark'])['widthMinAt'], 'hafs:1:2 mark 1');
      expect(_map(sizes['marker'])['widthMinAt'], 'hafs:1:2 marker');
      expect(_map(sizes['marker'])['heightP50'], 26.0);

      final probes = _map(json['probes']);
      for (final rule in TapRule.values) {
        final kinds = _map(probes[rule.name]);
        for (final (kind, targets) in [
          ('word', 4),
          ('mark', 1),
          ('marker', 1),
        ]) {
          final radii = _map(kinds[kind]);
          expect(radii.keys, ['0', '6', '12', '18']);
          for (final MapEntry(:key, :value) in radii.entries) {
            final counts = _map(value);
            final probes = key == '0' ? targets : 8 * targets;
            expect(counts['probes'], probes, reason: '$rule $kind $key');
            expect(
              [
                'self',
                'word',
                'mark',
                'marker',
                'margin',
              ].fold<int>(0, (n, k) => n + (counts[k]! as int)),
              probes,
            );
          }
          // D's centre lies in K's zone, which priorityZones puts first.
          final missed = rule == TapRule.priorityZones && kind == 'word'
              ? 1
              : 0;
          expect(
            _map(radii['0'])['self'],
            targets - missed,
            reason: '$rule $kind',
          );
        }
      }
      // Around K at 18 px, exactly: D at 0, 45 and 315 degrees, C at 180,
      // the margin at the other four.
      expect(_map(_map(_map(probes['exact'])['mark'])['18']), {
        'probes': 8,
        'self': 0,
        'word': 4,
        'mark': 0,
        'marker': 0,
        'margin': 4,
      });

      // 12 columns (4 to 92) x 5 rows x 2 bands. Band 0: 4 rows cross A
      // and B (6 + 5 columns), the row at 45 lies under both. Band 1: C 4
      // columns, D 4, K 1 (rows 65 and 75), M 2 (rows 65, 75 and 85), and
      // the row at 95 lies under all.
      final exact = _map(_map(json['grid'])['exact']);
      expect(exact['points'], 120);
      expect(exact['word'], 44 + 32);
      expect(exact['mark'], 2);
      expect(exact['marker'], 6);
      expect(exact['margin'], 36);
      expect(exact['insideWord'], 76);
      expect(exact['notThatWord'], 0);
      expect(exact['marginShare'], 30.0);
      for (final rule in TapRule.values) {
        final grid = _map(_map(json['grid'])[rule.name]);
        expect(
          [
            'word',
            'mark',
            'marker',
            'margin',
          ].fold<int>(0, (n, k) => n + (grid[k]! as int)),
          120,
        );
        expect(grid['insideWord'], 76);
      }
      // Every grid point lies on a band with targets, where nearestOnLine
      // never gives the margin.
      expect(_map(_map(json['grid'])['nearestOnLine'])['margin'], 0);

      // K's zone (21 to 69 wide) meets M's (66 to 114) and holds D's centre.
      expect(_map(json['zones']), {
        'count': 2,
        'overlapping': 2,
        'markMark': 0,
        'markMarker': 1,
        'markerMarker': 0,
        'wordRects': 4,
        'wordCentresInZones': 1,
      });
    });

    test('zones: mark-mark and marker-marker pairs, swept by top', () {
      final g = TargetGeometry(
        lineBands: [const Rect.fromLTRB(0, 0, 300, 50)],
        marks: {
          (_address(1), 1): const Rect.fromLTRB(10, 15, 20, 35),
          (_address(1), 2): const Rect.fromLTRB(30, 15, 40, 35),
          // Far below: its zone meets no other.
          (_address(3), 1): const Rect.fromLTRB(10, 415, 20, 435),
        },
        markers: {
          _address(1): const Rect.fromLTRB(200, 12, 220, 38),
          _address(2): const Rect.fromLTRB(230, 12, 250, 38),
        },
      );
      expect(_map(_tallyOf(g, 300).tally.toJson()['zones']), {
        'count': 5,
        'overlapping': 4,
        'markMark': 1,
        'markMarker': 0,
        'markerMarker': 1,
        'wordRects': 0,
        'wordCentresInZones': 0,
      });
    });

    test('wordCentre and markCentre fire on a word rect under a mark box', () {
      final g = TargetGeometry(
        lineBands: [const Rect.fromLTRB(0, 0, 300, 60)],
        words: {
          _a: [const Rect.fromLTRB(100, 10, 200, 50)],
        },
        marks: {(_address(1), 1): const Rect.fromLTRB(140, 20, 160, 40)},
      );
      final problems = _tallyOf(g, 300).problems;
      expect(problems.where((p) => p.$1 == GeometryProblem.wordCentre), [
        for (final rule in [TapRule.exact, TapRule.nearestOnLine])
          (
            GeometryProblem.wordCentre,
            'hand $_a on line 0 ${rule.name}: gave hafs:1:1 mark 1; a mark '
                'starts its line no, the next no',
          ),
      ]);
      expect(problems.where((p) => p.$1 == GeometryProblem.markCentre), [
        (
          GeometryProblem.markCentre,
          'hand hafs:1:1 mark 1 priorityZonesWithSlop: gave $_a',
        ),
      ]);
    });
  });

  group('the synthetic pack', () {
    late Directory root;
    late SpikeSurahText long;
    late SpikeSurahText sublist;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('s7_measure');
      final read = await readSyntheticSurahs(root, withMarks: true);
      long = read.long;
      sublist = _first(long, _sublist);
      read.pack.close();
    });
    tearDownAll(() => root.delete(recursive: true));

    test('the first $_sublist ayat at four configurations: no problem, '
        'counts that partition the text, and only numbers and addresses', () {
      final measurement = GeometryMeasurement()..run([sublist]);
      final results = measurement.results;
      for (final kind in GeometryProblem.values) {
        expect(
          measurement.problems[kind],
          isEmpty,
          reason: '${measurement.problemCounts[kind]} $kind',
        );
      }
      final words = sublist.words.fold(0, (n, w) => n + w.length);
      final marks = sublist.marks.fold(0, (n, m) => n + m.length);
      expect(_map(results['measured']), {
        'surahs': 1,
        'ayat': _sublist,
        'words': words,
        'marks': marks,
      });
      final configs = _map(results['configs']);
      expect(configs.keys, ['360/1.0x', '360/2.0x', '412/1.0x', '412/2.0x']);
      for (final MapEntry(key: config, :value) in configs.entries) {
        final c = _map(value);
        final w = _map(c['words']);
        final m = _map(c['marks']);
        int count(Object? listed) => _map(listed)['count']! as int;
        expect(
          (w['positive']! as int) +
              count(w['onlyNonPositive']) +
              count(w['none']),
          words,
          reason: config,
        );
        expect((m['withBox']! as int) + (m['withoutBox']! as int), marks);
        expect(c['markers'], _sublist);
        expect(
          _map(c['withoutBoxGroups']).values.fold(0, (n, g) => n + count(g)),
          m['withoutBox'],
        );
        expect(_map(_map(c['sizes'])['word'])['count'], w['positive']);
        expect(_map(_map(c['sizes'])['mark'])['count'], m['withBox']);
        for (final rule in TapRule.values) {
          expect(_map(_map(c['tapUs'])[rule.name])['samples'], isPositive);
        }
      }
      final json = jsonEncode(results);
      final summary = geometrySummaryLines(results);
      expect(_hasArabic(json), isFalse);
      expect(summary.where(_hasArabic), isEmpty);
      for (final line in summary) {
        // ignore: avoid_print
        print('s7 synthetic: $line');
      }
    });

    test('the whole long surah at 412/1.0x: 597 marks with a box, and the 23 '
        'without, by group', () {
      final measurement = GeometryMeasurement()
        ..run([long], widths: [412], scales: [1.0]);
      expect(measurement.problemCounts.values.every((n) => n == 0), isTrue);
      final c = _map(_map(measurement.results['configs'])['412/1.0x']);
      expect(_map(c['marks']), {'withBox': 597, 'withoutBox': 23});
      final groups = _map(c['withoutBoxGroups']);
      Map<String, Object?> group(String name) => _map(groups[name]);
      expect(group('lineStart')['count'], 15);
      expect(group('ayahOpening')['count'], 7);
      expect(group('lineAbove'), {
        'count': 1,
        'first': ['hafs:1:28 mark 5'],
      });
      expect(group('other')['count'], 0);
    });

    for (final (width, scale) in [(360.0, 2.0), (412.0, 1.0)]) {
      test('per-band and per-tap geometry agree at every $_agreeEvery'
          'th grid point, all rules (${width.toInt()}/${scale}x)', () {
        final paragraph = surahParagraph(
          sublist,
          width: width,
          textScaler: TextScaler.linear(scale),
          pageMarkSize: measurePageMark,
        );
        addTearDown(paragraph.dispose);
        final g = TargetGeometry.of(paragraph);
        final band = BandResolver(paragraph, g);
        var index = 0;
        var compared = 0;
        final kinds = <Type>{};
        for (final line in g.lineBands) {
          for (final p in gridPoints(line, width)) {
            if (index++ % _agreeEvery != 0) continue;
            for (final rule in TapRule.values) {
              final perTap = resolvePerTap(paragraph, p, rule);
              expect(band.resolve(p, rule), perTap, reason: '$p $rule');
              kinds.add(perTap.runtimeType);
              compared++;
            }
          }
        }
        expect(compared, greaterThan(1000));
        expect(kinds, {WordTarget, WaqfMarkTarget, MarkerTarget, MarginTarget});
      });
    }
  });
}

double _angle(int k) {
  final a = k * 2 * math.pi / 8;
  return a > math.pi ? a - 2 * math.pi : a;
}
