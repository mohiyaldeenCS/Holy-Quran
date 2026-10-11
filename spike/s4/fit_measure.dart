import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;

import '../s1/measure/text_checks.dart' show keptProblems;
import '../s1/render/spike_surah_text.dart';
import 'ayah_widget_face.dart';
import 'widget_fit.dart';
import 'widget_publisher.dart' show faceSizeOf;
import 'widget_slots.dart';

// S4's fit counts (WG-03, D-094): at which Quran size from 28 down to 22
// every ayah fills the ayah box of the 4x2 and the 2x2 face, or that it
// fits neither and the widget skips it. Results hold numbers and addresses
// only, never text.

/// The sizes [fitQuranSize] tries by default, largest first: the keys of
/// the counts.
const fitFrom = 28.0;
const fitTo = 22.0;

/// The kinds of problem that make a run fail.
enum FitProblem { counts, monotone }

const _none = 'none';
const _medium = 'medium';
const _small = 'small';
const _pairs = ['both', 'mediumOnly', 'smallOnly', 'neither'];

List<String> get _sizeKeys => [
  for (var size = fitFrom; size >= fitTo; size--) '${size.toInt()}',
  _none,
];

String _keyOf(double? size) => size == null ? _none : '${size.toInt()}';

String _pairOf(double? medium, double? small) => switch ((medium, small)) {
  (_?, _?) => 'both',
  (_?, null) => 'mediumOnly',
  (null, _?) => 'smallOnly',
  (null, null) => 'neither',
};

final class _Counts {
  final faces = {
    for (final face in [_medium, _small])
      face: {for (final key in _sizeKeys) key: 0},
  };
  final pairs = {for (final pair in _pairs) pair: 0};
  var ayat = 0;

  void add(double? medium, double? small) {
    ayat++;
    faces[_medium]![_keyOf(medium)] = faces[_medium]![_keyOf(medium)]! + 1;
    faces[_small]![_keyOf(small)] = faces[_small]![_keyOf(small)]! + 1;
    pairs[_pairOf(medium, small)] = pairs[_pairOf(medium, small)]! + 1;
  }

  Map<String, Object?> toJson() => {
    'ayat': ayat,
    for (final MapEntry(:key, :value) in faces.entries) key: {...value},
    ...pairs,
  };
}

/// The results of [run] and its problems: counted in full and kept up to
/// [keptProblems] per kind.
final class FitMeasurement {
  final Map<String, Object?> results = {};
  final Map<FitProblem, List<String>> problems = {
    for (final kind in FitProblem.values) kind: [],
  };
  final Map<FitProblem, int> problemCounts = {
    for (final kind in FitProblem.values) kind: 0,
  };

  /// Fits every ayah of [surahs] at both faces, calling [progress] after
  /// each surah with its number.
  void run(List<SpikeSurahText> surahs, {void Function(int surah)? progress}) {
    final clock = Stopwatch()..start();
    final boxes = {
      for (final face in WidgetFaceSize.values)
        face: AyahWidgetFace.ayahBoxOf(faceSizeOf(face)),
    };
    results
      ..['format'] = 1
      ..['platform'] = Platform.operatingSystem
      ..['mode'] = kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug'
      ..['plan'] = {
        'from': fitFrom,
        'to': fitTo,
        for (final face in WidgetFaceSize.values)
          face.name: {
            'face': [faceSizeOf(face).width, faceSizeOf(face).height],
            'ayahBox': [boxes[face]!.width, boxes[face]!.height],
          },
        'keptProblems': keptProblems,
      };
    final total = _Counts();
    final perSurah = <Map<String, Object?>>[];
    for (final surah in surahs) {
      final counts = _Counts();
      final fits = <List<double?>>[];
      for (final ayah in surah.ayat) {
        final medium = fitQuranSize(ayah, boxes[WidgetFaceSize.medium]!);
        final small = fitQuranSize(ayah, boxes[WidgetFaceSize.small]!);
        counts.add(medium, small);
        total.add(medium, small);
        fits.add([medium, small]);
      }
      perSurah.add({
        'surah': surah.firstAyah.surah,
        'firstAyah': surah.firstAyah.ayah,
        ...counts.toJson(),
        'fits': fits,
      });
      progress?.call(surah.firstAyah.surah);
    }
    results
      ..['total'] = total.toJson()
      ..['surahs'] = perSurah;
    for (final MapEntry(key: kind, value: found) in fitProblems(
      results,
    ).entries) {
      problemCounts[kind] = problemCounts[kind]! + found.length;
      problems[kind]!.addAll(found.take(keptProblems));
    }
    results['problemCounts'] = {
      for (final MapEntry(:key, :value) in problemCounts.entries)
        key.name: value,
    };
    results['elapsedMs'] = clock.elapsedMilliseconds;
  }
}

