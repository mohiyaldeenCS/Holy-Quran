import 'dart:isolate';

import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/query_fold.dart';
import '../../domain/models/search_hit.dart';
import '../../domain/models/search_match.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/tafsir_pack_database.dart';

/// Searches the passages of downloaded tafsir books (`TF-07`).
abstract interface class TafsirSearchRepository {
  /// The passages of [books], pack ids of installed tafsir books, whose
  /// text holds the folded words of [query] in order, separated by white
  /// space, anywhere, inside a word too; each with where it does. Book by
  /// book in the order given, passages in book order; a book no longer
  /// installed is left out. None for a query with no words.
  Future<Result<List<TafsirHit>>> search(String query, List<String> books);
}

/// Reads each book's passages off the main isolate, every surah of the
/// edition, and compares them with the query through [QueryFold.findAll]; a
/// passage is never folded, cut or copied. A sink of D-114. `installed`
/// lists only verified books that are serving. A book that fails to read
/// fails the call and is passed to `onFailed`, so that its integrity can be
/// reported.
final class PackTafsirSearchRepository implements TafsirSearchRepository {
  PackTafsirSearchRepository({
    required this._installed,
    required this._surahCount,
    this._onFailed,
  });

  final Future<List<VerifiedPack>> Function() _installed;
  final int _surahCount;
  final void Function(Exception error)? _onFailed;

  @override
  Future<Result<List<TafsirHit>>> search(
    String query,
    List<String> books,
  ) async {
    final installed = {
      for (final pack in await _installed()) pack.manifest.id: pack,
    };
    final packs = [for (final book in books) ?installed[book]];
    final folded = QueryFold.words(query).join(' ');
    if (folded.isEmpty) return const Ok([]);
    final hits = <TafsirHit>[];
    for (final pack in packs) {
      final surahCount = _surahCount;
      switch (await Isolate.run(() => _search(pack, folded, surahCount))) {
        case Ok(:final value):
          hits.addAll(value);
        case Failure(:final error):
          _onFailed?.call(error);
          return Failure(error);
      }
    }
    return Ok(hits);
  }

  static Result<List<TafsirHit>> _search(
    VerifiedPack pack,
    String folded,
    int surahCount,
  ) {
    final manifest = pack.manifest;
    final riwaya = manifest.riwaya;
    if (manifest.kind != PackKind.tafsir || riwaya == null) {
      return Failure(
        UnsupportedPackFormat(manifest.id, manifest.formatVersion),
      );
    }
    TafsirPackDatabase? database;
    try {
      final opened = database = TafsirPackDatabase.open(
        '${pack.directory}/$tafsirPackFileName',
        formatVersion: manifest.formatVersion,
        riwaya: riwaya,
      );
      return Ok([
        for (var surah = 1; surah <= surahCount; surah++)
          for (final passage in opened.passagesOfSurah(surah))
            if (_matches(passage.text, folded) case final matches
                when matches.isNotEmpty)
              TafsirHit(book: manifest.id, passage: passage, matches: matches),
      ]);
    } on PackFailure catch (failure) {
      return Failure(_named(manifest.id, failure));
    } finally {
      database?.close();
    }
  }

  /// Never a match that would cut a surrogate pair.
  static List<SearchMatch> _matches(PackText text, String folded) => [
    for (final (:start, :end) in QueryFold.findAll(text.verbatim, folded))
      if (text.isSliceBoundary(start) && text.isSliceBoundary(end))
        SearchMatch(start: start, end: end),
  ];

  /// The database names the file; the search names the pack [id].
  static PackFailure _named(String id, PackFailure failure) =>
      switch (failure) {
        UnsupportedPackFormat(:final formatVersion) => UnsupportedPackFormat(
          id,
          formatVersion,
        ),
        TextEncodingRejected(:final surah, :final ayah) => TextEncodingRejected(
          id,
          surah,
          ayah,
        ),
        FileHashMismatch(:final file) => FileHashMismatch(id, file),
        PackInconsistent(:final reason) => PackInconsistent(id, reason),
        _ => failure,
      };
}
