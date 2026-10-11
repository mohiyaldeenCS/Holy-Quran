import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';

import '../s1/measure/text_checks.dart';
import 'fit_measure.dart';

// S4 on a verified spike pack, normally of the real text, on the CI runner
// only (D-072, task spike-s1-text): the Quran size from 28 down to 22 at
// which each ayah fills the 4x2 and the 2x2 widget face, or none, and the
// widget skips it (WG-03, D-094). Writes build/spike/s4-results.json and
// fails only on an unfinished measurement or a broken invariant; the
// counts are reported. Every message and result holds numbers, digests and
// addresses, never text.

const _packDir = String.fromEnvironment('SPIKE_PACK_DIR');
const _resultsPath = 'build/spike/s4-results.json';
const _shownProblems = 40;

void main() {
  group(
    'S4 on the pack in SPIKE_PACK_DIR',
    skip: _packDir.isEmpty
        ? 'needs --dart-define=SPIKE_PACK_DIR=<verified spike pack '
              'directory>; the real text is fetched on the CI runner only '
              '(D-072)'
        : null,
    () {
      final measurement = FitMeasurement();
      var finished = false;
      int? manifestAyat;

      test(
        'fits every ayah at 4x2 and 2x2 from 28 to 22',
        timeout: const Timeout(Duration(minutes: 20)),
        () async {
          PackQuranTextRepository? text;
          var last = 0;
          final clock = Stopwatch()..start();
          try {
            final opened = await openVerifiedPack(_packDir);
            text = opened.text;
            final manifest = opened.verified.manifest;
            manifestAyat = manifest.counts.ayat;
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
                if (surah % 10 == 0) _log('surah $surah fitted');
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
          fitSummaryLines(measurement.results).forEach(_log);
        },
      );

      void expectNone(FitProblem kind) {
        expect(finished, isTrue, reason: 'the measurement did not finish');
        expect(
          measurement.problems[kind]!.take(_shownProblems).toList(),
          isEmpty,
          reason: '${measurement.problemCounts[kind]} problems',
        );
      }

      test('the fit accounts for every ayah at both faces', () {
        expectNone(FitProblem.counts);
        final total = measurement.results['total']! as Map<String, Object?>;
        expect(total['ayat'], manifestAyat);
      });
      test(
        'no ayah fits the 2x2 face better than the 4x2',
        () => expectNone(FitProblem.monotone),
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
void _log(String line) => print('s4: $line');
