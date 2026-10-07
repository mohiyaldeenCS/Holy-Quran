/// A string read from a content pack, carried unchanged. Only the sinks listed
/// in D-062 read [verbatim]; `test/guards/pack_text_guard_test.dart` enforces
/// it.
final class PackText {
  const PackText.fromPack(this._value);

  final String _value;

  String get verbatim => _value;

  @override
  bool operator ==(Object other) => other is PackText && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'PackText(${_value.length} code units)';
}
