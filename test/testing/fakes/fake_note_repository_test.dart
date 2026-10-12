import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_note_repository.dart';

void main() {
  test('adds, edits, lists, deletes and restores notes', () async {
    final notes = FakeNoteRepository();
    final ayah = QuranAddress.parse('hafs:2:5');

    final note = (await notes.add(ayah, 'synthetic body') as Ok<Note>).value;
    await notes.add(ayah, 'another synthetic body');
    await notes.edit(
      note.id,
      body: 'edited synthetic body',
      categoryId: 'category-a',
      tagIds: {},
    );

    expect((await notes.notesAt(ayah) as Ok<List<Note>>).value, hasLength(2));
    expect(
      (await notes.list(categoryId: 'category-a') as Ok<List<Note>>)
          .value
          .single
          .body,
      'edited synthetic body',
    );
    expect(await notes.add(ayah, ''), isA<Failure<Note>>());
    await notes.delete(note.id);
    expect((await notes.list() as Ok<List<Note>>).value, hasLength(1));
    await notes.restore(note.id);
    expect((await notes.annotatedAyat() as Ok<Set<QuranAddress>>).value, {
      ayah,
    });
    expect(await notes.restore(note.id), isA<Ok<void>>());
    expect(await notes.restore('absent'), isA<Failure<void>>());
  });
}
