import 'package:holyquran/domain/models/pack_text.dart';

/// A downloaded book the default tafsir can be chosen from (`TF-01`).
final class TafsirChoice {
  const TafsirChoice({
    required this.packId,
    required this.title,
    required this.chosen,
  });

  final String packId;

  /// The book's title; null when the pack failed its checks, so that it has
  /// none to show.
  final PackText? title;

  /// Whether the reader shows this book.
  final bool chosen;
}
