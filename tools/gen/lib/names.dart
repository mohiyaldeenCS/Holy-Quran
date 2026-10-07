import 'generator_error.dart';

final _tokenName = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');

/// Dart's reserved words and built-in identifiers, which cannot name a member.
const dartReservedWords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// `surface-sunk` → `surfaceSunk`, `space-1` → `space1`.
String camelCase(String tokenName) {
  if (!_tokenName.hasMatch(tokenName)) {
    throw GeneratorError(
      'Token name "$tokenName" is not lower-case kebab-case.',
    );
  }
  final parts = tokenName.split('-');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Throws when [names] holds the same identifier twice or a reserved word.
void requireUnique(Iterable<String> names, String where) {
  final seen = <String>{};
  for (final name in names) {
    if (dartReservedWords.contains(name)) {
      throw GeneratorError(
        'An entry in $where maps to the reserved word "$name".',
      );
    }
    if (!seen.add(name)) {
      throw GeneratorError('Two entries in $where map to the name "$name".');
    }
  }
}
