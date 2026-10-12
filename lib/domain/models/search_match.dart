/// Where a query occurs in a pack text, in UTF-16 code units into the text
/// as stored, [start] inclusive and [end] exclusive. Highlighting slices the
/// stored text at these offsets and changes no character.
final class SearchMatch {
  const SearchMatch({required this.start, required this.end})
    : assert(0 <= start && start < end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is SearchMatch && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SearchMatch($start, $end)';
}
