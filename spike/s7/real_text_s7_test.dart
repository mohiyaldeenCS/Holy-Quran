import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';

import '../s1/measure/text_checks.dart';
import 'geometry_measure.dart';

// S7 on a verified spike pack, normally of the real text, on the CI runner
// only (D-072, task spike-s1-text): target sizes against 48 px and how each
// tap rule resolves taps on them (D-095, AX-02). Writes
// build/spike/s7-results.json and fails only on an unfinished measurement
// or a broken invariant; sizes, shares and timings are reported. Every
// message and result holds numbers, digests and addresses, never text.

const _packDir = String.fromEnvironment('SPIKE_PACK_DIR');
const _resultsPath = 'build/spike/s7-results.json';
const _shownProblems = 40;

void main() {
  group(
    'S7 on the pack in SPIKE_PACK_DIR',
    skip: _packDir.isEmpty
        ? 'needs --dart-define=SPIKE_PACK_DIR=<verified spike pack '
              'directory>; the real text is fetched on the CI runner only '
              '(D-072)'
        : null,
    () {
      final measurement = GeometryMeasurement();
      var finished = false;
      PackCounts? counts;

      test(
        'measures targets and tap rules at 360 and 412 wide, 1.0x and 2.0x',
        timeout: const Timeout(Duration(minutes: 45)),
        () async {
          PackQuranTextRepository? text;
          var last = 0;
          final clock = Stopwatch()..start();
          try {
            final opened = await openVerifiedPack(_packDir);
            text = opened.text;
            final manifest = opened.verified.manifest;
            counts = manifest.counts;
            measurement.results['pack'] = {
              'id': manifest.id,
              'version': manifest.version,
              'textSqliteSha256': manifest.files.single.sha256,
              'surahs': manifest.counts.surahs,
              'ayat': manifest.counts.ayat,
              'words': manifest.counts.words,
              'marks': manifest.counts.marks,
            };
            final whole = await readWholePack(opened.text);
            measurement.results['readMs'] = clock.elapsedMilliseconds;
            measurement.run(
              whole.surahs,
              progress: (surah) {
                last = surah;
                if (surah % 10 == 0) _log('surah $surah measured');
              },
            );
            finished = true;
          } on StateError {
            rethrow;
          } on Object catch (e, stack) {
            // The spike's errors hold no text; another's might, so keep only
            // its type.
            Error.throwWithStackTrace(
              StateError('stopped after surah $last: ${e.runtimeType}'),
              stack,
            );
          } finally {
            text?.close();
            _write(measurement.results);
          }
          geometrySummaryLines(measurement.results).forEach(_log);
        },
      );

      void expectNone(GeometryProblem kind) {
        expect(finished, isTrue, reason: 'the measurement did not finish');
        expect(
          measurement.problems[kind]!.take(_shownProblems).toList(),
          isEmpty,
          reason: '${measurement.problemCounts[kind]} problems',
        );
      }

      test('every surah lays out', () => expectNone(GeometryProblem.layout));
      test('targets account for every ayah, word and mark', () {
        expectNone(GeometryProblem.counts);
        final measured =
            measurement.results['measured']! as Map<String, Object?>;
        expect(measured, {
          'surahs': counts!.surahs,
          'ayat': counts!.ayat,
          'words': counts!.words,
          'marks': counts!.marks,
        });
      });
      test(
        'every word rect centre resolves to its word',
        () => expectNone(GeometryProblem.wordCentre),
      );
      test(
        'every mark and marker centre resolves to itself',
        () => expectNone(GeometryProblem.markCentre),
      );
    },
  );
}

void _write(Map<String, Object?> results) {
  final file = File(_resultsPath)..parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
  _log('wrote $_resultsPath');
}

// ignore: avoid_print
void _log(String line) => print('s7: $line');
