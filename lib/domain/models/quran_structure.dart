import 'edition_map.dart';
import 'quran_address.dart';

/// The facts of the reference edition that plans, parsers and screens need,
/// read from the base pack. Numbers count from 1; a number or address
/// outside the edition throws a [RangeError] or an [ArgumentError].
abstract interface class QuranStructure {
  /// The riwaya of every address given and taken.
  String get riwaya;

  int get surahCount;

  int ayahCount(int surah);

  /// The surah after [surah], or null after the last.
  int? nextSurah(int surah);

  /// How many pages, juz, hizb or rub the edition has.
  int count(Division division);

  /// The first ayah of page, juz, hizb or rub [number].
  QuranAddress firstAyah(Division division, int number);

  /// The page, juz, hizb or rub holding the ayah of [address].
  int numberAt(Division division, QuranAddress address);
}
