import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/utils/result.dart';

import '../render/page_blocks_v2.dart';
import '../render/render_checks.dart';
import '../render/spike_surah_text.dart';
import '../render/surah_paragraph.dart';
import '../text/font_cmap.dart';
import 'frame_stats.dart' show nearestRank;
import 'unicode_categories.dart';

// The S1 checks on a whole text pack, the same code in CI and on the
// device. Every result and problem holds numbers, digests, U+XXXX code
// points and addresses only: never text, bytes or words.

/// Phone widths and text scales of M0.4's real-text measurements.
const measureWidths = [360.0, 412.0];
const measureScales = [1.0, 2.0];

/// Device pixels per logical pixel of the ink scan, as in the synthetic
/// render tests.
const inkPixelRatio = 2.0;

/// The page-mark size of the synthetic render tests; it fits in a marker's
/// advance at 1.0x (`docs/spikes/S1-surah-rendering.md`, finding 1).
const measurePageMark = Size(30, 20);

/// Problems kept per kind; the counts are always complete.
const keptProblems = 200;

/// The kinds of problem that make a run fail.
enum ProblemKind { cmap, layout, hitRoundTrip, markOrder, slicing }

/// The pack in [directory] verified with [LocalPackRepository] and opened
/// with [PackQuranTextRepository], as the app opens it. A failure throws a
/// [StateError] naming the failure, which holds no text.
Future<({VerifiedPack verified, PackQuranTextRepository text})>
openVerifiedPack(String directory) async {
  final verified = switch (await const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  ).verify(directory)) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('verify failed: $error'),
  };
  return switch (PackQuranTextRepository.open(verified)) {
    Ok(:final value) => (verified: verified, text: value),
    Failure(:final error) => throw StateError('open failed: $error'),
  };
}

/// Every surah of [pack], read by address.
Future<({List<SurahInfo> infos, List<SpikeSurahText> surahs})> readWholePack(
  QuranTextRepository pack,
) async {
  final infos = switch (await pack.surahs()) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('surahs failed: $error'),
  };
  return (
    infos: infos,
    surahs: [
      for (final info in infos) await readSpikeSurahText(pack, info.number),
    ],
  );
}

/// `U+XXXX`, at least four hex digits.
String codePointName(int c) =>
    'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// A check's results, for JSON, and its problems by kind.
typedef CheckResult = ({
  Map<String, Object?> json,
  Map<ProblemKind, List<String>> problems,
});

/// (a) Every code point of every surah name, basmala and ayah is mapped by
/// the font [ttf], which must be the font the pack names: there is no
/// fallback font (`docs/DESIGN_SYSTEM.md`).
CheckResult cmapCoverage({
  required List<SurahInfo> infos,
  required List<SpikeSurahText> surahs,
  required Uint8List ttf,
  required String packFontSha256,
}) {
  final mapped = cmapCodePoints(ttf);
  final used = <int, int>{};
  final missingAt = <int, List<String>>{};
  void count(String value, String where) {
    for (final c in value.runes) {
      used[c] = (used[c] ?? 0) + 1;
      if (!mapped.contains(c)) {
        final at = missingAt.putIfAbsent(c, () => []);
        if (at.length < 20 && (at.isEmpty || at.last != where)) at.add(where);
      }
    }
  }

  for (final info in infos) {
    count(info.name.verbatim, 'surah ${info.number} name');
  }
  for (final surah in surahs) {
    final number = surah.firstAyah.surah;
    if (surah.basmala case final basmala?) {
      count(basmala.verbatim, 'surah $number basmala');
    }
    for (final (i, ayah) in surah.ayat.indexed) {
      count(ayah.verbatim, '${_ayah(surah, i)}');
    }
  }
  final fontSha256 = sha256.convert(ttf).toString();
  final missing = missingAt.keys.toList()..sort();
  final codePoints = used.keys.toList()..sort();
  return (
    json: {
      'fontSha256': fontSha256,
      'fontIsThePacksFont': fontSha256 == packFontSha256,
      'fontCodePoints': mapped.length,
      'codePointsUsed': codePoints.length,
      'used': {for (final c in codePoints) codePointName(c): used[c]},
      'missing': [
        for (final c in missing)
          {
            'codePoint': codePointName(c),
            'count': used[c],
            'firstAt': missingAt[c],
          },
      ],
    },
    problems: {
      ProblemKind.cmap: [
        if (fontSha256 != packFontSha256)
          'the font file has SHA-256 $fontSha256, not $packFontSha256',
        for (final c in missing) _missingProblem(c, used[c]!, missingAt[c]!),
      ],
    },
  );
}

