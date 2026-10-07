import 'dart:convert';
import 'dart:io';

import 'dart_format.dart';
import 'generator_error.dart';
import 'icons_reader.dart';
import 'icons_writer.dart';
import 'ramps_writer.dart';
import 'tokens_reader.dart';
import 'tokens_writer.dart';

const tokensOutputPath = 'lib/ui/core/theme/tokens.g.dart';
const rampsOutputPath = 'lib/ui/core/theme/ramps.g.dart';
const iconsOutputPath = 'lib/ui/core/widgets/icon_paths.g.dart';

const usage =
    'Usage: dart run tools/gen/bin/generate.dart [--check]\n'
    '\n'
    'Writes $tokensOutputPath, $rampsOutputPath and $iconsOutputPath\n'
    'from the identity in design/design-system/.\n'
    '\n'
    '  --check   Write nothing; exit 1 and list the files that would change.\n'
    '  -h, --help  Show this help.';

/// Exit codes from sysexits.h, plus 1 for stale files under `--check`.
abstract final class Exit {
  static const ok = 0;
  static const stale = 1;
  static const usage = 64;
  static const data = 65;
}

/// The formatted content of every output, keyed by its path from [root], in
/// a fixed order.
Future<Map<String, String>> generateAll(String root) async {
  final tokens = readTokens(_readSource(root, tokensSourcePath));
  final icons = readIcons(
    components: _readSource(root, componentsSourcePath),
    types: _readSource(root, typesSourcePath),
  );
  final unformatted = {
    tokensOutputPath: writeTokens(tokens),
    rampsOutputPath: writeRamps(tokens),
    iconsOutputPath: writeIcons(icons),
  };
  return {
    for (final MapEntry(key: path, value: source) in unformatted.entries)
      path: _requireAscii(await formatDart(source, path: '$root/$path'), path),
  };
}

/// Runs the command line in [root] and returns the exit code.
Future<int> runGenerator(
  List<String> args, {
  required String root,
  required StringSink out,
  required StringSink err,
}) async {
  if (args.length == 1 && (args.single == '-h' || args.single == '--help')) {
    out.writeln(usage);
    return Exit.ok;
  }
  final check = args.length == 1 && args.single == '--check';
  if (args.isNotEmpty && !check) {
    err
      ..writeln('Unknown arguments: ${args.join(' ')}')
      ..writeln(usage);
    return Exit.usage;
  }

  final Map<String, String> outputs;
  try {
    outputs = await generateAll(root);
  } on GeneratorError catch (e) {
    err.writeln('generate: $e');
    return Exit.data;
  }

  final changed = [
    for (final MapEntry(key: path, value: content) in outputs.entries)
      if (!_isCurrent(File('$root/$path'), content)) path,
  ];
  if (check) {
    if (changed.isEmpty) return Exit.ok;
    err.writeln('Generated files are out of date; run the generator:');
    changed.forEach(out.writeln);
    return Exit.stale;
  }
  for (final path in changed) {
    final file = File('$root/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(utf8.encode(outputs[path]!));
    out.writeln('wrote $path');
  }
  return Exit.ok;
}

String _readSource(String root, String path) {
  final file = File('$root/$path');
  if (!file.existsSync()) throw GeneratorError('Missing source $path.');
  return file.readAsStringSync();
}

bool _isCurrent(File file, String content) {
  if (!file.existsSync()) return false;
  final bytes = file.readAsBytesSync();
  final expected = utf8.encode(content);
  if (bytes.length != expected.length) return false;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != expected[i]) return false;
  }
  return true;
}

/// Generated code is ASCII only, so no text from the sources' Arabic
/// fields (theme names, `sample`, `usage`) can have reached it.
String _requireAscii(String content, String path) {
  final index = content.runes.toList().indexWhere((r) => r > 0x7E);
  if (index >= 0) {
    throw GeneratorError('Generated $path holds a non-ASCII character.');
  }
  return content;
}
