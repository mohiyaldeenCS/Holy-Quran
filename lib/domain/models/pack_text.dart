/// A string read from a content pack, carried unchanged. Only the sinks listed
/// in D-062 read [verbatim]; `test/guards/pack_text_guard_test.dart` enforces
/// it.
final class PackText {
  const PackText.fromPack(this._value);

  final String _value;

  String get verbatim => _value;

  /// Whether a slice may start or end at [offset], in UTF-16 code units:
  /// within the text and not between the two halves of a surrogate pair. The
  /// text itself is not exposed.
  bool isSliceBoundary(int offset) =>
      offset >= 0 &&
      offset <= _value.length &&
      !(offset > 0 &&
          offset < _value.length &&
          _isHighSurrogate(_value.codeUnitAt(offset - 1)) &&
          _isLowSurrogate(_value.codeUnitAt(offset)));

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;

  static bool _isLowSurrogate(int unit) => (unit & 0xFC00) == 0xDC00;

  @override
  bool operator ==(Object other) => other is PackText && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'PackText(${_value.length} code units)';
}
