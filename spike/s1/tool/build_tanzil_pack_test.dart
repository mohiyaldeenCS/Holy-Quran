import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../text/tanzil_fixture.dart';

// Runs the tool as CI does, with `dart run`, on a synthetic fixture.

const _url =
    'https://example.invalid/x.xml?quranType=synthetic&marks=true&agree=true';

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('s1_tool'));
  tearDown(() => root.delete(recursive: true));

  Future<ProcessResult> build(List<String> arguments) => Process.run('dart', [
    'run',
    'spike/s1/tool/build_tanzil_pack.dart',
    ...arguments,
  ], stdoutEncoding: utf8);

  test('builds the pack and prints counts with marks, the options and the '
      'mark code points, in ASCII only', () async {
    final input = File('${root.path}/fixture.xml')
      ..writeAsBytesSync(
        tanzilFixtureXml([...syntheticFixtureSuras(), markFixtureSura()]),
      );
    final result = await build([
      '--input',
      input.path,
      '--out',
      '${root.path}/out',
      '--source-url',
      _url,
      '--fetched-on',
      '2026-01-01',
    ]);
    final out = result.stdout as String;
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      out.runes.where((c) => c > 0x7E || (c < 0x20 && c != 0x0A)),
      isEmpty,
    );
    final lines = const LineSplitter().convert(out);
    expect(lines, contains('counts surahs 4 ayat 11 words 43 marks 9'));
    expect(lines, contains('divisions juz 1 hizb 1 rub 1 page 2'));
    expect(lines, contains('options quranType=synthetic marks=true'));
    final sets = lines.indexOf('mark code point sets 8');
    expect(sets, isNot(-1));
    expect(lines.sublist(sets + 1, sets + 9), [
      'U+1F600 2',
      'U+064E U+0651 1',
      'U+0661 U+0662 1',
      'U+06D6 1',
      'U+06D7 1',
      'U+06D8 1',
      'U+06DA 1',
      'U+06E9 1',
    ]);
    expect(
      File(
        '${root.path}/out/spike-tanzil-uthmani/1/manifest.json',
      ).existsSync(),
      isTrue,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'prints its usage and exits 64 without an input',
    () async {
      final result = await build(['--out', '${root.path}/out']);
      expect(result.exitCode, 64);
      expect(result.stderr, contains('Usage: dart run'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
