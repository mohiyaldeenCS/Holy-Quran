import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';

import '../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'measure/text_checks.dart';

// S1 on a verified spike pack, normally of the real text, on the CI runner
// only (D-072, task spike-s1-text). Writes build/spike/s1-results.json and
// fails only on correctness problems; stretch, ink and timings are
// reported. Every message and result holds numbers, digests, U+XXXX code
// points and addresses, never text.

const _packDir = String.fromEnvironment('SPIKE_PACK_DIR');
const _resultsPath = 'build/spike/s1-results.json';

void main() {
  group(
    'S1 on the pack in SPIKE_PACK_DIR',
    skip: _packDir.isEmpty
        ? 'needs --dart-define=SPIKE_PACK_DIR=<verified spike pack '
              'directory>; the real text is fetched on the CI runner only '
              '(D-072)'
        : null,
    () {
      final measurement = TextPackMeasurement();
      var finished = false;

      test(
        'measures every surah at 360 and 412 wide, 1.0x and 2.0x',
        timeout: const Timeout(Duration(minutes: 55)),
        () async {
          PackQuranTextRepository? text;
          var last = 0;
          try {
            final opened = await openVerifiedPack(_packDir);
            text = opened.text;
            await measurement.run(
              verified: opened.verified,
              text: opened.text,
              ttf: File(amiriQuranFontPath).readAsBytesSync(),
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
          final results = measurement.results;
          _log('elapsed ${results['elapsedMs']} ms');
          _log('problems ${jsonEncode(results['problemCounts'])}');
          _log('summary ${jsonEncode(results['summary'])}');
          final tokens = results['markOnlyTokens']! as Map<String, Object?>;
          _log(
            'tokens ${tokens['tokens']}, without a letter '
            '${tokens['noLetter']}, marks only ${tokens['marksOnly']}, '
            'unclassified ${tokens['unclassifiedTokens']}',
          );
          for (final group
              in (tokens['groups']! as List<Map<String, Object?>>)) {
            _log('  ${group['codePoints']} ${group['count']}');
          }
        },
      );

      void expectNone(ProblemKind kind) {
        expect(finished, isTrue, reason: 'the measurement did not finish');
        expect(
          measurement.problems[kind]!.take(40).toList(),
          isEmpty,
          reason: '${measurement.problemCounts[kind]} problems',
        );
      }

      test(
        'the pack font maps every code point of every name, basmala and '
        'ayah',
        () => expectNone(ProblemKind.cmap),
      );
      test(
        'every surah lays out, its last line centred',
        () => expectNone(ProblemKind.layout),
      );
      test(
        'every word box centre hits its word',
        () => expectNone(ProblemKind.hitRoundTrip),
      );
      test(
        'markers and page marks are drawn in reading order',
        () => expectNone(ProblemKind.markOrder),
      );
      test(
        'an ayah sliced at its stored offsets lays out as it does whole',
        () => expectNone(ProblemKind.slicing),
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
void _log(String line) => print('s1: $line');
