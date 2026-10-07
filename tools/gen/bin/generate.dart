import 'dart:io';

import '../lib/generator.dart';

Future<void> main(List<String> args) async {
  // tools/gen/bin/generate.dart → the repository root, whatever the cwd.
  final root = File.fromUri(Platform.script).parent.parent.parent.parent.path;
  exitCode = await runGenerator(args, root: root, out: stdout, err: stderr);
}
