import 'generated_header.dart';
import 'names.dart';
import 'tokens_reader.dart';
import 'tokens_writer.dart' show tokensSourcePath;

/// The source of `ramps.g.dart`, before formatting.
String writeRamps(TokenSet tokens) {
  final names = [for (final r in tokens.ramps) camelCase(r.name)];
  requireUnique(names, 'Ramps');
  final out = StringBuffer(generatedHeader([tokensSourcePath]))
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln('/// Palette values that do not change with the theme. Only the')
    ..writeln('/// fixed brand colours of lib/ui/core/ may use them.')
    ..writeln('abstract final class Ramps {');
  for (final (i, ramp) in tokens.ramps.indexed) {
    out.writeln('static const Color ${names[i]} = ${ramp.value.toDart()};');
  }
  out.writeln('}');
  return out.toString();
}
