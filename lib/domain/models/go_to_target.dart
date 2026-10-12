import 'edition_map.dart';
import 'quran_address.dart';

/// What the go-to sheet asks for (`NV-03`): a surah, with or without an
/// ayah, or a page, juz, hizb or rub.
enum GoToKind {
  surah(null),
  page(Division.page),
  juz(Division.juz),
  hizb(Division.hizb),
  rub(Division.rub);

  const GoToKind(this.division);

  /// The division every kind but [surah] goes to.
  final Division? division;
}

/// Where a go-to or a direct jump leads, checked against the edition.
sealed class GoToTarget {
  const GoToTarget();

  /// The first ayah of the target.
  QuranAddress get start;
}

/// A surah, from its first ayah.
final class GoToSurah extends GoToTarget {
  GoToSurah(this.start) {
    if (start.ayah != 1 || start.isWord) {
      throw ArgumentError.value(start, 'start', 'must be the first ayah');
    }
  }

  @override
  final QuranAddress start;

  int get surah => start.surah;

  @override
  bool operator ==(Object other) => other is GoToSurah && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'GoToSurah($surah)';
}

final class GoToAyah extends GoToTarget {
  GoToAyah(this.start) {
    if (start.isWord) {
      throw ArgumentError.value(start, 'start', 'must be an ayah address');
    }
  }

  @override
  final QuranAddress start;

  @override
  bool operator ==(Object other) => other is GoToAyah && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'GoToAyah($start)';
}

/// A page, juz, hizb or rub.
final class GoToDivision extends GoToTarget {
  const GoToDivision(this.division, this.number, this.start);

  final Division division;
  final int number;

  @override
  final QuranAddress start;

  @override
  bool operator ==(Object other) =>
      other is GoToDivision &&
      other.division == division &&
      other.number == number &&
      other.start == start;

  @override
  int get hashCode => Object.hash(division, number, start);

  @override
  String toString() => 'GoToDivision(${division.name} $number, $start)';
}
