import 'pack_text.dart';

/// The facts of a tafsir book its pack stores for the source badge
/// (`TF-05`). A fact the source does not give is null and hidden. The
/// digitisation source and version are the pack manifest's tafsir source.
final class TafsirBook {
  const TafsirBook({
    required this.title,
    required this.author,
    required this.publisher,
    required this.edition,
    required this.editor,
  });

  final PackText title;
  final PackText author;
  final PackText? publisher;
  final PackText? edition;
  final PackText? editor;
}
