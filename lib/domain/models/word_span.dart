/// A word of an ayah as offsets into its pack text, in UTF-16 code units,
/// [start] inclusive and [end] exclusive.
final class WordSpan {
  const WordSpan({required this.number, required this.start, required this.end})
    : assert(0 <= start && start <= end);

  final int number;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is WordSpan &&
      other.number == number &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(number, start, end);
}
