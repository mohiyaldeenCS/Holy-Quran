import '../../domain/models/edition_map.dart';
import '../../domain/models/mark_span.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/surah_info.dart';
import '../../domain/models/word_span.dart';
import '../../utils/result.dart';

/// The text of one riwaya from a verified text pack, by address. The first
/// read of a surah in a session checks its digest; a mismatch disables the
/// pack for the session.
abstract interface class QuranTextRepository {
  String get riwaya;

  /// The font the text is drawn with; text and font are one pair.
  PackFont get font;

  Future<Result<List<SurahInfo>>> surahs();

  /// The text of the ayah at [address], an ayah address.
  Future<Result<PackText>> ayahText(QuranAddress address);

  /// The basmala stored for [surah]; null when the surah has none.
  Future<Result<PackText?>> basmala(int surah);

  /// The word spans of the ayah at [address], an ayah address. The spans of
  /// a surah are checked on its first read, like its digest.
  Future<Result<List<WordSpan>>> words(QuranAddress address);

  /// The marks of the ayah at [address], an ayah address: the tokens with no
  /// letter, such as pause marks, each outside every word span. They are
  /// checked with the word spans on the surah's first read.
  Future<Result<List<MarkSpan>>> marks(QuranAddress address);

  Future<Result<EditionMap>> editionMap();

  /// Whether the ayah or word at [address] is in the pack: `Ok(false)` when
  /// it is not, a failure when the pack cannot answer because it is broken or
  /// disabled.
  Future<Result<bool>> contains(QuranAddress address);
}
