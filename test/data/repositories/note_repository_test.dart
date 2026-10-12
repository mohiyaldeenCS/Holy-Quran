import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/daos/note_dao.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends NoteDao {
  _FailingDao(super.attachedDatabase);

  static const _failure = FormatException('synthetic failure');

  @override
  Future<List<NoteRow>> live() async => throw _failure;

  @override
  Future<List<NoteRow>> liveAt(String address) async => throw _failure;

  @override
  Future<NoteRow?> byId(String id) async => throw _failure;

  @override
  Future<NoteRow> add(
    String address,
    String body, {
    required String? categoryId,
    required Set<String> tagIds,
    required int at,
  }) async => throw _failure;

  @override
  Future<bool> edit(
    String id, {
    required String body,
    required String? categoryId,
    required Set<String> tagIds,
    required int at,
  }) async => throw _failure;

  @override
  Future<bool> markDeleted(String id, {required int at}) async =>
      throw _failure;
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
  late LocalNoteRepository notes;
  late LocalTagRepository tags;
  late int notified;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    clock = 1000;
    notes = LocalNoteRepository(NoteDao(db), now: () => clock);
    tags = LocalTagRepository(TagDao(db), now: () => clock);
    notified = 0;
    notes.addListener(() => notified++);
  });
  tearDown(() => db.close());

  Future<Note> add(
    String ayah,
    String body, {
    String? categoryId,
    Set<String> tagIds = const {},
  }) async => _value(
    await notes.add(_ayah(ayah), body, categoryId: categoryId, tagIds: tagIds),
  );

  Future<List<Note>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) async => _value(
    await notes.list(
      order: order,
      categoryId: categoryId,
      tagId: tagId,
      query: query,
    ),
  );

  test('adds several notes on one ayah and notifies', () async {
    final alpha = _value(await tags.create('tag-alpha'));
    final first = await add(
      'hafs:2:5',
      'synthetic note one',
      categoryId: 'category-a',
      tagIds: {alpha.id},
    );
    clock = 2000;
    final second = await add('hafs:2:5', 'synthetic note two');

    expect(first.body, 'synthetic note one');
    expect(first.categoryId, 'category-a');
    expect(first.tagIds, {alpha.id});
    expect(second.categoryId, isNull);
    expect(notified, 2);
    expect(_value(await notes.notesAt(_ayah('hafs:2:5'))), [first, second]);
    expect(_value(await notes.notesAt(_ayah('hafs:2:6'))), isEmpty);
    expect(_value(await notes.annotatedAyat()), {_ayah('hafs:2:5')});
  });

  test('refuses an empty body and a word address', () async {
    final result = await notes.add(_ayah('hafs:2:5'), '');

    expect((result as Failure).error, isA<FormatException>());
    expect(notified, 0);
    expect(await list(), isEmpty);
    expect(() => notes.add(_ayah('hafs:2:5:1'), 'x'), throwsArgumentError);
    expect(() => notes.notesAt(_ayah('hafs:2:5:1')), throwsArgumentError);
  });

  test('edits body, category and tags, and can clear the category', () async {
    final alpha = _value(await tags.create('tag-alpha'));
    final note = await add(
      'hafs:2:5',
      'synthetic note body',
      categoryId: 'category-a',
    );
    clock = 2000;

    expect(
      await notes.edit(
        note.id,
        body: 'edited synthetic body',
        categoryId: null,
        tagIds: {alpha.id},
      ),
      isA<Ok<void>>(),
    );
    final [edited] = await list();
    expect(edited.body, 'edited synthetic body');
    expect(edited.categoryId, isNull);
    expect(edited.tagIds, {alpha.id});
    expect(edited.createdAt, note.createdAt);
    expect(edited.updatedAt, DateTime.utc(1970, 1, 1, 0, 0, 2));
    expect(notified, 2);
  });

  test('fails to edit an empty body or a note that is not live', () async {
    final note = await add('hafs:2:5', 'synthetic note body');
    final empty = await notes.edit(
      note.id,
      body: '',
      categoryId: null,
      tagIds: {},
    );
    final absent = await notes.edit(
      'absent',
      body: 'x',
      categoryId: null,
      tagIds: {},
    );
    await notes.delete(note.id);
    final deleted = await notes.edit(
      note.id,
      body: 'x',
      categoryId: null,
      tagIds: {},
    );

    expect((empty as Failure).error, isA<FormatException>());
    expect((absent as Failure).error, isA<ItemNotFound>());
    expect((deleted as Failure).error, isA<ItemNotFound>());
    expect((await notes.delete(note.id) as Failure).error, isA<ItemNotFound>());
    expect(
      (await notes.restore('absent') as Failure).error,
      isA<ItemNotFound>(),
    );
  });

  group('lists', () {
    late Note first;
    late Note second;
    late Note third;
    late String alpha;
    late String beta;

    setUp(() async {
      alpha = _value(await tags.create('tag-alpha')).id;
      beta = _value(await tags.create('tag-beta')).id;
      first = await add(
        'hafs:3:1',
        'synthetic body one',
        categoryId: 'category-a',
        tagIds: {alpha},
      );
      clock = 2000;
      second = await add(
        'hafs:2:7',
        'synthetic body two',
        categoryId: 'category-b',
        tagIds: {alpha, beta},
      );
      clock = 3000;
      third = await add('hafs:2:7', 'synthetic body three');
    });

    test('newest first or in mushaf order', () async {
      expect(await list(), [third, second, first]);
      expect(await list(order: ListOrder.mushaf), [second, third, first]);
    });

    test('filtered by category and by tag', () async {
      expect(await list(categoryId: 'category-a'), [first]);
      expect(await list(categoryId: 'category-b'), [second]);
      expect(await list(tagId: alpha), [second, first]);
      expect(await list(tagId: beta), [second]);
    });

    test('searched in bodies and tag names, as typed', () async {
      expect(await list(query: 'body t'), [third, second]);
      expect(await list(query: 'Body'), isEmpty);
      expect(await list(query: 'beta'), [second]);
      expect(await list(query: 'tag-'), [second, first]);
      expect(await list(), hasLength(3), reason: 'an empty query');
    });

    test('hide a deleted tag until it is restored', () async {
      await tags.delete(beta);

      expect(await list(tagId: beta), isEmpty);
      expect(await list(query: 'beta'), isEmpty);
      expect(_value(await notes.notesAt(_ayah('hafs:2:7'))).first.tagIds, {
        alpha,
      });

      await tags.restore(beta);
      expect(await list(tagId: beta), [second]);
    });
  });

  test('a deletion is undone within the window, then stays', () async {
    final kept = await add('hafs:2:5', 'synthetic kept');
    final lost = await add('hafs:2:5', 'synthetic lost');
    clock = 5000;
    await notes.delete(kept.id);
    await notes.delete(lost.id);

    expect(await list(), isEmpty);
    expect(_value(await notes.notesAt(_ayah('hafs:2:5'))), isEmpty);
    expect(_value(await notes.annotatedAyat()), isEmpty);

    clock = 5000 + undoWindow.inMilliseconds;
    expect(await notes.restore(kept.id), isA<Ok<void>>());
    notified = 0;
    expect(await notes.restore(kept.id), isA<Ok<void>>());
    expect(notified, 0, reason: 'restoring a live note changes nothing');
    clock++;
    final late = await notes.restore(lost.id);

    expect((late as Failure).error, isA<UndoExpired>());
    expect((await list()).map((n) => n.id), [kept.id]);
    expect((await NoteDao(db).byId(lost.id))!.deleted, isTrue);
  });

  test('a stored address that is not an ayah address is skipped', () async {
    await db
        .into(db.note)
        .insert(
          const NoteRow(
            id: 'stored',
            updatedAt: 1,
            deleted: false,
            address: 'hafs:2:5:1',
            body: 'synthetic',
            createdAt: 1,
          ),
        );

    expect(await list(), isEmpty);
    expect(_value(await notes.annotatedAyat()), isEmpty);
  });

  test('a failing database returns Failures and does not notify', () async {
    final failing = LocalNoteRepository(_FailingDao(db));
    var heard = 0;
    failing.addListener(() => heard++);

    expect(await failing.add(_ayah('hafs:2:5'), 'x'), isA<Failure<Note>>());
    expect(
      await failing.edit('a', body: 'x', categoryId: null, tagIds: {}),
      isA<Failure<void>>(),
    );
    expect(
      await failing.notesAt(_ayah('hafs:2:5')),
      isA<Failure<List<Note>>>(),
    );
    expect(await failing.annotatedAyat(), isA<Failure<Set<QuranAddress>>>());
    expect(await failing.list(), isA<Failure<List<Note>>>());
    expect(await failing.delete('a'), isA<Failure<void>>());
    expect(await failing.restore('a'), isA<Failure<void>>());
    expect(heard, 0);
  });

  test('notes survive closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('note_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final tag = _value(await LocalTagRepository(TagDao(first)).create('tag-a'));
    final note = _value(
      await LocalNoteRepository(NoteDao(first)).add(
        _ayah('hafs:18:10'),
        'synthetic kept body',
        categoryId: 'category-a',
        tagIds: {tag.id},
      ),
    );
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(_value(await LocalNoteRepository(NoteDao(second)).list()), [note]);
  });
}