String _missingProblem(int c, int count, List<String> at) =>
    '${codePointName(c)} is not in the font: $count times, first at '
    '${at.first}';

/// (b) Word spans with no letter: only combining marks, or marks, symbols,
/// digits and punctuation. Input to D-038 and CONTENT_PACKS P3. Grouped by
/// the set of their code points; a span with a code point outside the
/// category table is counted apart as unclassified, not guessed at.
Map<String, Object?> markOnlyTokens(List<SpikeSurahText> surahs) {
  var tokens = 0;
  var empty = 0;
  final groups = <String, ({List<int> codePoints, List<String> at})>{};
  final unclassified = <int, int>{};
  var unclassifiedTokens = 0;
  for (final surah in surahs) {
    for (final (i, ayah) in surah.ayat.indexed) {
      final value = ayah.verbatim;
      final address = _ayah(surah, i);
      for (final span in surah.words[i]) {
        tokens++;
        final at = QuranAddress(
          address.riwaya,
          address.surah,
          address.ayah,
          span.number,
        );
        if (span.start == span.end) {
          empty++;
          continue;
        }
        final codePoints = value.substring(span.start, span.end).runes.toSet();
        final unknown = codePoints.where((c) => generalCategory(c) == null);
        if (unknown.isNotEmpty) {
          unclassifiedTokens++;
          for (final c in unknown) {
            unclassified[c] = (unclassified[c] ?? 0) + 1;
          }
          continue;
        }
        if (codePoints.any((c) => generalCategory(c)!.startsWith('L'))) {
          continue;
        }
        final sorted = codePoints.toList()..sort();
        final key = sorted.map(codePointName).join(' ');
        groups
            .putIfAbsent(key, () => (codePoints: sorted, at: []))
            .at
            .add('$at');
      }
    }
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final byCount = groups[b]!.at.length.compareTo(groups[a]!.at.length);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  final noLetter = groups.values.fold(0, (n, g) => n + g.at.length);
  final marksOnly = groups.values
      .where((g) => g.codePoints.every((c) => generalCategory(c)![0] == 'M'))
      .fold(0, (n, g) => n + g.at.length);
  final unknown = unclassified.keys.toList()..sort();
  return {
    'tokens': tokens,
    'empty': empty,
    'noLetter': noLetter,
    'marksOnly': marksOnly,
    'groups': [
      for (final key in keys)
        {
          'codePoints': [
            for (final c in groups[key]!.codePoints) codePointName(c),
          ],
          'categories': [
            for (final c in groups[key]!.codePoints) generalCategory(c),
          ],
          'count': groups[key]!.at.length,
          'addresses': groups[key]!.at,
        },
    ],
    'unclassifiedTokens': unclassifiedTokens,
    'unclassifiedCodePoints': {
      for (final c in unknown) codePointName(c): unclassified[c],
    },
  };
}

/// (c) [surah] laid out [width] wide at [scale]: V1 with page marks, its
/// hit round trip, mark order, stretch, line-start fingerprint and layout
/// time; the same layout uncentred for the ink at band edges; V2's plan and
/// whether its blocks break as V1 does, for a surah with a page mark; and
/// every ayah alone, sliced at its stored offsets, against itself whole.
Future<CheckResult> measureSurahLayout(
  SpikeSurahText surah, {
  required double width,
  required double scale,
}) async {
  final scaler = TextScaler.linear(scale);
  final where = '${width.toInt()}/${scale}x';
  final clock = Stopwatch()..start();

  // A centring that fails is a problem; the other checks then run on the
  // layout without it, which has the same lines.
  String? centring;
  SurahParagraph v1;
  try {
    v1 = surahParagraph(
      surah,
      width: width,
      textScaler: scaler,
      pageMarkSize: measurePageMark,
    );
  } on StateError catch (e) {
    centring = '$where ${surah.firstAyah.surah}: centring failed: ${e.message}';
    v1 = surahParagraph(
      surah,
      width: width,
      textScaler: scaler,
      pageMarkSize: measurePageMark,
      centreLastLine: false,
    );
  }
  final v1Ms = _ms(clock);
  final hit = hitRoundTripProblems(v1);
  final order = markOrderProblems(v1);
  final starts = v1.lineStartPositions;
  final stretch = lineStretch(v1);
  final lines = v1.lineCount;
  final height = v1.height;
  v1.dispose();

  clock.reset();
  final plain = surahParagraph(
    surah,
    width: width,
    textScaler: scaler,
    pageMarkSize: measurePageMark,
    centreLastLine: false,
  );
  final ink = await bandEdgeInk(plain, pixelRatio: inkPixelRatio);
  plain.dispose();
  final inkMs = _ms(clock);

  Map<String, Object?>? v2;
  String? v2Failure;
  if (surah.pageStarts.isNotEmpty) {
    try {
      v2 = _v2(surah, width, scaler, starts);
    } on StateError catch (e) {
      v2Failure = '$where ${surah.firstAyah.surah}: V2 failed: ${e.message}';
    }
  }

  clock.reset();
  final slicing = <String>[];
  var sliced = 0;
  for (var i = 0; i < surah.ayat.length; i++) {
    final words = surah.words[i];
    if (words.isEmpty) continue;
    final ayah = _ayah(surah, i);
    slicing.addAll(
      slicingProblems(
        SurahBlockContent(
          firstAyah: ayah,
          ayat: [surah.ayat[i]],
          words: [words],
        ),
        word: QuranAddress(
          ayah.riwaya,
          ayah.surah,
          ayah.ayah,
          words.first.number,
        ),
        colour: AppColors.paper.tjGhunna,
        width: width,
        textScaler: scaler,
      ),
    );
    sliced++;
  }
  final slicingMs = _ms(clock);

  final perGap = [
    for (final s in stretch)
      if (s.words > 1) s.stretch / (s.words - 1),
  ];
  return (
    json: {
      'width': width,
      'scale': scale,
      'lines': lines,
      'height': _round(height),
      'v1LayoutMs': v1Ms,
      'fingerprint': lineStartFingerprint(starts),
      'stretch': {
        'lines': stretch.length,
        'max': _max(stretch.map((s) => s.stretch)),
        'p99': _p99(stretch.map((s) => s.stretch)),
        'perGapMax': _max(perGap),
        'perGapP99': _p99(perGap),
        'oneWordLines': stretch.where((s) => s.words <= 1).length,
      },
      'ink': {
        'edges': ink.length,
        'touched': ink.where((e) => e.above > 0 || e.below > 0).length,
        'crossed': ink.where((e) => e.above > 0 && e.below > 0).length,
        'maxRowPixels': ink.fold(
          0,
          (n, e) => math.max(n, math.max(e.above, e.below)),
        ),
        'ms': inkMs,
      },
      'v2': v2,
      'slicedAyat': sliced,
      'slicingMs': slicingMs,
      'problems': {
        'centring': centring == null ? 0 : 1,
        'v2': v2Failure == null ? 0 : 1,
        'hitRoundTrip': hit.length,
        'markOrder': order.length,
        'slicing': slicing.length,
      },
    },
    problems: {
      ProblemKind.layout: [?centring, ?v2Failure],
      ProblemKind.hitRoundTrip: [for (final p in hit) '$where $p'],
      ProblemKind.markOrder: [for (final p in order) '$where $p'],
      ProblemKind.slicing: [for (final p in slicing) '$where $p'],
    },
  );
}

/// The results of [run] and its problems: counted in full and kept up to
/// [keptProblems] per kind.
final class TextPackMeasurement {
  final Map<String, Object?> results = {};
  final Map<ProblemKind, List<String>> problems = {
    for (final kind in ProblemKind.values) kind: [],
  };
  final Map<ProblemKind, int> problemCounts = {
    for (final kind in ProblemKind.values) kind: 0,
  };

  void _add(Map<ProblemKind, List<String>> found) {
    for (final MapEntry(:key, :value) in found.entries) {
      problemCounts[key] = problemCounts[key]! + value.length;
      final kept = problems[key]!;
      kept.addAll(value.take(keptProblems - kept.length));
    }
  }

  /// Runs (a), (b) and (c) over [surahNumbers] of the pack, or every
  /// surah, at [widths] and [scales], calling [progress] after each surah
  /// with its number. [ttf] is the font file the text is drawn with.
  Future<void> run({
    required VerifiedPack verified,
    required QuranTextRepository text,
    required Uint8List ttf,
    List<int>? surahNumbers,
    List<double> widths = measureWidths,
    List<double> scales = measureScales,
    void Function(int surah)? progress,
  }) async {
    final clock = Stopwatch()..start();
    final manifest = verified.manifest;
    results
      ..['format'] = 1
      ..['platform'] = Platform.operatingSystem
      ..['mode'] = kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'
      ..['pack'] = {
        'id': manifest.id,
        'version': manifest.version,
        'textSqliteSha256': manifest.files.single.sha256,
        'surahs': manifest.counts.surahs,
        'ayat': manifest.counts.ayat,
        'words': manifest.counts.words,
        'fontFamily': text.font.family,
        'fontVersion': text.font.version,
      }
      ..['plan'] = {
        'widths': widths,
        'scales': scales,
        'inkPixelRatio': inkPixelRatio,
        'pageMark': [measurePageMark.width, measurePageMark.height],
        'markerDiameter': AppSizes.ayahMarker,
      };

    final whole = await readWholePack(text);
    results['readMs'] = _ms(clock);
    final cmap = cmapCoverage(
      infos: whole.infos,
      surahs: whole.surahs,
      ttf: ttf,
      packFontSha256: text.font.sha256,
    );
    _add(cmap.problems);
    results['cmap'] = cmap.json;
    results['markOnlyTokens'] = markOnlyTokens(whole.surahs);

    final perSurah = <Map<String, Object?>>[];
    results['surahs'] = perSurah;
    for (final surah in whole.surahs) {
      final number = surah.firstAyah.surah;
      if (surahNumbers != null && !surahNumbers.contains(number)) continue;
      final runs = <Map<String, Object?>>[];
      for (final width in widths) {
        for (final scale in scales) {
          try {
            final run = await measureSurahLayout(
              surah,
              width: width,
              scale: scale,
            );
            _add(run.problems);
            runs.add(run.json);
          } on Object catch (e) {
            // The spike's own errors hold no text; another's might.
            final why = e is StateError ? e.message : '${e.runtimeType}';
            _add({
              ProblemKind.layout: [
                '${width.toInt()}/${scale}x $number: stopped: $why',
              ],
            });
          }
        }
      }
      perSurah.add({
        'surah': number,
        'ayat': surah.ayat.length,
        'words': surah.words.fold<int>(0, (n, w) => n + w.length),
        'pageMarks': surah.pageStarts.length,
        'runs': runs,
      });
      progress?.call(number);
    }
    results['summary'] = _summary(perSurah, widths, scales);
    results['problemCounts'] = {
      for (final MapEntry(:key, :value) in problemCounts.entries)
        key.name: value,
    };
    results['elapsedMs'] = _ms(clock);
  }
}

Map<String, Object?> _summary(
  List<Map<String, Object?>> surahs,
  List<double> widths,
  List<double> scales,
) {
  final out = <String, Object?>{};
  for (final width in widths) {
    for (final scale in scales) {
      final runs = [
        for (final s in surahs)
          for (final r in (s['runs']! as List<Map<String, Object?>>))
            if (r['width'] == width && r['scale'] == scale)
              (surah: s['surah']! as int, run: r),
      ];
      int sum(String group, String key) => runs.fold(
        0,
        (n, r) => n + ((r.run[group]! as Map<String, Object?>)[key]! as int),
      );
      ({int surah, num value})? widest(String group, String key) {
        ({int surah, num value})? best;
        for (final r in runs) {
          final v = (r.run[group]! as Map<String, Object?>)[key] as num?;
          if (v != null && (best == null || v > best.value)) {
            best = (surah: r.surah, value: v);
          }
        }
        return best;
      }

      final slowest = runs.isEmpty
          ? null
          : runs.reduce(
              (a, b) =>
                  (a.run['v1LayoutMs']! as int) >= (b.run['v1LayoutMs']! as int)
                  ? a
                  : b,
            );
      final v2 = [
        for (final r in runs)
          if (r.run['v2'] case final Map<String, Object?> v2)
            (surah: r.surah, v2: v2),
      ];
      final stretchMax = widest('stretch', 'max');
      final perGapMax = widest('stretch', 'perGapMax');
      out['${width.toInt()}/${scale}x'] = {
        'lines': runs.fold(0, (n, r) => n + (r.run['lines']! as int)),
        'v1LayoutMsTotal': runs.fold(
          0,
          (n, r) => n + (r.run['v1LayoutMs']! as int),
        ),
        'v1LayoutMsMax': slowest?.run['v1LayoutMs'],
        'v1LayoutMsMaxSurah': slowest?.surah,
        'v2PlanMsMax': v2.isEmpty
            ? null
            : v2.map((e) => e.v2['planMs']! as int).reduce(math.max),
        'v2DifferFromV1': [
          for (final e in v2)
            if (e.v2['sameLineStartsAsV1'] != true) e.surah,
        ],
        'stretchMax': stretchMax?.value,
        'stretchMaxSurah': stretchMax?.surah,
        'stretchPerGapMax': perGapMax?.value,
        'stretchPerGapMaxSurah': perGapMax?.surah,
        'inkEdges': sum('ink', 'edges'),
        'inkTouched': sum('ink', 'touched'),
        'inkCrossed': sum('ink', 'crossed'),
        'surahsWithInkCrossing': [
          for (final r in runs)
            if (((r.run['ink']! as Map<String, Object?>)['crossed']! as int) >
                0)
              r.surah,
        ].length,
      };
    }
  }
  return out;
}

Map<String, Object?> _v2(
  SpikeSurahText surah,
  double width,
  TextScaler scaler,
  List<LineStart> v1Starts,
) {
  final clock = Stopwatch()..start();
  final planner = SurahFlowPlanner(
    surah: surah,
    width: width,
    textScaler: scaler,
    pageMarkSize: measurePageMark,
  );
  final blocks = planner.all.length;
  final planMs = _ms(clock);
  clock.reset();
  final flow = flowLineStarts(planner);
  return {
    'blocks': blocks,
    'planMs': planMs,
    'blockLayoutMs': _ms(clock),
    'sameLineStartsAsV1': listEquals(flow, v1Starts),
    'fingerprint': lineStartFingerprint(flow),
  };
}

QuranAddress _ayah(SpikeSurahText surah, int index) => QuranAddress(
  surah.firstAyah.riwaya,
  surah.firstAyah.surah,
  surah.firstAyah.ayah + index,
);

int _ms(Stopwatch clock) => clock.elapsedMilliseconds;

double _round(double x) => (x * 100).round() / 100;

double? _max(Iterable<double> values) =>
    values.isEmpty ? null : _round(values.reduce(math.max));

double? _p99(Iterable<double> values) {
  if (values.isEmpty) return null;
  return _round(nearestRank(values.toList()..sort(), 0.99));
}
