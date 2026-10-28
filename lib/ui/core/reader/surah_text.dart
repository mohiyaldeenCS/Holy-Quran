import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';

/// One ayah as the view model hands it over: its pack text with the stored
/// word and mark spans, in order.
final class AyahText {
  AyahText({
    required this.text,
    required List<WordSpan> words,
    List<MarkSpan> marks = const [],
  }) : words = List.unmodifiable(words),
       marks = List.unmodifiable(marks);

  final PackText text;
  final List<WordSpan> words;
  final List<MarkSpan> marks;
}

/// What a margin mark marks (`RD-02`).
enum MarginMarkKind { rub, hizb, juz, sajda }

/// A margin mark beside the ayah of [ayah]: the start of a rub, hizb or juz,
/// with its [hizb] or [juz] number, or a sajda. A rub mark also says which
/// [quarter] of its hizb begins there: 1, 2 or 3 (the hizb's own start is a
/// hizb mark).
final class MarginMark {
  const MarginMark(this.kind, this.ayah, {this.hizb, this.juz, this.quarter});

  final MarginMarkKind kind;
  final int ayah;

  /// The hizb a rub or hizb mark names.
  final int? hizb;

  /// The juz a juz mark names.
  final int? juz;

  final int? quarter;

  @override
  bool operator ==(Object other) =>
      other is MarginMark &&
      other.kind == kind &&
      other.ayah == ayah &&
      other.hizb == hizb &&
      other.juz == juz &&
      other.quarter == quarter;

  @override
  int get hashCode => Object.hash(kind, ayah, hizb, juz, quarter);
}

/// A whole surah for surah mode: its ayat from 1 on, its stored basmala, the
/// reference pages that begin inside it ([pageStarts], ayah number to page
/// number) and its margin marks.
final class SurahText {
  SurahText({
    required this.riwaya,
    required this.surah,
    required List<AyahText> ayat,
    this.basmala,
    Map<int, int> pageStarts = const {},
    List<MarginMark> marginMarks = const [],
  }) : ayat = List.unmodifiable(ayat),
       pageStarts = Map.unmodifiable(pageStarts),
       marginMarks = List.unmodifiable(marginMarks) {
    if (ayat.isEmpty) throw ArgumentError.value(ayat, 'ayat', 'is empty');
    for (final ayah in [
      ...pageStarts.keys,
      for (final m in marginMarks) m.ayah,
    ]) {
      if (ayah < 1 || ayah > ayat.length) {
        throw RangeError.range(ayah, 1, ayat.length, 'ayah');
      }
    }
  }

  final String riwaya;
  final int surah;
  final List<AyahText> ayat;

  /// The pack's basmala field for this surah; null where it has none.
  final PackText? basmala;
  final Map<int, int> pageStarts;
  final List<MarginMark> marginMarks;

  QuranAddress addressOf(int ayah) => QuranAddress(riwaya, surah, ayah);

  /// Whether the basmala stands as its own line above the ayat (`RD-02`):
  /// never in al-Tawba, which has none, nor in al-Fatiha, where it is the
  /// first, numbered ayah.
  bool get showsBasmala =>
      basmala != null && surah != _fatiha && surah != _tawba;
}

const int _fatiha = 1;
const int _tawba = 9;
