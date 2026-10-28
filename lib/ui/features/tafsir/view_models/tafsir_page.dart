import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';

/// An ayah as the chosen book explains it, with the facts of the source
/// badge (`TF-05`).
final class TafsirPage {
  const TafsirPage({
    required this.packId,
    required this.position,
    required this.book,
    required this.source,
    required this.version,
  });

  final String packId;
  final TafsirPosition position;
  final TafsirBook book;

  /// The name of the source the book was digitised from; null when the
  /// manifest lists none.
  final String? source;

  /// The pack's version.
  final int version;

  TafsirPassage? get passage => position.passage;

  /// The first and last ayah number of the passage when it explains more
  /// than one ayah together (`TF-04`); null otherwise.
  ({int first, int last})? get range {
    final passage = this.passage;
    if (passage == null) return null;
    final first = passage.range.start.ayah;
    final last = passage.range.end.ayah;
    return first == last ? null : (first: first, last: last);
  }
}

/// A downloaded book the default tafsir can be chosen from (`TF-01`).
final class TafsirChoice {
  const TafsirChoice({
    required this.packId,
    required this.title,
    required this.chosen,
  });

  final String packId;
  final PackText title;

  /// Whether the reader shows this book.
  final bool chosen;
}
