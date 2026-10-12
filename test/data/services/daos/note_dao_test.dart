import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/note_dao.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late NoteDao dao;
  late TagDao tags;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = NoteDao(db);
    tags = TagDao(db);
  });
  tearDown(() => db.close());

  Future<Set<String>> tagsOf(String id) async => {
    for (final (_, tag) in await dao.liveTags(noteId: id)) tag.id,
  };

  test('add stores a note with its tags; an ayah takes several', () async {
    final alpha = await tags.named('tag-alpha', at: 1);
    final first = await dao.add(
      'hafs:2:5',
      'synthetic note body',
      categoryId: 'category-a',
      tagIds: {alpha.id},
      at: 10,
    );
    final second = await dao.add(
      'hafs:2:5',
      'another synthetic body',
      categoryId: null,
      tagIds: {},
      at: 20,
    );

    expect(first.body, 'synthetic note body');
    expect(first.createdAt, 10);
    expect(second.categoryId, isNull);
    expect(await dao.liveAt('hafs:2:5'), unorderedEquals([first, second]));
    expect(await dao.live(), hasLength(2));
    expect(await dao.byId(first.id), first);
    expect(await tagsOf(first.id), {alpha.id});
    expect(await tagsOf(second.id), isEmpty);
  });

  test('edit sets body, category and tags of a live note', () async {
    final alpha = await tags.named('tag-alpha', at: 1);
    final beta = await tags.named('tag-beta', at: 1);
    final row = await dao.add(
      'hafs:2:5',
      'synthetic note body',
      categoryId: 'category-a',
      tagIds: {alpha.id},
      at: 10,
    );

    expect(
      await dao.edit(
        row.id,
        body: 'edited synthetic body',
        categoryId: null,
        tagIds: {beta.id},
        at: 20,
      ),
      isTrue,
    );
    final edited = (await dao.byId(row.id))!;
    expect(edited.body, 'edited synthetic body');
    expect(edited.categoryId, isNull);
    expect(edited.updatedAt, 20);
    expect(edited.createdAt, 10);
    expect(await tagsOf(row.id), {beta.id});
    final pair = (await db.select(db.noteTag).get()).singleWhere(
      (p) => p.tagId == alpha.id,
    );
    expect(pair.deleted, isTrue);

    await dao.edit(
      row.id,
      body: 'edited synthetic body',
      categoryId: null,
      tagIds: {alpha.id},
      at: 30,
    );
    expect(await tagsOf(row.id), {alpha.id});
    expect(await db.select(db.noteTag).get(), hasLength(2));

    expect(
      await dao.edit('absent', body: 'x', categoryId: null, tagIds: {}, at: 30),
      isFalse,
    );
  });

  test('edit leaves pairs of a deleted tag', () async {
    final alpha = await tags.named('tag-alpha', at: 1);
    final row = await dao.add(
      'hafs:2:5',
      'synthetic note body',
      categoryId: null,
      tagIds: {alpha.id},
      at: 10,
    );
    await tags.markDeleted(alpha.id, at: 20);
    expect(await tagsOf(row.id), isEmpty);

    await dao.edit(row.id, body: 'b', categoryId: null, tagIds: {}, at: 30);
    await tags.revive(alpha.id, at: 40);

    expect(await tagsOf(row.id), {alpha.id});
  });

  test('markDeleted keeps a tombstone that revive clears', () async {
    final row = await dao.add(
      'hafs:2:5',
      'synthetic note body',
      categoryId: null,
      tagIds: {},
      at: 10,
    );

    expect(await dao.markDeleted(row.id, at: 20), isTrue);
    expect(await dao.markDeleted(row.id, at: 25), isFalse);
    expect(await dao.live(), isEmpty);
    expect(await dao.liveAt('hafs:2:5'), isEmpty);
    expect(
      await dao.edit(row.id, body: 'b', categoryId: null, tagIds: {}, at: 30),
      isFalse,
    );
    expect((await dao.byId(row.id))!.updatedAt, 20);

    expect(await dao.revive(row.id, at: 40), isTrue);
    expect(await dao.revive(row.id, at: 50), isFalse);
    expect((await dao.byId(row.id))!.deleted, isFalse);
    expect((await dao.byId(row.id))!.updatedAt, 40);
  });
}
