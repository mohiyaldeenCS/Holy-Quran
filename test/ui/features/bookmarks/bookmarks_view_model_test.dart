import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/bookmarks_view_model.dart';

import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('bookmarks_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  late BookmarksWorld world;
  setUp(() => world = BookmarksWorld(fixture));

  BookmarksViewModel make({
    bool withPack = true,
    Duration undoShown = const Duration(minutes: 1),
  }) {
    final viewModel = BookmarksViewModel(
      bookmarks: world.bookmarks,
      notes: world.notes,
      tags: world.tags,
      categories: world.categories,
      text: withPack ? fixture.text : null,
      index: withPack ? fixture.index : null,
      undoShown: undoShown,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Future<void> settle() => pumpEventQueue();

  List<QuranAddress> addresses(BookmarksViewModel viewModel) => [
    for (final entry in viewModel.entries) entry.address,
  ];

  test('lists bookmarks newest first, or in the order of the mushaf', () async {
    final late = world.ayah(2, 5);
    final early = world.ayah(1, 3);
    final middle = world.ayah(1, 6);
    await world.bookmark(late);
    await world.bookmark(early);
    await world.bookmark(middle);
    final viewModel = make();
    await settle();

    expect(viewModel.loaded, isTrue);
    expect(addresses(viewModel), [middle, early, late]);

    viewModel.selectOrder(ListOrder.mushaf);
    await settle();
    expect(addresses(viewModel), [early, middle, late]);
  });

  test('gives each entry the ayah and the surah name from the pack', () async {
    await world.bookmark(world.ayah(1, 3));
    final viewModel = make();
    await settle();

    final entry = viewModel.entries.single;
    expect(entry.ayahText, isNotNull);
    expect(entry.surahName, fixture.surahs.first.name);
    expect(entry.note, isNull);
  });

  test('has no ayah and no name without a base pack', () async {
    await world.bookmark(world.ayah(1, 3));
    final viewModel = make(withPack: false);
    await settle();

    expect(viewModel.entries, hasLength(1));
    expect(viewModel.entries.single.ayahText, isNull);
    expect(viewModel.entries.single.surahName, isNull);
  });

  test('filters by category and by tag', () async {
    final tag = await world.makeTag('وسم تجريبي');
    await world.bookmark(world.ayah(1, 1), category: 'fake-review');
    await world.bookmark(world.ayah(1, 2), tagIds: {tag.id});
    await world.bookmark(world.ayah(1, 3));
    final viewModel = make();
    await settle();
    expect(viewModel.entries, hasLength(3));
    expect(viewModel.narrowed, isFalse);

    viewModel.toggleCategory('fake-memorise');
    await settle();
    expect(addresses(viewModel), [world.ayah(1, 3), world.ayah(1, 2)]);
    expect(viewModel.narrowed, isTrue);

    viewModel.toggleTag(tag.id);
    await settle();
    expect(addresses(viewModel), [world.ayah(1, 2)]);

    viewModel
      ..toggleTag(tag.id)
      ..toggleCategory('fake-memorise');
    await settle();
    expect(viewModel.entries, hasLength(3));
  });

  test(
    'searches the tags of bookmarks and the text and tags of notes',
    () async {
      final tag = await world.makeTag('وسم تجريبي');
      await world.bookmark(world.ayah(1, 1), tagIds: {tag.id});
      await world.bookmark(world.ayah(1, 2));
      await world.note(world.ayah(1, 3), 'نص تجريبي');
      await world.note(world.ayah(1, 4), 'كلام آخر', tagIds: {tag.id});
      final viewModel = make();
      await settle();

      viewModel.search('تجريبي');
      await settle();
      expect(addresses(viewModel), [world.ayah(1, 1)]);

      viewModel.selectTab(AnnotationTab.notes);
      await settle();
      expect(addresses(viewModel).toSet(), {
        world.ayah(1, 3),
        world.ayah(1, 4),
      });
      expect(
        viewModel.entries.map((entry) => entry.note),
        containsAll(['نص تجريبي', 'كلام آخر']),
      );

      viewModel.search('');
      await settle();
      expect(viewModel.narrowed, isFalse);
    },
  );

  test('lists several notes on one ayah as separate entries', () async {
    final at = world.ayah(1, 2);
    await world.note(at, 'نص تجريبي');
    await world.note(at, 'نص تجريبي ثان');
    final viewModel = make()..selectTab(AnnotationTab.notes);
    await settle();

    expect(viewModel.entries, hasLength(2));
    expect({for (final entry in viewModel.entries) entry.id}, hasLength(2));
  });

  test('shows only the tab chosen, never the other one\'s cards', () async {
    await world.bookmark(world.ayah(1, 1));
    final viewModel = make();
    await settle();
    expect(viewModel.entries, hasLength(1));

    viewModel.selectTab(AnnotationTab.notes);
    expect(viewModel.entries, isEmpty);
    expect(viewModel.loaded, isFalse);
    await settle();
    expect(viewModel.entries, isEmpty);
    expect(viewModel.loaded, isTrue);
  });

  test('deletes a bookmark and undoes it', () async {
    await world.bookmark(world.ayah(1, 1));
    final viewModel = make();
    await settle();

    await viewModel.delete(viewModel.entries.single);
    await settle();
    expect(viewModel.entries, isEmpty);
    expect(viewModel.canUndo, isTrue);

    await viewModel.undo();
    await settle();
    expect(viewModel.entries, hasLength(1));
    expect(viewModel.canUndo, isFalse);
    expect(viewModel.writeFailed, isFalse);
  });

  test('deletes a note and undoes it', () async {
    await world.note(world.ayah(1, 1), 'نص تجريبي');
    final viewModel = make()..selectTab(AnnotationTab.notes);
    await settle();

    await viewModel.delete(viewModel.entries.single);
    await settle();
    expect(viewModel.entries, isEmpty);

    await viewModel.undo();
    await settle();
    expect(viewModel.entries.single.note, 'نص تجريبي');
  });

  test('stops offering the undo once its time is up', () async {
    await world.bookmark(world.ayah(1, 1));
    final viewModel = make(undoShown: const Duration(milliseconds: 20));
    await settle();

    await viewModel.delete(viewModel.entries.single);
    expect(viewModel.canUndo, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(viewModel.canUndo, isFalse);
    expect(viewModel.entries, isEmpty);
  });

  test('says so when a write fails, and keeps the list', () async {
    await world.bookmark(world.ayah(1, 1));
    final viewModel = make();
    await settle();

    world.bookmarks.failure = Exception('write failed');
    await viewModel.delete(viewModel.entries.single);
    expect(viewModel.writeFailed, isTrue);
    expect(viewModel.canUndo, isFalse);
    world.bookmarks.failure = null;
    viewModel.search('');
    await settle();
    expect(viewModel.entries, hasLength(1));
    expect(viewModel.writeFailed, isFalse);
  });

  test('says so when the list cannot be read', () async {
    world.bookmarks.failure = Exception('read failed');
    final viewModel = make();
    await settle();

    expect(viewModel.failed, isTrue);
    expect(viewModel.entries, isEmpty);
  });

  test('changes the category and the tags of a bookmark', () async {
    final tag = await world.makeTag('وسم تجريبي');
    final made = await world.bookmark(world.ayah(1, 1));
    final viewModel = make();
    await settle();

    await viewModel.setCategory(made.id, 'fake-study');
    await viewModel.setTags(made.id, {tag.id});
    await settle();
    expect(viewModel.entries.single.categoryId, 'fake-study');
    expect(viewModel.entries.single.tagIds, {tag.id});
    expect(viewModel.categoryOf('fake-study'), BuiltinCategory.study);
    expect(viewModel.tagName(tag.id), 'وسم تجريبي');
  });

  test('makes a tag, or finds the one of that name', () async {
    final viewModel = make();
    await settle();

    final first = await viewModel.createTag('وسم تجريبي');
    final again = await viewModel.createTag('وسم تجريبي');
    expect(first, isNotNull);
    expect(again, first);
    await settle();
    expect(viewModel.tags, hasLength(1));
  });

  test('drops the pack names once the pack stops serving', () async {
    await world.bookmark(world.ayah(1, 3));
    final integrity = FakePackIntegrityRepository();
    final viewModel = BookmarksViewModel(
      bookmarks: world.bookmarks,
      notes: world.notes,
      tags: world.tags,
      categories: world.categories,
      text: fixture.text,
      index: fixture.index,
      integrity: integrity,
    );
    addTearDown(viewModel.dispose);
    addTearDown(() => fixture.serving = true);
    await settle();
    expect(viewModel.entries.single.surahName, isNotNull);

    fixture.serving = false;
    integrity.report('synthetic', const IntegrityFailed(PackDisabled('x')));
    await settle();
    expect(viewModel.entries, hasLength(1));
    expect(viewModel.entries.single.surahName, isNull);

    fixture.serving = true;
    integrity.report('synthetic', const IntegrityOk());
    await settle();
    expect(viewModel.entries.single.surahName, isNotNull);
  });
}
