import 'edition_map.dart';
import 'quran_address.dart';

/// Where unit [number] of a [division] starts: its first ayah and the page
/// that ayah is on.
final class DivisionEntry {
  const DivisionEntry({
    required this.division,
    required this.number,
    required this.firstAyah,
    required this.firstPage,
  });

  final Division division;
  final int number;
  final QuranAddress firstAyah;
  final int firstPage;

  @override
  bool operator ==(Object other) =>
      other is DivisionEntry &&
      other.division == division &&
      other.number == number &&
      other.firstAyah == firstAyah &&
      other.firstPage == firstPage;

  @override
  int get hashCode => Object.hash(division, number, firstAyah, firstPage);

  @override
  String toString() =>
      'DivisionEntry(${division.name} $number: $firstAyah, page $firstPage)';
}
