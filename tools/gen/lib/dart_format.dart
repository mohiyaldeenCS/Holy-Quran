import 'dart:convert';
import 'dart:io';

import 'generator_error.dart';

/// [source] formatted by `dart format` as if it were the file at [path], so
/// the language version of the surrounding package applies.
Future<String> formatDart(String source, {required String path}) async {
  final Process process;
  try {
    process = await Process.start(_dartExecutable(), [
      'format',
      '--output=show',
      '--summary=none',
      '--stdin-name=$path',
    ]);
  } on ProcessException catch (e) {
    throw GeneratorError('Cannot run dart format: ${e.message}');
  }
  final stdoutText = process.stdout.transform(utf8.decoder).join();
  final stderrText = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(source);
  await process.stdin.close();
  final code = await process.exitCode;
  if (code != 0) {
    throw GeneratorError(
      'dart format failed on generated $path (exit $code):\n${await stderrText}',
    );
  }
  return stdoutText;
}

/// The running `dart` when there is one (`dart run`); otherwise the `dart`
/// on the PATH (under `flutter test` the runner is not `dart`).
String _dartExecutable() {
  final running = Platform.resolvedExecutable;
  final name = Uri.file(running).pathSegments.last;
  return name == 'dart' || name == 'dart.exe' ? running : 'dart';
}
