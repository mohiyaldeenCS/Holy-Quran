import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/daos/bookmark_dao.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends BookmarkDao {
  _FailingDao(super.attachedDatabase);

  static const _failure = FormatException('synthetic failure');

  @override
  Future<List<BookmarkRow>> live() async => throw _failure;

  @override
  Future<BookmarkRow?> liveAt(String address) async => throw _failure;

  @override
  Future<BookmarkRow?> byId(String id) async => throw _failure;

  @override
  Future<BookmarkRow> place(
    String address,
    String categoryId, {
    required int at,
  }) async => throw _failure;

  @override
  Future<bool> markDeleted(String id, {required int at}) async =>
      throw _failure;

  @override
  Future<bool> writeCategory(
    String id,
    String categoryId, {
    required int at,
  }) async => throw _failure;

  @override
  Future<bool> writeTags(
    String id,
    Set<String> tagIds, {
    required int at,
  }) async => throw _failure;
}

QuranAddress _ayah(String source) => QuranAddress.parse(source);

T _value<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late int clock;
  late LocalBookmarkRepository bookmarks;
  late LocalTagRepository tags;
  late int notified;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    clock = 1000;
    bookmarks = LocalBookmarkRepository(BookmarkDao(db), now: () => clock);
    tags = LocalTagRepository(TagDao(db), now: () => clock);
    notified = 0;
    bookmarks.addListener(() => notified++);
  });
  tearDown(() => db.close());

  Future<Bookmark> add(String ayah, [String category = 'category-a']) async =>
      _value(await bookmarks.add(_ayah(ayah), category));

  Future<List<Bookmark>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) async => _value(
    await bookmarks.list(
      order: order,
      categoryId: categoryId,
      tagId: tagId,
      query: query,
    ),
  );

  test('adds a bookmark on an ayah and notifies', () async {
    final bookmark = await add('hafs:2:5');

    expect(bookmark.address, _ayah('hafs:2:5'));
    expect(bookmark.categoryId, 'category-a');
    expect(bookmark.tagIds, isEmpty);
    expect(bookmark.createdAt, DateTime.utc(1970, 1, 1, 0, 0, 1));
    expect(bookmark.updatedAt, bookmark.createdAt);
    expect(notified, 1);
    expect(await list(), [bookmark]);
    expect(_value(await bookmarks.bookmarkAt(_ayah('hafs:2:5'))), bookmark);
    expect(_value(await bookmarks.bookmarkAt(_ayah('hafs:2:6'))), isNull);
  });

  test('keeps one bookmark per ayah, changing its category', () async {
    final first = await add('hafs:2:5');
    clock = 2000;
    final second = await add('hafs:2:5', 'category-b');

    expect(second.id, first.id);
    expect(second.categoryId, 'category-b');
    expect(second.createdAt, first.createdAt);
    expect(second.updatedAt, DateTime.utc(1970, 1, 1, 0, 0, 2));
    expect(await list(), [second]);
  });

  test('refuses a word address', () {
    expect(
      () => bookmarks.add(_ayah('hafs:2:5:1'), 'category-a'),
      throwsArgumentError,
    );
    expect(
      () => bookmarks.bookmarkAt(_ayah('hafs:2:5:1')),
      throwsArgumentError,
    );
  });

  test('lists the bookmarked ayat', () async {
    await add('hafs:2:5');
    await add('hafs:3:1');

    expect(_value(await bookmarks.bookmarkedAyat()), {
      _ayah('hafs:2:5'),
      _ayah('hafs:3:1'),
    });
  });

  test('changes the category and the tags', () async {
    final bookmark = await add('hafs:2:5');
    final alpha = _value(await tags.create('tag-alpha'));
    final beta = _value(await tags.create('tag-beta'));

    expect(
      await bookmarks.setCategory(bookmark.id, 'category-b'),
      isA<Ok<void>>(),
    );
    expect(
      await bookmarks.setTags(bookmark.id, {alpha.id, beta.id}),
      isA<Ok<void>>(),
    );
    expect(notified, 3);
    final [changed] = await list();
    expect(changed.categoryId, 'category-b');
    expect(changed.tagIds, {alpha.id, beta.id});

    await bookmarks.setTags(bookmark.id, {beta.id});
    expect(_value(await bookmarks.bookmarkAt(_ayah('hafs:2:5')))!.tagIds, {
      beta.id,
    });
  });

  test('fails to change a bookmark that is absent or deleted', () async {
    final bookmark = await add('hafs:2:5');
    await bookmarks.delete(bookmark.id);
    notified = 0;

    for (final result in [
      await bookmarks.setCategory('absent', 'category-b'),
      await bookmarks.setTags('absent', {}),
      await bookmarks.setCategory(bookmark.id, 'category-b'),
      await bookmarks.setTags(bookmark.id, {}),
      await bookmarks.delete(bookmark.id),
      await bookmarks.restore('absent'),
    ]) {
      expect((result as Failure).error, isA<ItemNotFound>());
    }
    expect(notified, 0);
  });

  group('lists', () {
    late Bookmark first;
    late Bookmark second;
    late Bookmark third;
    late String alpha;
    late String beta;

    setUp(() async {
      alpha = _value(await tags.create('tag-alpha')).id;
      beta = _value(await tags.create('tag-beta')).id;
      first = await add('hafs:3:1');
      clock = 2000;
      second = await add('hafs:2:7', 'category-b');
      clock = 3000;
      third = await add('hafs:2:5');
      await bookmarks.setTags(first.id, {alpha});
      await bookmarks.setTags(second.id, {alpha, beta});
      first = _value(await bookmarks.bookmarkAt(first.address))!;
      second = _value(await bookmarks.bookmarkAt(second.address))!;
    });

    test('newest first or in mushaf order', () async {
      expect(await list(), [third, second, first]);
      expect(await list(order: ListOrder.mushaf), [third, second, first]);
      await add('hafs:1:1');
      expect((await list(order: ListOrder.mushaf)).map((b) => '${b.address}'), [
        'hafs:1:1',
        'hafs:2:5',
        'hafs:2:7',
        'hafs:3:1',
      ]);
    });

    test('filtered by category and by tag', () async {
      expect(await list(categoryId: 'category-a'), [third, first]);
      expect(await list(categoryId: 'category-b'), [second]);
      expect(await list(tagId: alpha), [second, first]);
      expect(await list(tagId: beta), [second]);
      expect(await list(categoryId: 'category-a', tagId: beta), isEmpty);
    });

    test('searched in tag names', () async {
      expect(await list(query: 'beta'), [second]);
      expect(await list(query: 'tag-'), [second, first]);
      expect(await list(query: 'absent'), isEmpty);
      expect(await list(), hasLength(3), reason: 'an empty query');
    });

    test('hide a deleted tag until it is restored', () async {
      await tags.delete(alpha);

      expect(await list(tagId: alpha), isEmpty);
      expect(await list(query: 'alpha'), isEmpty);
      expect((await list(tagId: beta)).single.tagIds, {beta});

      await tags.restore(alpha);
      expect(await list(tagId: alpha), [second, first]);
    });
  });

  test('a deletion is undone within the window, then stays', () async {
    final kept = await add('hafs:2:5');
    final lost = await add('hafs:2:6');
    clock = 5000;
    await bookmarks.delete(kept.id);
    await bookmarks.delete(lost.id);

    expect(await list(), isEmpty);
    expect(_value(await bookmarks.bookmarkedAyat()), isEmpty);
    expect(await db.select(db.bookmark).get(), hasLength(2));

    clock = 5000 + undoWindow.inMilliseconds;
    notified = 0;
    expect(await bookmarks.restore(kept.id), isA<Ok<void>>());
    expect(notified, 1);
    expect(await bookmarks.restore(kept.id), isA<Ok<void>>());
    expect(notified, 1, reason: 'restoring a live bookmark changes nothing');

    clock++;
    final late = await bookmarks.restore(lost.id);
    expect((late as Failure).error, isA<UndoExpired>());

    expect((await list()).map((b) => b.id), [kept.id]);
    final tombstone = (await BookmarkDao(db).byId(lost.id))!;
    expect(tombstone.deleted, isTrue);
    expect(tombstone.updatedAt, 5000);
  });

  test('a restore fails when the ayah was bookmarked since', () async {
    final old = await add('hafs:2:5');
    await bookmarks.delete(old.id);
    final current = await add('hafs:2:5', 'category-b');

    notified = 0;
    final result = await bookmarks.restore(old.id);

    expect((result as Failure).error, isA<AyahAlreadyBookmarked>());
    expect(notified, 0);
    expect(await list(), [current]);
  });

  test('a stored address that is not an ayah address is skipped', () async {
    await add('hafs:2:5');
    for (final (index, address) in ['hafs:2:5:1', 'not an address'].indexed) {
      await db
          .into(db.bookmark)
          .insert(
            BookmarkRow(
              id: 'stored-$index',
              updatedAt: 1,
              deleted: false,
              address: address,
              categoryId: 'category-a',
              createdAt: 1,
            ),
          );
    }

    expect(await list(), hasLength(1));
    expect(_value(await bookmarks.bookmarkedAyat()), {_ayah('hafs:2:5')});
  });

  test('a failing database returns Failures and does not notify', () async {
    final failing = LocalBookmarkRepository(_FailingDao(db));
    var heard = 0;
    failing.addListener(() => heard++);

    expect(await failing.add(_ayah('hafs:2:5'), 'c'), isA<Failure<Bookmark>>());
    expect(
      await failing.bookmarkAt(_ayah('hafs:2:5')),
      isA<Failure<Bookmark?>>(),
    );
    expect(await failing.bookmarkedAyat(), isA<Failure<Set<QuranAddress>>>());
    expect(await failing.list(), isA<Failure<List<Bookmark>>>());
    expect(await failing.setCategory('a', 'c'), isA<Failure<void>>());
    expect(await failing.setTags('a', {'t'}), isA<Failure<void>>());
    expect(await failing.delete('a'), isA<Failure<void>>());
    expect(await failing.restore('a'), isA<Failure<void>>());
    expect(heard, 0);
  });

  test('bookmarks survive closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('bookmark_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final tag = _value(await LocalTagRepository(TagDao(first)).create('tag-a'));
    final stored = LocalBookmarkRepository(BookmarkDao(first));
    final bookmark = _value(await stored.add(_ayah('hafs:18:10'), 'c'));
    await stored.setTags(bookmark.id, {tag.id});
    final gone = _value(await stored.add(_ayah('hafs:18:11'), 'c'));
    await stored.delete(gone.id);
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final [reread] = _value(
      await LocalBookmarkRepository(BookmarkDao(second)).list(),
    );
    expect(reread.id, bookmark.id);
    expect(reread.address, _ayah('hafs:18:10'));
    expect(reread.tagIds, {tag.id});
  });
}
