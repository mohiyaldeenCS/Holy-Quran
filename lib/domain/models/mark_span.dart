/// A mark of an ayah, such as a pause mark or a sajda sign: a token with no
/// letter, outside every word span (D-078). [afterWord] is the number of the
/// word it follows, 0 when it precedes the first word. Offsets are into the
/// ayah's pack text, in UTF-16 code units, [start] inclusive and [end]
/// exclusive.
final class MarkSpan {
  const MarkSpan({
    required this.number,
    required this.afterWord,
    required this.start,
    required this.end,
  }) : assert(afterWord >= 0 && 0 <= start && start <= end);

  final int number;
  final int afterWord;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MarkSpan &&
      other.number == number &&
      other.afterWord == afterWord &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(number, afterWord, start, end);
}
