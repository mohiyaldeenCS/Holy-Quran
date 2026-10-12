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

  static final _space = RegExp(r'\s+');

  static bool _drops(int unit) => _dropped.contains(unit);

  /// [query] with every unit the fold drops left out.
  static String fold(String query) => String.fromCharCodes([
    for (final unit in query.codeUnits)
      if (!_drops(unit)) unit,
  ]);

  /// The folded words of [query], split at runs of white space.
  static List<String> words(String query) => [
    for (final word in fold(query).split(_space))
      if (word.isNotEmpty) word,
  ];

  /// Where [folded], a folded query, occurs in [text], left to right and not
  /// overlapping, as offsets into [text] in UTF-16 code units. A match
  /// starts at a unit the fold keeps, and its end reaches over the dropped
  /// units that follow it, so that a letter keeps its marks. An empty
  /// [folded] occurs nowhere.
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
      if (at == text.length || text.codeUnitAt(at) != folded.codeUnitAt(i)) {
        return null;
      }
      at++;
    }
    while (at < text.length && _drops(text.codeUnitAt(at))) {
      at++;
    }
    return at;
  }
}
