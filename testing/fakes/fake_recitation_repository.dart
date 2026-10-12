import 'package:flutter/foundation.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// A [RecitationRepository] in memory, for view-model tests. A test sets
/// [recitations], which notifies listeners and, unlike the real
/// repository, is not filtered by rights; and [answers], which answers
/// both file calls; every call is logged in [calls] as `(recitation id,
/// surah, ayah or null, quality)`.
final class FakeRecitationRepository extends ChangeNotifier
    implements RecitationRepository {
  FakeRecitationRepository([this._recitations = const []]);

  List<CatalogueRecitation> _recitations;

  /// By default no recitation is listed.
  Result<RecitationAudio> Function(
    String recitationId,
    int surah,
    int? ayah,
    int qualityKbps,
  )
  answers = (recitationId, _, _, _) =>
      Failure(RecitationNotListed(recitationId));

  final List<(String, int, int?, int)> calls = [];

  @override
  List<CatalogueRecitation> get recitations => _recitations;

  set recitations(List<CatalogueRecitation> value) {
    _recitations = value;
    notifyListeners();
  }

  @override
  Future<Result<RecitationAudio>> surahFile(
    String recitationId,
    int surah, {
    required int qualityKbps,
  }) async {
    calls.add((recitationId, surah, null, qualityKbps));
    return answers(recitationId, surah, null, qualityKbps);
  }

  @override
  Future<Result<RecitationAudio>> ayahFile(
    String recitationId,
    QuranAddress address, {
    required int qualityKbps,
  }) async {
    calls.add((recitationId, address.surah, address.ayah, qualityKbps));
    return answers(recitationId, address.surah, address.ayah, qualityKbps);
  }
}
