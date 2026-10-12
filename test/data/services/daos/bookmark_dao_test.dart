import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/bookmark_dao.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late BookmarkDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = BookmarkDao(db);
  });
  tearDown(() => db.close());

  Future<Set<String>> tagsOf(String id) async => {
    for (final (_, tag) in await dao.liveTags(bookmarkId: id)) tag.id,
  };

  test('place adds a bookmark, then recategorises the same one', () async {
    final first = await dao.place('hafs:2:5', 'category-a', at: 10);
    final same = await dao.place('hafs:2:5', 'category-a', at: 20);
    final moved = await dao.place('hafs:2:5', 'category-b', at: 30);

    expect(first.createdAt, 10);
    expect(first.updatedAt, 10);
    expect(same, first);
    expect(moved.id, first.id);
    expect(moved.categoryId, 'category-b');
    expect(moved.updatedAt, 30);
    expect(moved.createdAt, 10);
    expect(await dao.live(), [moved]);
    expect(await dao.liveAt('hafs:2:5'), moved);
    expect(await dao.liveAt('hafs:2:6'), isNull);
    expect(await dao.byId(first.id), moved);
  });

  test('writeCategory changes a live bookmark only', () async {
    final row = await dao.place('hafs:2:5', 'category-a', at: 10);

    expect(await dao.writeCategory(row.id, 'category-b', at: 20), isTrue);
    expect((await dao.byId(row.id))!.categoryId, 'category-b');
    expect(await dao.writeCategory('absent', 'category-b', at: 20), isFalse);
    await dao.markDeleted(row.id, at: 30);
    expect(await dao.writeCategory(row.id, 'category-a', at: 40), isFalse);
  });

  test('markDeleted keeps a tombstone that revive clears', () async {
    final row = await dao.place('hafs:2:5', 'category-a', at: 10);

    expect(await dao.markDeleted(row.id, at: 20), isTrue);
    expect(await dao.markDeleted(row.id, at: 30), isFalse);
    expect(await dao.live(), isEmpty);
    expect(await dao.liveAt('hafs:2:5'), isNull);
    final tombstone = (await dao.byId(row.id))!;
    expect(tombstone.deleted, isTrue);
    expect(tombstone.updatedAt, 20);

    expect(await dao.revive(row.id, at: 40), isTrue);
    expect((await dao.byId(row.id))!.deleted, isFalse);
    expect((await dao.byId(row.id))!.updatedAt, 40);
    expect(await dao.revive('absent', at: 50), isFalse);
  });

  test('revive refuses when the ayah has another live bookmark', () async {
    final old = await dao.place('hafs:2:5', 'category-a', at: 10);
    await dao.markDeleted(old.id, at: 20);
    final current = await dao.place('hafs:2:5', 'category-b', at: 30);

    expect(current.id, isNot(old.id));
    expect(await dao.revive(old.id, at: 40), isFalse);
    expect((await dao.byId(old.id))!.deleted, isTrue);
  });

  test('writeTags adds, removes with a tombstone and revives pairs', () async {
    final tags = TagDao(db);
    final alpha = await tags.named('tag-alpha', at: 1);
    final beta = await tags.named('tag-beta', at: 1);
    final row = await dao.place('hafs:2:5', 'category-a', at: 10);

    expect(await dao.writeTags(row.id, {alpha.id, beta.id}, at: 20), isTrue);
    expect(await tagsOf(row.id), {alpha.id, beta.id});

    await dao.writeTags(row.id, {beta.id}, at: 30);
    expect(await tagsOf(row.id), {beta.id});
    final pairs = await db.select(db.bookmarkTag).get();
    expect(pairs, hasLength(2));
    final removed = pairs.singleWhere((p) => p.tagId == alpha.id);
    expect(removed.deleted, isTrue);
    expect(removed.updatedAt, 30);

    await dao.writeTags(row.id, {alpha.id, beta.id}, at: 40);
    expect(await tagsOf(row.id), {alpha.id, beta.id});
    expect(await db.select(db.bookmarkTag).get(), hasLength(2));
  });

  test(
    'writeTags leaves pairs of a deleted tag and skips a dead bookmark',
    () async {
      final tags = TagDao(db);
      final alpha = await tags.named('tag-alpha', at: 1);
      final row = await dao.place('hafs:2:5', 'category-a', at: 10);
      await dao.writeTags(row.id, {alpha.id}, at: 20);
      await tags.markDeleted(alpha.id, at: 30);

      expect(await tagsOf(row.id), isEmpty);
      await dao.writeTags(row.id, {}, at: 40);
      await tags.revive(alpha.id, at: 50);
      expect(await tagsOf(row.id), {alpha.id});

      await dao.markDeleted(row.id, at: 60);
      expect(await dao.writeTags(row.id, {}, at: 70), isFalse);
      expect(await dao.writeTags('absent', {alpha.id}, at: 70), isFalse);
      expect(await tagsOf(row.id), {alpha.id});
    },
  );

  test('liveTags pairs every bookmark with its live tags', () async {
    final tags = TagDao(db);
    final alpha = await tags.named('tag-alpha', at: 1);
    final a = await dao.place('hafs:2:5', 'category-a', at: 10);
    final b = await dao.place('hafs:2:6', 'category-a', at: 10);
    await dao.writeTags(a.id, {alpha.id}, at: 20);
    await dao.writeTags(b.id, {alpha.id}, at: 20);

    expect([
      for (final (id, tag) in await dao.liveTags()) (id, tag.name),
    ], unorderedEquals([(a.id, 'tag-alpha'), (b.id, 'tag-alpha')]));
  });
}