/// The problems of [results], as [FitMeasurement.run] writes them or read
/// back from JSON: counts that do not account for every ayah, per face and
/// per pair, in the total and in each surah, or surahs that do not add up
/// to the total; and an ayah that fits the 2x2 face but not the 4x2, or at
/// a larger size.
Map<FitProblem, List<String>> fitProblems(Map<String, Object?> results) {
  Map<String, Object?> map(Object? value) => value! as Map<String, Object?>;
  int sum(Iterable<Object?> values) =>
      values.fold(0, (n, v) => n + (v! as num).toInt());
  final counts = <String>[];
  final monotone = <String>[];

  void check(String where, Map<String, Object?> c, int ayat) {
    for (final face in [_medium, _small]) {
      final found = sum(map(c[face]).values);
      if (found != ayat) counts.add('$where $face: $found of $ayat');
    }
    final pairs = sum([for (final pair in _pairs) c[pair]]);
    if (pairs != ayat) counts.add('$where pairs: $pairs of $ayat');
  }

  final total = map(results['total']);
  final surahs = [for (final s in results['surahs']! as List<Object?>) map(s)];
  final ayat = sum([for (final s in surahs) s['ayat']]);
  if (total['ayat'] != ayat) {
    counts.add('total: ${total['ayat']} ayat, the surahs $ayat');
  }
  check('total', total, (total['ayat']! as num).toInt());
  for (final s in surahs) {
    final fits = s['fits']! as List<Object?>;
    final where = 'surah ${s['surah']}';
    check(where, s, fits.length);
    if (s['ayat'] != fits.length) {
      counts.add('$where: ${s['ayat']} ayat, ${fits.length} fits');
    }
    for (final (i, fit) in fits.indexed) {
      final [medium, small] = [
        for (final size in fit! as List<Object?>) size as num?,
      ];
      if (small != null && (medium == null || small > medium)) {
        monotone.add(
          '$where:${(s['firstAyah']! as num).toInt() + i} 4x2 $medium, '
          '2x2 $small',
        );
      }
    }
  }
  return {FitProblem.counts: counts, FitProblem.monotone: monotone};
}

/// [results] of [FitMeasurement.run] as lines of numbers, for a log.
List<String> fitSummaryLines(Map<String, Object?> results) {
  Map<String, Object?> map(Object? value) => value! as Map<String, Object?>;
  final total = map(results['total']);
  String face(String name) =>
      map(total[name]).entries.map((e) => '${e.key} ${e.value}').join(', ');
  final problems = map(
    results['problemCounts'],
  ).entries.map((e) => '${e.key} ${e.value}').join(', ');
  final surahs = results['surahs']! as List<Object?>;
  final skipping = [
    for (final s in surahs)
      if (map(s)['neither'] case final int n when n > 0)
        '${map(s)['surah']}: $n',
  ];
  final lines = <String>[];
  if (results['pack'] case final Map<String, Object?> pack) {
    lines.add(
      'pack ${pack['id']} ${pack['version']}: ayat ${pack['ayat']}; '
      'text.sqlite '
      '${(pack['textSqliteSha256']! as String).substring(0, 16)}',
    );
  }
  return lines
    ..add(
      'fitted ${total['ayat']} ayat of ${surahs.length} surahs; mode '
      '${results['mode']} on ${results['platform']}, elapsed '
      '${results['elapsedMs']} ms; problems: $problems',
    )
    ..add('4x2 by size: ${face(_medium)}')
    ..add('2x2 by size: ${face(_small)}')
    ..add(
      'both ${total['both']}, 4x2 only ${total['mediumOnly']}, 2x2 only '
      '${total['smallOnly']}, neither ${total['neither']}',
    )
    ..add(
      'ayat fitting neither face, by surah: '
      '${skipping.isEmpty ? 'none' : skipping.join(', ')}',
    );
}
