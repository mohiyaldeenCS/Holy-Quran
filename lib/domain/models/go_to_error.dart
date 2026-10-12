import 'edition_map.dart';

/// Why a go-to or a direct jump was refused, with what the sentence that
/// names the reason needs.
sealed class GoToError implements Exception {
  const GoToError();
}

final class NoSuchAyah extends GoToError {
  const NoSuchAyah({
    required this.surah,
    required this.ayah,
    required this.ayahCount,
  });

  final int surah;

  /// The ayah number asked for.
  final int ayah;

  /// How many ayat [surah] has.
  final int ayahCount;

  @override
  bool operator ==(Object other) =>
      other is NoSuchAyah &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.ayahCount == ayahCount;

  @override
  int get hashCode => Object.hash(surah, ayah, ayahCount);

  @override
  String toString() => 'NoSuchAyah($surah:$ayah of $ayahCount)';
}

final class NoSuchSurah extends GoToError {
  const NoSuchSurah({required this.surah, required this.surahCount});

  /// The surah number asked for.
  final int surah;
  final int surahCount;

  @override
  bool operator ==(Object other) =>
      other is NoSuchSurah &&
      other.surah == surah &&
      other.surahCount == surahCount;

  @override
  int get hashCode => Object.hash(surah, surahCount);

  @override
  String toString() => 'NoSuchSurah($surah of $surahCount)';
}

/// A page, juz, hizb or rub number outside the edition.
final class DivisionOutOfRange extends GoToError {
  const DivisionOutOfRange({
    required this.division,
    required this.number,
    required this.count,
  });

  final Division division;

  /// The number asked for.
  final int number;

  /// How many units of [division] the edition has.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DivisionOutOfRange &&
      other.division == division &&
      other.number == number &&
      other.count == count;

  @override
  int get hashCode => Object.hash(division, number, count);

  @override
  String toString() => 'DivisionOutOfRange(${division.name} $number of $count)';
}

/// Input that is not a number where one is needed.
final class UnreadableGoTo extends GoToError {
  const UnreadableGoTo();

  @override
  bool operator ==(Object other) => other is UnreadableGoTo;

  @override
  int get hashCode => (UnreadableGoTo).hashCode;

  @override
  String toString() => 'UnreadableGoTo()';
}
