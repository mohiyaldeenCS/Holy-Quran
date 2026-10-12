import '../../utils/result.dart';
import '../models/edition_map.dart';
import '../models/go_to_error.dart';
import '../models/go_to_target.dart';
import '../models/quran_address.dart';
import '../models/quran_structure.dart';

/// The zeros of the Western, Arabic-Indic and extended Arabic-Indic digits.
const _zeros = [0x0030, 0x0660, 0x06F0];

/// More digits than any count of an edition needs; nine always fit an `int`,
/// on the web too.
const _maxDigits = 9;

/// Whether [text] is a run of digits of the three systems, however long.
bool isDigitRun(String text) =>
    text.isNotEmpty &&
    text.codeUnits.every((unit) => _digitValue(unit) != null);

/// The value of [text] when it is a run of at most nine digits; otherwise
/// null.
int? readNumber(String text) {
  if (text.length > _maxDigits || !isDigitRun(text)) return null;
  return text.codeUnits.fold<int>(
    0,
    (value, unit) => value * 10 + _digitValue(unit)!,
  );
}

int? _digitValue(int unit) {
  for (final zero in _zeros) {
    if (unit >= zero && unit <= zero + 9) return unit - zero;
  }
  return null;
}

/// The target of the go-to sheet's fields as typed: [number] is the surah or
/// division number, [ayah] the ayah of a surah, empty when none was given.
/// Spaces around either are ignored. Throws an [ArgumentError] when an ayah
/// is given for a kind other than [GoToKind.surah]: the sheet offers none.
Result<GoToTarget> parseGoTo(
  QuranStructure structure,
  GoToKind kind,
  String number, {
  String ayah = '',
}) {
  final ayahText = ayah.trim();
  if (kind != GoToKind.surah && ayahText.isNotEmpty) {
    throw ArgumentError.value(ayah, 'ayah', 'is not asked for a ${kind.name}');
  }
  final value = readNumber(number.trim());
  final ayahValue = ayahText.isEmpty ? null : readNumber(ayahText);
  if (value == null || (ayahText.isNotEmpty && ayahValue == null)) {
    return const Failure(UnreadableGoTo());
  }
  return switch (kind.division) {
    null => goToSurah(structure, value, ayah: ayahValue),
    final division => goToDivision(structure, division, value),
  };
}

/// Surah [surah], or its ayah [ayah] when given, if the edition has it.
Result<GoToTarget> goToSurah(QuranStructure structure, int surah, {int? ayah}) {
  final surahCount = structure.surahCount;
  if (surah < 1 || surah > surahCount) {
    return Failure(NoSuchSurah(surah: surah, surahCount: surahCount));
  }
  if (ayah == null) {
    return Ok(GoToSurah(QuranAddress(structure.riwaya, surah, 1)));
  }
  final ayahCount = structure.ayahCount(surah);
  if (ayah < 1 || ayah > ayahCount) {
    return Failure(NoSuchAyah(surah: surah, ayah: ayah, ayahCount: ayahCount));
  }
  return Ok(GoToAyah(QuranAddress(structure.riwaya, surah, ayah)));
}

/// Unit [number] of [division], if the edition has it.
Result<GoToTarget> goToDivision(
  QuranStructure structure,
  Division division,
  int number,
) {
  final count = structure.count(division);
  if (number < 1 || number > count) {
    return Failure(
      DivisionOutOfRange(division: division, number: number, count: count),
    );
  }
  return Ok(
    GoToDivision(division, number, structure.firstAyah(division, number)),
  );
}
