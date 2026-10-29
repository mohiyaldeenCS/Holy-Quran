import 'dart:async';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/utils/result.dart';

/// A text repository whose ayah reads wait for the test: each read is held in
/// [pending] until the test completes it, or answers at once with [then]
/// once [open]. Everything else is [inner]'s.
final class GatedTextRepository implements QuranTextRepository {
  GatedTextRepository(this.inner);

  final QuranTextRepository inner;
  final pending = <Completer<Result<PackText>>>[];
  bool open = false;
  Result<PackText>? then;

  @override
  String get riwaya => inner.riwaya;

  @override
  PackFont get font => inner.font;

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) {
    if (open) {
      final answer = then;
      return answer == null ? inner.ayahText(address) : Future.value(answer);
    }
    final read = Completer<Result<PackText>>();
    pending.add(read);
    return read.future;
  }

  @override
  Future<Result<List<SurahInfo>>> surahs() => inner.surahs();

  @override
  Future<Result<PackText?>> basmala(int surah) => inner.basmala(surah);

  @override
  Future<Result<Set<int>>> basmalaSurahs() => inner.basmalaSurahs();

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) =>
      inner.words(address);

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) =>
      inner.marks(address);

  @override
  Future<Result<EditionMap>> editionMap() => inner.editionMap();

  @override
  Future<Result<bool>> contains(QuranAddress address) =>
      inner.contains(address);
}
