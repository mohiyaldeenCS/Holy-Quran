import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';

import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'index_fixture.dart';

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('index_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  IndexViewModel model({FakeReadingPositionRepository? positions}) {
    final model = IndexViewModel(index: fixture.index, positions: positions);
    addTearDown(model.dispose);
    return model;
  }

  test('counts the surahs and the juz from the pack', () {
    final m = model();
    expect(m.hasData, isTrue);
    expect(m.surahCount, fixture.surahs.length);
    expect(m.juzCount, fixture.index.count(Division.juz));
  });

  test('lists every surah with its page and first ayah', () {
    final rows = model().surahRows;
    expect(rows.map((row) => row.info.number), [
      for (final surah in fixture.surahs) surah.number,
    ]);
    for (final row in rows) {
      expect(row.page, fixture.index.firstPage(row.info.number));
      expect(
        row.address,
        QuranAddress(fixture.index.riwaya, row.info.number, 1),
      );
      expect(row.info.name, fixture.surahs[row.info.number - 1].name);
    }
  });

  test('marks the surah of the last position read', () {
    final positions = FakeReadingPositionRepository(
      last: QuranAddress(fixture.index.riwaya, 2, 5),
    );
    final m = model(positions: positions);
    expect(
      [for (final row in m.surahRows) row.lastRead],
      [for (final surah in fixture.surahs) surah.number == 2],
    );
  });

  test('marks no surah without a position, or one of another riwaya', () {
    expect(model().surahRows.where((row) => row.lastRead), isEmpty);
    final other = FakeReadingPositionRepository(
      last: QuranAddress('warsh', 2, 1),
    );
    expect(
      model(positions: other).surahRows.where((row) => row.lastRead),
      isEmpty,
    );
  });

  test('moves the badge when the position changes', () async {
    final positions = FakeReadingPositionRepository(
      last: QuranAddress(fixture.index.riwaya, 1, 1),
    );
    final m = model(positions: positions);
    var notified = 0;
    m.addListener(() => notified++);
    await positions.save(QuranAddress(fixture.index.riwaya, 3, 2));
    expect(notified, 1);
    expect(m.surahRows.singleWhere((row) => row.lastRead).info.number, 3);
  });

  test('lists every juz with its first ayah, page and surah name', () {
    final rows = model().juzRows;
    final entries = fixture.index.divisions(Division.juz);
    expect(rows.length, entries.length);
    for (final (row, entry) in [
      for (var i = 0; i < rows.length; i++) (rows[i], entries[i]),
    ]) {
      expect(row.number, entry.number);
      expect(row.address, entry.firstAyah);
      expect(row.page, entry.firstPage);
      expect(row.surahName, fixture.surahs[entry.firstAyah.surah - 1].name);
      expect(row.isRub, isFalse);
    }
  });

  test('lists every hizb followed by the rubs inside it', () {
    final rows = model().hizbRows;
    final hizb = fixture.index.divisions(Division.hizb);
    expect(rows.where((row) => !row.isRub).map((row) => row.number), [
      for (final entry in hizb) entry.number,
    ]);
    // Rubs that start where their hizb does are the hizb's own row.
    final inner = [
      for (final rub in fixture.index.divisions(Division.rub))
        if (!hizb.any((entry) => entry.firstAyah == rub.firstAyah)) rub,
    ];
    expect(rows.where((row) => row.isRub).map((row) => row.number), [
      for (final rub in inner) rub.number,
    ]);
    var current = 0;
    for (final row in rows) {
      if (!row.isRub) {
        current = row.number;
      } else {
        expect(fixture.index.numberAt(Division.hizb, row.address), current);
      }
    }
  });

  test('chooses a tab and tells the screen once', () {
    final m = model();
    var notified = 0;
    m.addListener(() => notified++);
    expect(m.tab, IndexTab.surahs);
    m
      ..selectTab(IndexTab.hizb)
      ..selectTab(IndexTab.hizb);
    expect(m.tab, IndexTab.hizb);
    expect(notified, 1);
  });
}
