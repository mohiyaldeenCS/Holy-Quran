/// The one fold of search (D-037, D-118). A typed query passes through it
/// before it is compared with the pack's search forms, which are compared as
/// stored. A tafsir passage is never folded: [findAll] skips, while
/// comparing, the units the fold drops, and copies nothing.
///
/// Each rule is a row of [_dropped]; each further row is a decision taken
/// against the golden query set (B0.10).
abstract final class QueryFold {
  /// «بلا تشكيل»: the eight harakat, fathatan (U+064B) to sukun (U+0652).
  static const _dropped = {
    0x064B,
    0x064C,
    0x064D,
    0x064E,
    0x064F,
    0x0650,
    0x0651,
    0x0652,
  };

  /// White space: the units of `\s` in a Dart regular expression.
  static const _spaces = {
    0x0009,
    0x000A,
    0x000B,
    0x000C,
    0x000D,
    0x0020,
    0x00A0,
    0x1680,
    0x2028,
    0x2029,
    0x202F,
    0x205F,
    0x3000,
    0xFEFF,
  };

  static bool _isSpace(int unit) =>
      _spaces.contains(unit) || (unit >= 0x2000 && unit <= 0x200A);

  static bool _drops(int unit) => _dropped.contains(unit);

  /// [query] with every unit the fold drops left out.
  static String fold(String query) => String.fromCharCodes([
    for (final unit in query.codeUnits)
      if (!_drops(unit)) unit,
  ]);

  /// The folded words of [query], split at runs of white space.
  static List<String> words(String query) {
    final words = <String>[];
    final word = <int>[];
    for (final unit in [...query.codeUnits, 0x0020]) {
      if (!_isSpace(unit)) {
        if (!_drops(unit)) word.add(unit);
      } else if (word.isNotEmpty) {
        words.add(String.fromCharCodes(word));
        word.clear();
      }
    }
    return words;
  }

  /// Where [folded], a query's folded words joined by U+0020, occurs in
  /// [text], left to right and not overlapping, as offsets into [text] in
  /// UTF-16 code units. A space of [folded] meets any run of white space. A
  /// match starts at a unit the fold keeps, and its end reaches over the
  /// dropped units that follow it, so that a letter keeps its marks. An
  /// empty [folded] occurs nowhere.
  static List<({int start, int end})> findAll(String text, String folded) {
    final found = <({int start, int end})>[];
    if (folded.isEmpty) return found;
    var start = 0;
    while (start < text.length) {
      final end = _matchAt(text, start, folded);
      if (end == null) {
        start++;
      } else {
        found.add((start: start, end: end));
        start = end;
      }
    }
    return found;
  }

  static int? _matchAt(String text, int start, String folded) {
    if (_drops(text.codeUnitAt(start))) return null;
    var at = start;
    for (var i = 0; i < folded.length; i++) {
      while (at < text.length && _drops(text.codeUnitAt(at))) {
        at++;
      }
      if (at == text.length) return null;
      final unit = folded.codeUnitAt(i);
      if (unit == 0x0020) {
        if (!_isSpace(text.codeUnitAt(at))) return null;
        while (at < text.length && _isSpace(text.codeUnitAt(at))) {
          at++;
        }
        continue;
      }
      if (text.codeUnitAt(at) != unit) return null;
      at++;
    }
    while (at < text.length && _drops(text.codeUnitAt(at))) {
      at++;
    }
    return at;
  }
}
