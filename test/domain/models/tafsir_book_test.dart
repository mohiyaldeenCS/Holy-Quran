import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';

void main() {
  test('holds its facts, absent ones as null', () {
    const title = PackText.fromPack('Synthetic title');
    const author = PackText.fromPack('Synthetic author');
    const editor = PackText.fromPack('Synthetic editor');
    const book = TafsirBook(
      title: title,
      author: author,
      publisher: null,
      edition: null,
      editor: editor,
    );
    expect(book.title, same(title));
    expect(book.author, same(author));
    expect(book.publisher, isNull);
    expect(book.edition, isNull);
    expect(book.editor, same(editor));
  });
}
