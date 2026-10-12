import 'quran_address.dart';
import 'quran_range.dart';

/// What a play request covers (`AU-02`, `AU-03`). Numbers are checked against
/// the edition when the plan is built.
sealed class PlaybackRange {
  const PlaybackRange();

  static void _checkAyah(QuranAddress address) {
    if (address.isWord) {
      throw ArgumentError.value(address, 'address', 'must be an ayah address');
    }
  }

  static int _checkNumber(int value, String name) =>
      value >= 1 ? value : throw RangeError.value(value, name, 'must be >= 1');
}

final class SingleAyah extends PlaybackRange {
  SingleAyah(this.ayah) {
    PlaybackRange._checkAyah(ayah);
  }

  final QuranAddress ayah;
}

final class AyahSpan extends PlaybackRange {
  AyahSpan(this.range) {
    PlaybackRange._checkAyah(range.start);
  }

  final QuranRange range;
}

/// From page [first] to page [last]; the current page when they are equal.
final class PageSpan extends PlaybackRange {
  PageSpan(int first, [int? last])
    : first = PlaybackRange._checkNumber(first, 'first'),
      last = PlaybackRange._checkNumber(last ?? first, 'last') {
    if (this.last < this.first) {
      throw ArgumentError('last page $last before first page $first');
    }
  }

  final int first;
  final int last;
}

final class WholeSurah extends PlaybackRange {
  WholeSurah(int surah) : surah = PlaybackRange._checkNumber(surah, 'surah');

  final int surah;
}

final class WholeJuz extends PlaybackRange {
  WholeJuz(int juz) : juz = PlaybackRange._checkNumber(juz, 'juz');

  final int juz;
}

final class WholeHizb extends PlaybackRange {
  WholeHizb(int hizb) : hizb = PlaybackRange._checkNumber(hizb, 'hizb');

  final int hizb;
}

/// Several surahs, played in mushaf order, each once.
final class SurahSet extends PlaybackRange {
  SurahSet(Iterable<int> surahs)
    : surahs = List.unmodifiable(
        {for (final surah in surahs) PlaybackRange._checkNumber(surah, 'surah')}
            .toList()
          ..sort(),
      ) {
    if (this.surahs.isEmpty) throw ArgumentError('no surah given');
  }

  final List<int> surahs;
}

/// From [from] to the last ayah of the mushaf.
final class ToEndOfMushaf extends PlaybackRange {
  ToEndOfMushaf(this.from) {
    PlaybackRange._checkAyah(from);
  }

  final QuranAddress from;
}

/// Where a play started from the ayah tools ends (`AU-03`).
enum AyahToolEnd { ayah, page, surah, juz, untilStopped }

final class FromAyahTool extends PlaybackRange {
  FromAyahTool(this.ayah, this.until) {
    PlaybackRange._checkAyah(ayah);
  }

  final QuranAddress ayah;
  final AyahToolEnd until;
}
