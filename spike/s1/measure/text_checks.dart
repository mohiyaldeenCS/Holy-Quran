import 'dart:convert';
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
import 'package:holyquran/domain/models/mark_span.dart';
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

/// What [measureSurahLayout] found, with the stretch of every line for
/// percentiles over many surahs.
typedef SurahLayoutResult = ({
  Map<String, Object?> json,
  Map<ProblemKind, List<String>> problems,
  List<double> stretch,
  List<double> perGap,
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

/// (b) The tokens of every ayah as the pack stores them (D-083): words and
/// marks. Marks are grouped by the set of their code points, each with its
/// general category from unicode_categories.dart (null outside the table),
/// with their count and addresses (`<ayah> mark <number>`), most frequent
/// first. As a check independent of the writer, words with no letter and
/// marks with one by that table are counted, both expected 0; a token with
/// a code point outside the table is counted apart as unclassified, and is
/// neither, never guessed at.
Map<String, Object?> tokenReport(List<SpikeSurahText> surahs) {
  var words = 0;
  var marks = 0;
  final groups = <String, ({List<int> codePoints, List<String> at})>{};
  final unclassified = <int, int>{};
  var unclassifiedWords = 0;
  var unclassifiedMarks = 0;
  final wordsWithoutLetter = <String>[];
  final marksWithLetter = <String>[];

  /// Counts the code points of [codePoints] outside the table; whether
  /// there was one.
  bool hasUnknown(Set<int> codePoints) {
    final unknown = codePoints.where((c) => generalCategory(c) == null);
    for (final c in unknown) {
      unclassified[c] = (unclassified[c] ?? 0) + 1;
    }
    return unknown.isNotEmpty;
  }

  bool hasLetter(Set<int> codePoints) =>
      codePoints.any((c) => generalCategory(c)?.startsWith('L') ?? false);

  for (final surah in surahs) {
    for (final (i, ayah) in surah.ayat.indexed) {
      final value = ayah.verbatim;
      final address = _ayah(surah, i);
      Set<int> codePointsOf(int start, int end) =>
          value.substring(start, end).runes.toSet();
      for (final span in surah.words[i]) {
        words++;
        final codePoints = codePointsOf(span.start, span.end);
        if (hasUnknown(codePoints)) {
          unclassifiedWords++;
        } else if (isLetterless(codePoints)) {
          wordsWithoutLetter.add(
            '${QuranAddress(address.riwaya, address.surah, address.ayah, span.number)}',
          );
        }
      }
      for (final mark in surah.marks[i]) {
        marks++;
        final at = '$address mark ${mark.number}';
        final codePoints = codePointsOf(mark.start, mark.end);
        if (hasUnknown(codePoints)) {
          unclassifiedMarks++;
        } else if (hasLetter(codePoints)) {
          marksWithLetter.add(at);
        }
        final sorted = codePoints.toList()..sort();
        groups
            .putIfAbsent(
              sorted.map(codePointName).join(' '),
              () => (codePoints: sorted, at: []),
            )
            .at
            .add(at);
      }
    }
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final byCount = groups[b]!.at.length.compareTo(groups[a]!.at.length);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  final unknown = unclassified.keys.toList()..sort();
  return {
    'tokens': words + marks,
    'words': words,
    'marks': marks,
    'markGroups': [
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
    'wordsWithoutLetter': wordsWithoutLetter.length,
    'wordsWithoutLetterFirst': wordsWithoutLetter.take(20).toList(),
    'marksWithLetter': marksWithLetter.length,
    'marksWithLetterFirst': marksWithLetter.take(20).toList(),
    'unclassifiedWords': unclassifiedWords,
    'unclassifiedMarks': unclassifiedMarks,
    'unclassifiedCodePoints': {
      for (final c in unknown) codePointName(c): unclassified[c],
    },
  };
}

/// Whether a token of [codePoints] has no letter: every code point is in
/// the category table and none is a letter. An empty token has none.
bool isLetterless(Iterable<int> codePoints) => codePoints.every((c) {
  final category = generalCategory(c);
  return category != null && !category.startsWith('L');
});

/// The kind of a problem of `hitRoundTripProblems`, which reads
/// `<address>: <what>`, and the address it names.
({QuranAddress address, String kind}) _hitProblem(String problem) {
  final colon = problem.indexOf(': ');
  final address = QuranAddress.parse(problem.substring(0, colon));
  final what = problem.substring(colon + 2);
  final kind = switch (what) {
    'no box' => 'noBox',
    'empty' => 'empty',
    'outside its line band' => 'outsideBand',
    'outside the width' => 'outsideWidth',
    'centre hits null' => 'centreHitsNull',
    _ when what.startsWith('centre hits ') => 'centreHitsOther',
    _ when what.startsWith('on ') => 'onSeveralLines',
    _ => 'other',
  };
  return (address: address, kind: kind);
}

/// The stored marks that start a line of [starts], and how many lines
/// after the first start at a mark inside its ayah, so that the line before
/// ends right before it, as part 1 counted: where a pause mark is separated
/// from the word it follows.
({List<(QuranAddress, MarkSpan)> startMarks, int endsBefore}) _breaksAtMarks(
  SpikeSurahText surah,
  List<LineStart> starts,
) {
  final startMarks = <(QuranAddress, MarkSpan)>[];
  var endsBefore = 0;
  for (final (k, start) in starts.indexed) {
    final i = start.ayah - surah.firstAyah.ayah;
    for (final mark in surah.marks[i]) {
      if (mark.start != start.offset) continue;
      startMarks.add((_ayah(surah, i), mark));
      if (k > 0 && start.offset > 0) endsBefore++;
    }
  }
  return (startMarks: startMarks, endsBefore: endsBefore);
}

/// The words beside a mark of [startMarks]: the word it follows
/// (`after_word` = w) and the word after it (`after_word` = w - 1).
Set<QuranAddress> wordsBesideMarks(
  SpikeSurahText surah,
  Iterable<(QuranAddress, MarkSpan)> startMarks,
) => {
  for (final (ayah, mark) in startMarks)
    for (final word in [mark.afterWord, mark.afterWord + 1])
      if (word >= 1 &&
          word <= surah.words[ayah.ayah - surah.firstAyah.ayah].length)
        QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, word),
};

/// The hit round trip problems of words, counted by kind; those of a word
/// beside a mark that starts a line ([besideLineStartMark]) are explained
/// by that line break, and the rest fail a run.
({List<String> unexplained, Map<String, Object?> json}) splitHitProblems(
  List<String> problems,
  Set<QuranAddress> besideLineStartMark,
) {
  final kinds = <String, int>{};
  final words = <QuranAddress>{};
  final explainedKinds = <String, int>{};
  final explainedWords = <QuranAddress>{};
  final unexplainedKinds = <String, int>{};
  final unexplained = <String>[];
  for (final problem in problems) {
    final found = _hitProblem(problem);
    kinds[found.kind] = (kinds[found.kind] ?? 0) + 1;
    words.add(found.address);
    if (besideLineStartMark.contains(found.address)) {
      explainedKinds[found.kind] = (explainedKinds[found.kind] ?? 0) + 1;
      explainedWords.add(found.address);
    } else {
      unexplained.add(problem);
      unexplainedKinds[found.kind] = (unexplainedKinds[found.kind] ?? 0) + 1;
    }
  }
  int sum(Map<String, int> counts) => counts.values.fold(0, (a, b) => a + b);
  return (
    unexplained: unexplained,
    json: {
      'wordProblems': problems.length,
      'wordKinds': kinds,
      'wordsWithProblem': words.length,
      'explainedProblems': sum(explainedKinds),
      'explainedWords': explainedWords.length,
      'explainedKinds': explainedKinds,
      'unexplainedProblems': unexplained.length,
      'unexplainedKinds': unexplainedKinds,
      'unexplainedFirst': [
        for (final p in unexplained.take(20)) _hitProblemLabel(p),
      ],
    },
  );
}

String _hitProblemLabel(String problem) {
  final found = _hitProblem(problem);
  return '${found.address} ${found.kind}';
}

/// (c) [surah] laid out [width] wide at [scale]: V1 with page marks, its
/// hit round trip, mark order, stretch, line-start fingerprint and layout
/// time; the same layout uncentred for the ink at band edges; V2's plan and
/// whether its blocks break as V1 does, for a surah with a page mark; and
/// every ayah alone, sliced at its stored offsets, against itself whole.
/// Lines that start at a stored mark are counted, and the hit round trip
/// problems of a word beside such a mark are counted as explained, not
/// failed on.
Future<SurahLayoutResult> measureSurahLayout(
  SpikeSurahText surah, {
  required double width,
  required double scale,
}) async {
  final scaler = TextScaler.linear(scale);
  final where = _config(width, scale);
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
  final breaks = _breaksAtMarks(surah, v1.lineStartPositions);
  final hits = splitHitProblems(
    hitRoundTripProblems(v1),
    wordsBesideMarks(surah, breaks.startMarks),
  );
  final hit = hits.unexplained;
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
  final ink = await bandInk(plain, pixelRatio: inkPixelRatio);
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
          marks: [surah.marks[i]],
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
      'ink': {...bandInkJson(ink), 'ms': inkMs},
      'v2': v2,
      'hit': hits.json,
      'lineBreaks': {
        'startsWithMark': breaks.startMarks.length,
        'endsBeforeMark': breaks.endsBefore,
        'startMarksFirst': [
          for (final (ayah, mark) in breaks.startMarks.take(20))
            '$ayah mark ${mark.number}',
        ],
      },
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
    stretch: [for (final s in stretch) s.stretch],
    perGap: perGap,
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
        'marks': manifest.counts.marks,
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
    results['tokens'] = tokenReport(whole.surahs);

    final perSurah = <Map<String, Object?>>[];
    results['surahs'] = perSurah;
    final stretch = <String, ({List<double> lines, List<double> gaps})>{};
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
            final all = stretch.putIfAbsent(
              _config(width, scale),
              () => (lines: [], gaps: []),
            );
            all.lines.addAll(run.stretch);
            all.gaps.addAll(run.perGap);
          } on Object catch (e) {
            // The spike's own errors hold no text; another's might.
            final why = e is StateError ? e.message : '${e.runtimeType}';
            _add({
              ProblemKind.layout: [
                '${_config(width, scale)} $number: stopped: $why',
              ],
            });
          }
        }
      }
      perSurah.add({
        'surah': number,
        'ayat': surah.ayat.length,
        'words': surah.words.fold<int>(0, (n, w) => n + w.length),
        'marks': surah.marks.fold<int>(0, (n, m) => n + m.length),
        'pageMarks': surah.pageStarts.length,
        'runs': runs,
      });
      progress?.call(number);
    }
    results['summary'] = _summary(perSurah, widths, scales, stretch);
    results['problemCounts'] = {
      for (final MapEntry(:key, :value) in problemCounts.entries)
        key.name: value,
    };
    results['elapsedMs'] = _ms(clock);
  }
}

