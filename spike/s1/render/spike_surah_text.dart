import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/utils/result.dart';

/// One surah as the spike layouts take it, read by address from a verified
/// text pack. Nothing here holds or derives text; the values are the pack's.
final class SpikeSurahText {
  SpikeSurahText({
    required this.firstAyah,
    required List<PackText> ayat,
    required List<List<WordSpan>> words,
    required this.basmala,
    required Map<QuranAddress, int> pageStarts,
  }) : ayat = List.unmodifiable(ayat),
       words = List.unmodifiable(words),
       pageStarts = Map.unmodifiable(pageStarts);

  /// Ayah 1 of the surah.
  final QuranAddress firstAyah;
  final List<PackText> ayat;
  final List<List<WordSpan>> words;
  final PackText? basmala;

  /// The ayat of this surah at which a reference page starts, with the
  /// page's number, ayah 1 excluded: a page that starts with the surah has
  /// no boundary inside its text.
  final Map<QuranAddress, int> pageStarts;
}

/// Reads surah [surah] through [repository]. A failure of the repository
/// throws a [StateError] naming the call, never the text.
Future<SpikeSurahText> readSpikeSurahText(
  QuranTextRepository repository,
  int surah,
) async {
  T expectOk<T>(Result<T> result, String what) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('$what failed: $error'),
  };

  final info = expectOk(await repository.surahs(), 'surahs')[surah - 1];
  final riwaya = repository.riwaya;
  final ayat = <PackText>[];
  final words = <List<WordSpan>>[];
  for (var ayah = 1; ayah <= info.ayahCount; ayah++) {
    final address = QuranAddress(riwaya, surah, ayah);
    ayat.add(expectOk(await repository.ayahText(address), '$address text'));
    words.add(expectOk(await repository.words(address), '$address words'));
  }
  final edition = expectOk(await repository.editionMap(), 'edition map');
  return SpikeSurahText(
    firstAyah: QuranAddress(riwaya, surah, 1),
    ayat: ayat,
    words: words,
    basmala: expectOk(await repository.basmala(surah), 'basmala $surah'),
    pageStarts: {
      for (var page = 1; page <= edition.count(Division.page); page++)
        if (edition.startOf(Division.page, page) case final start
            when start.surah == surah && start.ayah > 1)
          start: page,
    },
  );
}
