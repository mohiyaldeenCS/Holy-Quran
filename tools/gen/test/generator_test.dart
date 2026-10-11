import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/generator.dart';
import '../lib/icons_reader.dart';
import '../lib/tokens_writer.dart';
import 'synthetic_sources.dart';

final _repoRoot = Directory.current.path;

/// A root holding [tokens], the components and the types, as the generator
/// expects them.
Directory _sourceRoot({
  required String tokens,
  String? components,
  String? types,
}) {
  final root = Directory.systemTemp.createTempSync('gen_test_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final (path, content) in [
    (tokensSourcePath, tokens),
    (componentsSourcePath, components ?? syntheticComponents()),
    (typesSourcePath, types ?? syntheticTypes()),
  ]) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
  return root;
}

Future<(int, String, String)> _run(List<String> args, String root) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runGenerator(args, root: root, out: out, err: err);
  return (code, out.toString(), err.toString());
}

void main() {
  test('two runs over the real sources give identical bytes', () async {
    final first = await generateAll(_repoRoot);
    final second = await generateAll(_repoRoot);
    expect(first.keys, [tokensOutputPath, rampsOutputPath, iconsOutputPath]);
    expect(second, first);
  });

  test('the committed outputs are current', () async {
    final (code, out, err) = await _run(['--check'], _repoRoot);
    expect(code, Exit.ok, reason: '$out$err');
  });

  test('no output holds an Arabic character or the sample text', () async {
    final outputs = await generateAll(_repoRoot);
    final arabic = RegExp(
      '[\u0600-\u06FF\u0750-\u077F\u0870-\u089F\u08A0-\u08FF'
      '\uFB50-\uFDFF\uFE70-\uFEFF]',
    );
    for (final MapEntry(key: path, value: content) in outputs.entries) {
      expect(arabic.hasMatch(content), isFalse, reason: path);
      expect(content, isNot(contains('sample')), reason: path);
    }
  });

  test('every output starts with the generated-file header', () async {
    final outputs = await generateAll(_repoRoot);
    for (final content in outputs.values) {
      expect(content, startsWith('// GENERATED CODE. DO NOT EDIT BY HAND.\n'));
      expect(content, contains('dart run tools/gen/bin/generate.dart'));
    }
  });

  group('--check', () {
    test('fails and lists the files while outputs are missing', () async {
      final root = _sourceRoot(tokens: encode(syntheticTokens()));
      final (code, out, _) = await _run(['--check'], root.path);
      expect(code, Exit.stale);
      expect(out.trim().split('\n'), [
        tokensOutputPath,
        rampsOutputPath,
        iconsOutputPath,
      ]);
      expect(File('${root.path}/$tokensOutputPath').existsSync(), isFalse);
    });

    test('passes after a run and fails again when an output changes', () async {
      final root = _sourceRoot(tokens: encode(syntheticTokens()));
      expect((await _run([], root.path)).$1, Exit.ok);
      expect((await _run(['--check'], root.path)).$1, Exit.ok);

      final ramps = File('${root.path}/$rampsOutputPath');
      ramps.writeAsStringSync('${ramps.readAsStringSync()}\n');
      final (code, out, _) = await _run(['--check'], root.path);
      expect(code, Exit.stale);
      expect(out.trim(), rampsOutputPath);
    });

    test('fails when a source changes after the run', () async {
      final root = _sourceRoot(tokens: encode(syntheticTokens()));
      await _run([], root.path);
      final json = syntheticTokens();
      // ground aliases base-100, so both colour files change.
      (colorTokens(json).first! as Map<String, Object?>)['value'] = '#EEEEEE';
      File('${root.path}/$tokensSourcePath').writeAsStringSync(encode(json));
      final (code, out, _) = await _run(['--check'], root.path);
      expect(code, Exit.stale);
      expect(out.trim().split('\n'), [tokensOutputPath, rampsOutputPath]);
    });
  });

  test('a run over unchanged outputs writes nothing', () async {
    final root = _sourceRoot(tokens: encode(syntheticTokens()));
    await _run([], root.path);
    final (code, out, _) = await _run([], root.path);
    expect(code, Exit.ok);
    expect(out, isEmpty);
  });

  test('an unknown argument is a usage error', () async {
    final (code, out, err) = await _run(['--force'], _repoRoot);
    expect(code, Exit.usage);
    expect(out, isEmpty);
    expect(err, contains('Usage:'));
  });

  test('--help prints the usage to stdout', () async {
    final (code, out, err) = await _run(['--help'], _repoRoot);
    expect(code, Exit.ok);
    expect(out, contains('--check'));
    expect(err, isEmpty);
  });

  test('a bad source is a data error and writes nothing', () async {
    final json = syntheticTokens();
    colorTokens(json).add({'name': 'stray', 'value': '{missing}'});
    final root = _sourceRoot(tokens: encode(json));
    final (code, _, err) = await _run([], root.path);
    expect(code, Exit.data);
    expect(err, contains('{missing}'));
    expect(Directory('${root.path}/lib').existsSync(), isFalse);
  });

  test('a missing source is a data error', () async {
    final root = _sourceRoot(tokens: encode(syntheticTokens()));
    File('${root.path}/$typesSourcePath').deleteSync();
    final (code, _, err) = await _run(['--check'], root.path);
    expect(code, Exit.data);
    expect(err, contains(typesSourcePath));
  });
}
