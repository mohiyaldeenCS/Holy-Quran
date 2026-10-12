import '../../utils/result.dart';
import '../models/edition_map.dart';
import '../models/go_to_error.dart';
import '../models/go_to_target.dart';
import '../models/quran_structure.dart';
import 'parse_go_to.dart';

/// The words a direct jump recognises before a number or a name, as the
/// interface writes them (`lib/l10n/app_ar.arb`).
final class DirectJumpWords {
  const DirectJumpWords({
    required this.surah,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.rub,
  });

  final String surah;
  final String page;
  final String juz;
  final String hizb;
  final String rub;

  GoToKind? _kindOf(String word) => {
    surah: GoToKind.surah,
    page: GoToKind.page,
    juz: GoToKind.juz,
    hizb: GoToKind.hizb,
    rub: GoToKind.rub,
  }[word];
}

/// The number of the surah whose stored name is [name], `Ok(null)` when none
/// is.
typedef SurahNameLookup = Future<Result<int?>> Function(String name);

final _colonForm = RegExp(r'^(\S+?)\s*:\s*(\S+)$');
final _firstWord = RegExp(r'^(\S+)\s+(\S.*)$');
final _lastWord = RegExp(r'^(.*\S)\s+(\S+)$');

/// The place typed into the search field (`SR-07`), or null when [text] is
/// not a jump and is searched for instead.
///
/// The forms, with digits of any of the three systems: `surah:ayah`; a
/// surah's name and an ayah; the surah word and a surah number or name, with
/// or without an ayah, or with `surah:ayah`; the page, juz, hizb or rub word
/// and a number. A jump to a place the edition does not have fails with a
/// [GoToError], a failed name lookup with the lookup's error.
Future<Result<GoToTarget>?> parseDirectJump(
  String text, {
  required DirectJumpWords words,
  required QuranStructure structure,
  required SurahNameLookup surahNamed,
}) async {
  final query = text.trim();
  if (_colonForm.firstMatch(query) case final match?
      when isDigitRun(match[1]!) && isDigitRun(match[2]!)) {
    return _surah(structure, match[1]!, ayah: match[2]);
  }
  if (_firstWord.firstMatch(query) case final match?) {
    final rest = match[2]!;
    final kind = words._kindOf(match[1]!);
    if (kind == GoToKind.surah) {
      return _surahNumberOrName(rest, structure, surahNamed);
    }
    if (kind?.division case final division? when isDigitRun(rest)) {
      return _division(structure, division, rest);
    }
  }
  return _surahNameAndAyah(query, structure, surahNamed);
}

/// What follows the surah word: a number or a name, with or without an ayah.
Future<Result<GoToTarget>?> _surahNumberOrName(
  String text,
  QuranStructure structure,
  SurahNameLookup surahNamed,
) async {
  if (isDigitRun(text)) return _surah(structure, text);
  if (_colonForm.firstMatch(text) case final match?
      when isDigitRun(match[1]!) && isDigitRun(match[2]!)) {
    return _surah(structure, match[1]!, ayah: match[2]);
  }
  if (_lastWord.firstMatch(text) case final match?
      when isDigitRun(match[1]!) && isDigitRun(match[2]!)) {
    return _surah(structure, match[1]!, ayah: match[2]);
  }
  return await _surahNameAndAyah(text, structure, surahNamed) ??
      switch (await surahNamed(text)) {
        Ok(value: final surah?) => goToSurah(structure, surah),
        Ok(value: null) => null,
        Failure(:final error) => Failure(error),
      };
}

Future<Result<GoToTarget>?> _surahNameAndAyah(
  String text,
  QuranStructure structure,
  SurahNameLookup surahNamed,
) async {
  final match = _lastWord.firstMatch(text);
  if (match == null || !isDigitRun(match[2]!)) return null;
  return switch (await surahNamed(match[1]!)) {
    Ok(value: final surah?) => switch (readNumber(match[2]!)) {
      final ayah? => goToSurah(structure, surah, ayah: ayah),
      null => const Failure(UnreadableGoTo()),
    },
    Ok(value: null) => null,
    Failure(:final error) => Failure(error),
  };
}

/// [surah] and [ayah] are digit runs; one too long to read is refused.
Result<GoToTarget> _surah(
  QuranStructure structure,
  String surah, {
  String? ayah,
}) {
  final surahNumber = readNumber(surah);
  final ayahNumber = ayah == null ? null : readNumber(ayah);
  if (surahNumber == null || (ayah != null && ayahNumber == null)) {
    return const Failure(UnreadableGoTo());
  }
  return goToSurah(structure, surahNumber, ayah: ayahNumber);
}

Result<GoToTarget> _division(
  QuranStructure structure,
  Division division,
  String number,
) => switch (readNumber(number)) {
  final value? => goToDivision(structure, division, value),
  null => const Failure(UnreadableGoTo()),
};
