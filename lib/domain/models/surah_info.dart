import 'pack_text.dart';

enum RevelationPlace { makki, madani }

/// A surah's metadata from the pack; a value the source lacks is null.
final class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.name,
    required this.ayahCount,
    this.revelationPlace,
    this.revelationOrder,
  });

  final int number;
  final PackText name;
  final int ayahCount;
  final RevelationPlace? revelationPlace;
  final int? revelationOrder;
}