String _config(double width, double scale) => '${width.toInt()}/${scale}x';

Map<String, Object?> _summary(
  List<Map<String, Object?>> surahs,
  List<double> widths,
  List<double> scales,
  Map<String, ({List<double> lines, List<double> gaps})> stretch,
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
      final inkReach = widest('ink', 'maxReach');
      Map<String, Object?> inkOf(Map<String, Object?> run) =>
          run['ink']! as Map<String, Object?>;
      int edgesCrossed(String way) => runs.fold(
        0,
        (n, r) =>
            n +
            (inkOf(r.run)['edges']! as List<Object?>)
                .where((e) => ((e! as Map<String, Object?>)[way]! as int) > 0)
                .length,
      );
      List<int> surahsWithBreaks(String key) => [
        for (final r in runs)
          if (((r.run['lineBreaks']! as Map<String, Object?>)[key]! as int) > 0)
            r.surah,
      ];
      int surahsWith(String key) =>
          runs.where((r) => (inkOf(r.run)[key]! as int) > 0).length;
      final perGapMax = widest('stretch', 'perGapMax');
      final config = _config(width, scale);
      int total(String key) =>
          runs.fold(0, (n, r) => n + ((r.run[key] as int?) ?? 0));
      int v2Total(String key) => v2.fold(0, (n, e) => n + (e.v2[key]! as int));
      Map<String, int> kinds(String key) {
        final out = <String, int>{};
        for (final r in runs) {
          final hit = r.run['hit']! as Map<String, Object?>;
          for (final MapEntry(key: kind, :value)
              in (hit[key]! as Map<String, int>).entries) {
            out[kind] = (out[kind] ?? 0) + value;
          }
        }
        return out;
      }

      String fingerprintOverAll(bool flow) => sha256
          .convert(
            utf8.encode(
              [
                for (final r in runs)
                  switch (r.run['v2']) {
                    final Map<String, Object?> v2 when flow =>
                      v2['fingerprint'],
                    _ => r.run['fingerprint'],
                  },
              ].join(','),
            ),
          )
          .toString()
          .substring(0, 16);

      out[config] = {
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
        'inkLines': sum('ink', 'lines'),
        'inkLinesLeaving': sum('ink', 'linesLeaving'),
        'inkEdgesDown': edgesCrossed('down'),
        'inkEdgesUp': edgesCrossed('up'),
        'inkMaxReach': inkReach == null ? null : _round(inkReach.value * 1.0),
        'inkMaxReachSurah': inkReach?.surah,
        'inkSurahsLeaving': surahsWith('linesLeaving'),
        'inkSurahsAboveFirst': surahsWith('aboveFirst'),
        'inkSurahsBelowLast': surahsWith('belowLast'),
        'stretchP99': _p99(stretch[config]?.lines ?? const []),
        'stretchPerGapP99': _p99(stretch[config]?.gaps ?? const []),
        'inkMsTotal': runs.fold(
          0,
          (n, r) => n + ((r.run['ink']! as Map<String, Object?>)['ms']! as int),
        ),
        'v2PlanMsTotal': v2Total('planMs'),
        'v2BlockLayoutMsTotal': v2Total('blockLayoutMs'),
        'slicingMsTotal': total('slicingMs'),
        'hitWordProblems': sum('hit', 'wordProblems'),
        'hitWordKinds': kinds('wordKinds'),
        'hitWords': sum('hit', 'wordsWithProblem'),
        'hitExplained': sum('hit', 'explainedProblems'),
        'hitExplainedWords': sum('hit', 'explainedWords'),
        'hitUnexplained': sum('hit', 'unexplainedProblems'),
        'hitUnexplainedKinds': kinds('unexplainedKinds'),
        'hitUnexplainedFirst': [
          for (final r in runs)
            ...((r.run['hit']! as Map<String, Object?>)['unexplainedFirst']!
                as List<Object?>),
        ].take(20).toList(),
        'linesStartingWithMark': sum('lineBreaks', 'startsWithMark'),
        'linesStartingWithMarkSurahs': surahsWithBreaks('startsWithMark'),
        'linesEndingBeforeMark': sum('lineBreaks', 'endsBeforeMark'),
        'linesEndingBeforeMarkSurahs': surahsWithBreaks('endsBeforeMark'),
        'fingerprintAll': fingerprintOverAll(false),
        'v2FingerprintAll': fingerprintOverAll(true),
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

/// [results] of [TextPackMeasurement.run] as a few dozen lines of numbers,
/// digests, U+XXXX code points and counts, for a log.
List<String> summaryLines(Map<String, Object?> results) {
  Map<String, Object?> map(Object? value) => value! as Map<String, Object?>;
  String counts(Object? kinds) {
    final entries = map(kinds).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.isEmpty
        ? 'none'
        : entries.map((e) => '${e.key} ${e.value}').join(', ');
  }

  final pack = map(results['pack']);
  final cmap = map(results['cmap']);
  final tokens = map(results['tokens']);
  final missing = cmap['missing']! as List<Map<String, Object?>>;
  final groups = tokens['markGroups']! as List<Map<String, Object?>>;
  const shownGroups = 40;
  final lines = <String>[];
  void line(String text) => lines.add(text);
  line(
    'pack ${pack['id']} ${pack['version']}: surahs ${pack['surahs']}, ayat '
    '${pack['ayat']}, words ${pack['words']}, marks ${pack['marks']}; '
    'text.sqlite '
    '${(pack['textSqliteSha256']! as String).substring(0, 16)}',
  );
  line(
    'mode ${results['mode']} on ${results['platform']}, elapsed '
    '${results['elapsedMs']} ms, read ${results['readMs']} ms',
  );
  line('problems: ${counts(results['problemCounts'])}');
  final absent = missing.map((m) => '${m['codePoint']} x${m['count']}');
  line(
    'cmap: ${cmap['codePointsUsed']} code points used, the font maps '
    '${cmap['fontCodePoints']}, font is the pack font '
    '${cmap['fontIsThePacksFont']}; missing: '
    '${absent.isEmpty ? 'none' : absent.join(', ')}',
  );
  line(
    'tokens ${tokens['tokens']}: words ${tokens['words']}, marks '
    '${tokens['marks']}; by the category table, words without a letter '
    '${tokens['wordsWithoutLetter']}, marks with a letter '
    '${tokens['marksWithLetter']}; unclassified words '
    '${tokens['unclassifiedWords']}, marks ${tokens['unclassifiedMarks']} '
    '(${counts(tokens['unclassifiedCodePoints'])})',
  );
  for (final key in ['wordsWithoutLetterFirst', 'marksWithLetterFirst']) {
    final first = tokens[key]! as List<Object?>;
    if (first.isNotEmpty) line('  $key ${first.join(', ')}');
  }
  line(
    'marks by code points: ${groups.length} sets (code points / '
    'categories / count)',
  );
  for (final g in groups.take(shownGroups)) {
    line(
      '  ${(g['codePoints']! as List<Object?>).join(' ')} / '
      '${(g['categories']! as List<Object?>).join(' ')} / ${g['count']}',
    );
  }
  if (groups.length > shownGroups) {
    line('  and ${groups.length - shownGroups} more sets');
  }
  for (final MapEntry(key: config, :value) in map(results['summary']).entries) {
    final s = map(value);
    final differ = s['v2DifferFromV1']! as List<Object?>;
    line('$config: ${s['lines']} lines');
    line(
      '  hit: ${s['hitWordProblems']} problems '
      '(${counts(s['hitWordKinds'])}) on ${s['hitWords']} words; explained '
      '(beside a mark that starts a line) ${s['hitExplained']} on '
      '${s['hitExplainedWords']} words; unexplained ${s['hitUnexplained']} '
      '(${counts(s['hitUnexplainedKinds'])})',
    );
    for (final problem in s['hitUnexplainedFirst']! as List<Object?>) {
      line('    unexplained $problem');
    }
    final starting = s['linesStartingWithMarkSurahs']! as List<int>;
    final ending = s['linesEndingBeforeMarkSurahs']! as List<int>;
    line(
      '  lines starting with a mark: ${s['linesStartingWithMark']} in '
      '${starting.length} surahs: ${starting.join(' ')}',
    );
    line(
      '  lines ending right before a mark: ${s['linesEndingBeforeMark']} in '
      '${ending.length} surahs'
      '${listEquals(ending, starting) ? ' (the same surahs)' : ': ${ending.join(' ')}'}',
    );
    line(
      '  ink at ${inkPixelRatio}x px: lines ${s['inkLines']}, leaving their '
      'band ${s['inkLinesLeaving']}; edges crossed downward '
      '${s['inkEdgesDown']}, upward ${s['inkEdgesUp']}; max reach '
      '${s['inkMaxReach']} px (surah ${s['inkMaxReachSurah']}); surahs with '
      'a line leaving ${s['inkSurahsLeaving']}, first line above '
      '${s['inkSurahsAboveFirst']}, last line below '
      '${s['inkSurahsBelowLast']}',
    );
    line(
      '  stretch px: max ${s['stretchMax']} (surah ${s['stretchMaxSurah']}), '
      'p99 ${s['stretchP99']}; per gap max ${s['stretchPerGapMax']} '
      '(surah ${s['stretchPerGapMaxSurah']}), p99 ${s['stretchPerGapP99']}',
    );
    line(
      '  ms: V1 ${s['v1LayoutMsTotal']} (max ${s['v1LayoutMsMax']}, surah '
      '${s['v1LayoutMsMaxSurah']}), V2 plan ${s['v2PlanMsTotal']} (max '
      '${s['v2PlanMsMax']}), V2 blocks ${s['v2BlockLayoutMsTotal']}, ink '
      '${s['inkMsTotal']}, slicing ${s['slicingMsTotal']}',
    );
    line(
      '  V2 differs from V1 in ${differ.length} surahs'
      '${differ.isEmpty ? '' : ': ${differ.take(10).join(' ')}'}; '
      'fingerprints V1 ${s['fingerprintAll']} V2 ${s['v2FingerprintAll']}',
    );
  }
  return lines;
}
