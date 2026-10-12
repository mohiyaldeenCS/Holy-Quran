import 'pack_text.dart';
import 'quran_address.dart';

/// A word's search form of one kind, as the source spells it (`SR-03`,
/// D-037). The app derives no form of its own; only the query is folded.
final class SearchForm {
  SearchForm({required this.word, required this.kind, required this.form}) {
    if (!word.isWord) {
      throw ArgumentError.value(word, 'word', 'is not a word address');
    }
    if (!kindPattern.hasMatch(kind)) {
      throw ArgumentError.value(
        kind,
        'kind',
        'must match ${kindPattern.pattern}',
      );
    }
  }

  /// The form of a form kind's name, in a manifest and in the pack.
  static final kindPattern = RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$');

  final QuranAddress word;
  final String kind;
  final PackText form;
}
