import 'generator_error.dart';

/// A double as the shortest Dart literal that denotes exactly that value.
String numberLiteral(double value) {
  if (!value.isFinite) {
    throw GeneratorError('A number in the sources is not finite: $value.');
  }
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
}

final _printableAscii = RegExp(r'^[\x20-\x7E]*$');

/// A single-quoted Dart string literal. Only printable ASCII is accepted, so
/// no Arabic text can reach generated code through a string.
String stringLiteral(String value) {
  if (!_printableAscii.hasMatch(value)) {
    throw GeneratorError(
      'The string "$value" holds a character outside printable ASCII.',
    );
  }
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}
