import 'dart:io';

/// A string literal of a scanned source: its value with escapes decoded and
/// interpolations left out, and the line it starts on.
typedef StringLiteral = ({String value, int line});

/// A Dart source with its comments and string literals blanked out of [code]
/// (kept the same length, newlines kept, so offsets and lines still match),
/// and the [strings] it holds. Code inside `${}` stays in [code].
final class ScannedSource {
  ScannedSource(String source) : this._(_Scanner(source)..scanCode());

  ScannedSource._(_Scanner scanner)
    : code = scanner.code.toString(),
      strings = scanner.strings;

  final String code;
  final List<StringLiteral> strings;

  int lineOf(int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;
}

/// Every `.dart` file under [root] whose path passes [include], keyed by its
/// path with forward slashes.
Map<String, String> dartSources(
  String root, {
  bool Function(String path)? include,
}) => {
  for (final file in Directory(
    root,
  ).listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart'))
      if (file.path.replaceAll(r'\', '/') case final path
          when include?.call(path) ?? true)
        path: file.readAsStringSync(),
};

final class _Scanner {
  _Scanner(this._source);

  final String _source;
  final code = StringBuffer();
  final strings = <StringLiteral>[];
  var _pos = 0;

  String? _at(int offset) {
    final index = _pos + offset;
    return index >= 0 && index < _source.length ? _source[index] : null;
  }

  void _keep() => code.write(_source[_pos++]);

  void _blank([int count = 1]) {
    for (var i = 0; i < count && _pos < _source.length; i++) {
      code.write(_source[_pos++] == '\n' ? '\n' : ' ');
    }
  }

  /// Copies code until the end, or until the `}` closing an interpolation.
  void scanCode({bool insideInterpolation = false}) {
    var depth = 0;
    while (_pos < _source.length) {
      final char = _source[_pos];
      final next = _at(1);
      if (char == '/' && next == '/') {
        while (_pos < _source.length && _source[_pos] != '\n') {
          _blank();
        }
      } else if (char == '/' && next == '*') {
        _blockComment();
      } else if (char == "'" || char == '"') {
        _string(raw: false);
      } else if ((char == 'r' || char == 'R') &&
          (next == "'" || next == '"') &&
          !_isIdentifierChar(_at(-1))) {
        _blank();
        _string(raw: true);
      } else if (insideInterpolation && char == '}' && depth == 0) {
        return;
      } else {
        if (char == '{') depth++;
        if (char == '}') depth--;
        _keep();
      }
    }
  }

  void _blockComment() {
    var depth = 0;
    while (_pos < _source.length) {
      if (_source[_pos] == '/' && _at(1) == '*') {
        depth++;
        _blank(2);
      } else if (_source[_pos] == '*' && _at(1) == '/') {
        depth--;
        _blank(2);
        if (depth == 0) return;
      } else {
        _blank();
      }
    }
  }

  void _string({required bool raw}) {
    final start = _pos;
    final quote = _source[_pos];
    final triple = _at(1) == quote && _at(2) == quote;
    final delimiter = triple ? quote * 3 : quote;
    _blank(delimiter.length);
    final value = StringBuffer();
    while (_pos < _source.length) {
      if (_source.startsWith(delimiter, _pos)) {
        _blank(delimiter.length);
        break;
      }
      final char = _source[_pos];
      if (!triple && char == '\n') break;
      if (!raw && char == r'\') {
        _escape(value);
      } else if (!raw && char == r'$' && _at(1) == '{') {
        _blank(2);
        scanCode(insideInterpolation: true);
        _blank();
      } else if (!raw && char == r'$') {
        _blank();
        while (_isIdentifierPart(_at(0))) {
          _blank();
        }
      } else {
        value.write(char);
        _blank();
      }
    }
    strings.add((
      value: value.toString(),
      line: '\n'.allMatches(_source.substring(0, start)).length + 1,
    ));
  }

  void _escape(StringBuffer value) {
    final kind = _at(1);
    final rest = _source.substring(_pos);
    final unicode =
        RegExp(r'^\\u\{([0-9A-Fa-f]+)\}').firstMatch(rest) ??
        RegExp(r'^\\u([0-9A-Fa-f]{4})').firstMatch(rest) ??
        RegExp(r'^\\x([0-9A-Fa-f]{2})').firstMatch(rest);
    if (unicode != null) {
      value.writeCharCode(int.parse(unicode[1]!, radix: 16));
      _blank(unicode[0]!.length);
      return;
    }
    value.write(switch (kind) {
      'n' => '\n',
      't' => '\t',
      'r' => '\r',
      _ => kind ?? '',
    });
    _blank(2);
  }

  static final _identifierPart = RegExp('[A-Za-z0-9_]');

  static bool _isIdentifierPart(String? char) =>
      char != null && _identifierPart.hasMatch(char);

  static bool _isIdentifierChar(String? char) =>
      char == r'$' || _isIdentifierPart(char);
}
