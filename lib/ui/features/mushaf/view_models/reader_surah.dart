import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';

/// A surah the reader shows: its facts and its text as the engine sets it.
final class ReaderSurah {
  const ReaderSurah({required this.info, required this.text});

  final SurahInfo info;
  final SurahText text;
}
