/// The comment every generated file starts with.
String generatedHeader(List<String> sources) =>
    '// GENERATED CODE. DO NOT EDIT BY HAND.\n'
    '// Generated from ${sources.join(', ')}\n'
    '// by `dart run tools/gen/bin/generate.dart` (see tools/gen/README.md).\n'
    '\n';
