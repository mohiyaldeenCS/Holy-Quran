import 'package:flutter/foundation.dart';

import 'package:holyquran/domain/models/quran_address.dart';

/// What the reader highlights inside the text, by address
/// (`docs/DESIGN_SYSTEM.md`, "Highlights inside Quran text"). Painted behind
/// the glyphs; the text is never changed.
final class ReaderHighlights {
  const ReaderHighlights({
    this.selectedAyah,
    this.recitedAyah,
    this.spokenWord,
    this.searchMatches = const {},
  });

  static const none = ReaderHighlights();

  /// The ayah a long press selected: tinted, with a thin frame.
  final QuranAddress? selectedAyah;

  /// The ayah being recited: tinted, with its marker filled.
  final QuranAddress? recitedAyah;

  /// The word being spoken: a stronger tint with a 2 px underline.
  final QuranAddress? spokenWord;

  /// The words a search matched: a tint with an underline in `info`.
  final Set<QuranAddress> searchMatches;

  bool get isEmpty =>
      selectedAyah == null &&
      recitedAyah == null &&
      spokenWord == null &&
      searchMatches.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReaderHighlights &&
      other.selectedAyah == selectedAyah &&
      other.recitedAyah == recitedAyah &&
      other.spokenWord == spokenWord &&
      setEquals(other.searchMatches, searchMatches);

  @override
  int get hashCode => Object.hash(
    selectedAyah,
    recitedAyah,
    spokenWord,
    Object.hashAllUnordered(searchMatches),
  );
}
