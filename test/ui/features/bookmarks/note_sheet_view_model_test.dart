import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_drafts.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_sheet_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('note_sheet_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  late BookmarksWorld world;
  late NoteDrafts drafts;
  setUp(() {
    world = BookmarksWorld(fixture);
    drafts = NoteDrafts();
  });

  NoteSheetViewModel make({String? initialNoteId, bool withIndex = true}) {
    final viewModel = NoteSheetViewModel(
      address: world.ayah(1, 2),
      notes: world.notes,
      tags: world.tags,
      categories: world.categories,
      index: withIndex ? fixture.index : null,
      initialNoteId: initialNoteId,
      window: const Duration(minutes: 1),
      drafts: drafts,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Future<void> settle() => pumpEventQueue();

  Future<List<Note>> stored() async =>
      ((await world.notes.notesAt(world.ayah(1, 2))) as Ok<List<Note>>).value;

  test('reads the notes of the ayah, the categories and the tags', () async {
    await world.makeTag('وسم تجريبي');
    final first = await world.note(world.ayah(1, 2), 'نص تجريبي');
    await world.note(world.ayah(1, 3), 'نص آخر');
    final viewModel = make();
    await settle();

    expect(viewModel.notes.map((note) => note.id), [first.id]);
    expect(viewModel.categories, hasLength(4));
    expect(viewModel.tags.single.name, 'وسم تجريبي');
    expect(viewModel.editing, isNull);
    expect(viewModel.surahName, fixture.surahs.first.name);
  });

  test('has no surah name without the index', () async {
    final viewModel = make(withIndex: false);
    await settle();
    expect(viewModel.surahName, isNull);
  });

  test('opens on the note it is asked for', () async {
    await world.note(world.ayah(1, 2), 'نص أول');
    final second = await world.note(
      world.ayah(1, 2),
      'نص ثان',
      category: BookmarksWorld.category('study'),
    );
    final viewModel = make(initialNoteId: second.id);
    await settle();

    expect(viewModel.editing?.id, second.id);
    expect(viewModel.body, 'نص ثان');
    expect(viewModel.categoryId, BookmarksWorld.category('study'));
    expect(viewModel.bodyRevision, greaterThan(0));
  });

  test('cannot save an empty note', () async {
    final viewModel = make();
    await settle();

    expect(viewModel.canSave, isFalse);
    expect(await viewModel.save(), isFalse);
    expect(await stored(), isEmpty);
  });

  test('saves a note with its category and tags', () async {
    final tag = await world.makeTag('وسم تجريبي');
    final viewModel = make();
    await settle();

    viewModel
      ..setBody('نص تجريبي')
      ..setCategory(BookmarksWorld.category('review'))
      ..toggleTag(tag.id);
    expect(viewModel.canSave, isTrue);
    expect(await viewModel.save(), isTrue);
    await settle();

    final note = (await stored()).single;
    expect(note.body, 'نص تجريبي');
    expect(note.categoryId, BookmarksWorld.category('review'));
    expect(note.tagIds, {tag.id});
    expect(viewModel.editing?.id, note.id);
  });

  test('keeps several notes on one ayah', () async {
    final viewModel = make();
    await settle();

    viewModel.setBody('نص تجريبي');
    await viewModel.save();
    viewModel.startNew();
    expect(viewModel.editing, isNull);
    expect(viewModel.body, isEmpty);
    viewModel.setBody('نص تجريبي ثان');
    await viewModel.save();
    await settle();

    expect((await stored()).map((note) => note.body), [
      'نص تجريبي',
      'نص تجريبي ثان',
    ]);
    expect(viewModel.notes, hasLength(2));
  });

  test('edits a note in place and can clear its category', () async {
    final made = await world.note(
      world.ayah(1, 2),
      'نص تجريبي',
      category: BookmarksWorld.category('study'),
    );
    final viewModel = make();
    await settle();

    viewModel
      ..select(viewModel.notes.single)
      ..setBody('نص معدل')
      ..setCategory(null);
    await viewModel.save();
    await settle();

    final note = (await stored()).single;
    expect(note.id, made.id);
    expect(note.body, 'نص معدل');
    expect(note.categoryId, isNull);
  });

  test('deletes the note in the editor and brings it back', () async {
    await world.note(world.ayah(1, 2), 'نص تجريبي');
    final viewModel = make();
    await settle();
    viewModel.select(viewModel.notes.single);

    await viewModel.delete();
    await settle();
    expect(await stored(), isEmpty);
    expect(viewModel.editing, isNull);
    expect(viewModel.body, isEmpty);
    expect(viewModel.canUndo, isTrue);

    await viewModel.undo();
    await settle();
    expect((await stored()).single.body, 'نص تجريبي');
    expect(viewModel.notes, hasLength(1));
    expect(viewModel.canUndo, isFalse);
  });

  test('makes a tag and chooses it, once per name', () async {
    final viewModel = make();
    await settle();

    await viewModel.addTag('وسم تجريبي');
    await viewModel.addTag('وسم تجريبي');
    await viewModel.addTag('');
    await settle();

    expect(viewModel.tags, hasLength(1));
    expect(viewModel.tagIds, {viewModel.tags.single.id});
  });

  test('does not store a tag that was deleted meanwhile', () async {
    final tag = await world.makeTag('وسم تجريبي');
    final viewModel = make();
    await settle();
    viewModel
      ..setBody('نص تجريبي')
      ..toggleTag(tag.id);
    await world.tags.delete(tag.id);
    await settle();

    await viewModel.save();
    expect((await stored()).single.tagIds, isEmpty);
  });

  test('says so when a write fails and keeps the draft', () async {
    final viewModel = make();
    await settle();
    viewModel.setBody('نص تجريبي');

    world.notes.failure = Exception('write failed');
    expect(await viewModel.save(), isFalse);
    expect(viewModel.writeFailed, isTrue);
    expect(viewModel.body, 'نص تجريبي');

    world.notes.failure = null;
    expect(await viewModel.save(), isTrue);
    expect(viewModel.writeFailed, isFalse);
  });

  test(
    'opens blank, with its pickers filled, on a note that is gone',
    () async {
      await world.makeTag('وسم تجريبي');
      final viewModel = make(initialNoteId: 'absent');
      await settle();

      expect(viewModel.editing, isNull);
      expect(viewModel.categories, hasLength(4));
      expect(viewModel.tags, hasLength(1));
    },
  );

  test(
    'a second save before the first is stored makes no second note',
    () async {
      final viewModel = make();
      await settle();
      viewModel.setBody('نص تجريبي');

      final first = viewModel.save();
      expect(viewModel.canSave, isFalse);
      final second = viewModel.save();
      expect(await second, isFalse);
      expect(await first, isTrue);
      await settle();

      expect(await stored(), hasLength(1));
      expect(viewModel.canSave, isTrue);
    },
  );

  test('cannot save a note of whitespace alone', () async {
    final viewModel = make();
    await settle();

    viewModel.setBody('   ');
    expect(viewModel.canSave, isFalse);
    expect(await viewModel.save(), isFalse);
    expect(await stored(), isEmpty);

    viewModel.setBody(' نص تجريبي ');
    expect(viewModel.canSave, isTrue);
    await viewModel.save();
    expect((await stored()).single.body, ' نص تجريبي ');
  });

  test('knows a tag it made at once, even when tags cannot be read', () async {
    final tags = _TagsThatCannotBeRead();
    final viewModel = NoteSheetViewModel(
      address: world.ayah(1, 2),
      notes: world.notes,
      tags: tags,
      categories: world.categories,
      drafts: drafts,
    );
    addTearDown(viewModel.dispose);
    await settle();

    await viewModel.addTag('وسم تجريبي');
    expect(viewModel.tags.single.name, 'وسم تجريبي');
    viewModel.setBody('نص تجريبي');
    expect(await viewModel.save(), isTrue);
    expect((await stored()).single.tagIds, {viewModel.tags.single.id});
  });

  test('cannot switch notes while the text would be lost', () async {
    final first = await world.note(world.ayah(1, 2), 'نص أول');
    final second = await world.note(world.ayah(1, 2), 'نص ثان');
    final viewModel = make(initialNoteId: first.id);
    await settle();
    expect(viewModel.canSwitch, isTrue);

    viewModel.setBody('نص معدل');
    expect(viewModel.dirty, isTrue);
    expect(viewModel.canSwitch, isFalse);
    viewModel
      ..select(viewModel.notes.last)
      ..startNew();
    expect(viewModel.editing?.id, first.id);
    expect(viewModel.body, 'نص معدل');

    viewModel.setBody('نص أول');
    expect(viewModel.canSwitch, isTrue);
    viewModel.select(viewModel.notes.last);
    expect(viewModel.editing?.id, second.id);
  });

  test('cannot leave a new note that has text', () async {
    await world.note(world.ayah(1, 2), 'نص أول');
    final viewModel = make();
    await settle();
    expect(viewModel.canSwitch, isTrue);

    viewModel.setBody('نص جديد');
    expect(viewModel.canSwitch, isFalse);
    viewModel.select(viewModel.notes.single);
    expect(viewModel.editing, isNull);
  });

  test('keeps the unsaved text for the ayah and brings it back', () async {
    final first = make();
    await settle();
    first
      ..setBody('نص غير محفوظ')
      ..setCategory(BookmarksWorld.category('study'))
      ..dispose();
    expect(await stored(), isEmpty);

    final second = make();
    await settle();
    expect(second.body, 'نص غير محفوظ');
    expect(second.categoryId, BookmarksWorld.category('study'));
    expect(second.dirty, isTrue);

    expect(await second.save(), isTrue);
    second.dispose();
    final third = make();
    await settle();
    expect(third.body, isEmpty);
    expect((await stored()).single.body, 'نص غير محفوظ');
  });

  test('keeps the unsaved text of one note apart from a new note', () async {
    final made = await world.note(world.ayah(1, 2), 'نص أول');
    final first = make(initialNoteId: made.id);
    await settle();
    first
      ..setBody('نص معدل')
      ..dispose();

    final again = make(initialNoteId: made.id);
    await settle();
    expect(again.body, 'نص معدل');
    expect((await stored()).single.body, 'نص أول');

    final blank = make();
    await settle();
    expect(blank.body, isEmpty);
  });

  test('forgets the text once it is back to the stored note', () async {
    final made = await world.note(world.ayah(1, 2), 'نص أول');
    final first = make(initialNoteId: made.id);
    await settle();
    first
      ..setBody('نص معدل')
      ..setBody('نص أول')
      ..dispose();

    expect(drafts.of(world.ayah(1, 2), made.id), isNull);
  });

  test(
    'holds the undo past the window, and the next action drops it',
    () async {
      final made = await world.note(world.ayah(1, 2), 'نص تجريبي');
      final viewModel = NoteSheetViewModel(
        address: world.ayah(1, 2),
        notes: world.notes,
        tags: world.tags,
        categories: world.categories,
        window: const Duration(milliseconds: 20),
        drafts: drafts,
        initialNoteId: made.id,
      )..holdUndo = true;
      addTearDown(viewModel.dispose);
      await settle();
      await viewModel.delete();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(viewModel.canUndo, isTrue);

      viewModel.startNew();
      expect(viewModel.canUndo, isFalse);
    },
  );
}

/// A tag repository that makes tags but cannot list them.
final class _TagsThatCannotBeRead extends TagRepository {
  final _made = <String, UserTag>{};

  @override
  Future<Result<List<UserTag>>> tags() async =>
      Failure(Exception('unreadable'));

  @override
  Future<Result<UserTag>> create(String name) async {
    final tag = UserTag(
      id: 'tag-${_made.length}',
      name: name,
      createdAt: DateTime.utc(2026),
    );
    _made[tag.id] = tag;
    notifyListeners();
    return Ok(tag);
  }

  @override
  Future<Result<void>> rename(String id, String name) async => const Ok(null);

  @override
  Future<Result<void>> delete(String id) async => const Ok(null);

  @override
  Future<Result<void>> restore(String id) async => const Ok(null);
}
