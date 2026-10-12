import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';

Note _note({
  String address = 'hafs:2:5',
  String body = 'synthetic note body',
  String? categoryId,
  Set<String> tagIds = const {},
}) => Note(
  id: 'n',
  address: QuranAddress.parse(address),
  body: body,
  categoryId: categoryId,
  tagIds: tagIds,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('refuses a word address', () {
    expect(() => _note(address: 'hafs:2:5:2'), throwsArgumentError);
  });

  test('is equal by every field', () {
    expect(_note(tagIds: {'a', 'b'}), _note(tagIds: {'b', 'a'}));
    expect(_note().hashCode, _note().hashCode);
    expect(_note(), isNot(_note(body: 'other synthetic body')));
    expect(_note(), isNot(_note(categoryId: 'category-a')));
    expect('${_note()}', 'Note(n, hafs:2:5)');
  });

  test('a search looks in its body and its tag names', () {
    final note = _note(tagIds: {'t'});

    expect(note.matches(query: 'note bo'), isTrue);
    expect(note.matches(query: 'tag-al', tagNames: {'t': 'tag-alpha'}), isTrue);
    expect(note.matches(query: 'absent'), isFalse);
  });

  test('a note without a category is in no category', () {
    expect(_note().matches(categoryId: 'category-a'), isFalse);
    expect(
      _note(categoryId: 'category-a').matches(categoryId: 'category-a'),
      isTrue,
    );
  });
}
