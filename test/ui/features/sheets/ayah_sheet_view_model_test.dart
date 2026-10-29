import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_sheet_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../listen/controls/controls_harness.dart' show planOf;
import 'sheets_harness.dart';

void main() {
  AyahSheetViewModel open(
    SheetsWorld world,
    int surah,
    int ayah, {
    bool tafsirs = true,
    bool notes = true,
    bool player = true,
  }) {
    final model = AyahSheetViewModel(
      address: world.ayah(surah, ayah),
      text: world.text,
      tafsirs: tafsirs ? world.fixture.tafsirs : null,
      notes: notes ? world.notes : null,
      player: player ? world.player : null,
      integrity: world.integrity,
    );
    addTearDown(model.dispose);
    return model;
  }

  sheetsTest('holds the ayah and its surah name as the pack stores them', (
    tester,
    world,
  ) async {
    final model = open(world, 1, 2);
    await waitUntil(tester, () => model.loaded);

    expect(model.unavailable, isFalse);
    expect(model.ayahText, await world.ayahText(tester, world.ayah(1, 2)));
    final surahs = await tester.runAsync(world.fixture.quran.surahs);
    expect(model.surahName, (surahs! as Ok<List<SurahInfo>>).value.first.name);
  });

  sheetsTest('takes the ayah of a word address', (tester, world) async {
    final model = AyahSheetViewModel(
      address: world.word(1, 2, 2),
      text: world.text,
      tafsirs: null,
      notes: null,
      player: null,
    );
    addTearDown(model.dispose);
    await waitUntil(tester, () => model.loaded);

    expect(model.address, world.ayah(1, 2));
    expect(model.ayahText, await world.ayahText(tester, world.ayah(1, 2)));
  });

  group('the tafsir section', () {
    sheetsTest('has the passage of the shown book, read as the sheet opens', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.tafsir.loaded);

      expect(model.tafsir.available, isTrue);
      final passage = model.tafsir.page!.passage!;
      expect(passage.text.verbatim, defaultSyntheticPassages[0].text);
      expect(model.tafsir.failure, isNull);
    });

    sheetsTest('has the page without a passage for an ayah the book skips', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 4);
      await waitUntil(tester, () => model.tafsir.loaded);

      expect(model.tafsir.page, isNotNull);
      expect(model.tafsir.page!.passage, isNull);
    });

    sheetsTest('is not available while no tafsir is installed', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.tafsir.loaded);
      expect(model.tafsir.available, isTrue);

      world.fixture.installs.installed = const [];
      await tester.pump();

      expect(model.tafsir.available, isFalse);
    });

    sheetsTest('reports a pack that failed its checks and shows none of it', (
      tester,
      world,
    ) async {
      world.fixture.installs.installed = const [];
      await tester.runAsync(
        () => world.fixture.install(id: 'synthetic-tafsir-bad', corrupt: true),
      );
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.tafsir.loaded);

      expect(model.tafsir.page, isNull);
      expect(model.tafsir.failure, isA<PackFailure>());
    });

    sheetsTest('is read again when the default book changes', (
      tester,
      world,
    ) async {
      await tester.runAsync(
        () => world.fixture.install(
          id: 'synthetic-tafsir-b',
          passages: const [
            SyntheticPassage(1, 1, 4, 'Synthetic second book passage'),
          ],
        ),
      );
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.tafsir.loaded);
      expect(model.tafsir.page!.packId, 'synthetic-tafsir');

      await tester.runAsync(
        () => world.fixture.tafsirs.setDefaultTafsir('synthetic-tafsir-b'),
      );
      await waitUntil(
        tester,
        () => model.tafsir.page?.packId == 'synthetic-tafsir-b',
      );

      expect(
        model.tafsir.page!.passage!.text.verbatim,
        'Synthetic second book passage',
      );
    });
  });

  group('the notes section', () {
    sheetsTest('is there where the notes of the user are provided', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);

      expect(model.notesAvailable, isTrue);
      expect(model.notes, isEmpty);
    });

    sheetsTest('is not there without them', (tester, world) async {
      final model = open(world, 1, 2, notes: false);
      await waitUntil(tester, () => model.loaded);

      expect(model.notesAvailable, isFalse);
      expect(model.notes, isEmpty);
    });

    sheetsTest('lists the notes of this ayah only, older first', (
      tester,
      world,
    ) async {
      await world.note(world.ayah(1, 2), 'نص أول');
      await world.note(world.ayah(1, 3), 'نص آخر');
      await world.note(world.ayah(1, 2), 'نص ثان');
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.notes.length == 2);

      expect([for (final note in model.notes) note.body], ['نص أول', 'نص ثان']);
    });

    sheetsTest('hears a note that is added, edited or deleted', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);

      final added = await world.note(world.ayah(1, 2), 'نص أول');
      await waitUntil(tester, () => model.notes.length == 1);
      await world.notes.edit(
        added.id,
        body: 'نص معدل',
        categoryId: null,
        tagIds: const {},
      );
      await waitUntil(tester, () => model.notes.single.body == 'نص معدل');
      await world.notes.delete(added.id);
      await waitUntil(tester, () => model.notes.isEmpty);
    });

    sheetsTest('shows no note when they cannot be read', (tester, world) async {
      await world.note(world.ayah(1, 2), 'نص أول');
      world.notes.failure = Exception('unreadable');
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(model.notes, isEmpty);
    });
  });

  group('the audio section', () {
    sheetsTest('is offered while the player holds a plan', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);

      expect(model.canPlay, isTrue);
    });

    sheetsTest('is not offered before a plan, and is when one comes', (
      tester,
      world,
    ) async {
      world.player = FakePlayerRepository();
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);
      expect(model.canPlay, isFalse);

      var heard = 0;
      model.addListener(() => heard++);
      world.player.state = world.player.state.copyWith(
        plan: planOf(world.builder, WholeSurah(1)),
      );

      expect(model.canPlay, isTrue);
      expect(heard, 1);
    });

    sheetsTest('is not offered without a player', (tester, world) async {
      final model = open(world, 1, 2, player: false);
      await waitUntil(tester, () => model.loaded);

      expect(model.canPlay, isFalse);
    });
  });

  group('when the pack stops serving', () {
    sheetsTest('an ayah it does not have makes the sheet unavailable', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 9);
      await waitUntil(tester, () => model.loaded);

      expect(model.unavailable, isTrue);
      expect(model.ayahText, isNull);
    });

    sheetsTest('a report of the failure of the pack makes it unavailable', (
      tester,
      world,
    ) async {
      final model = open(world, 1, 2);
      await waitUntil(tester, () => model.loaded);
      expect(model.unavailable, isFalse);

      world.text.failing = true;
      world.integrity.report(
        'synthetic-text',
        const IntegrityFailed(PackDisabled('synthetic-text')),
      );
      await waitUntil(tester, () => model.unavailable);

      expect(model.ayahText, isNull);
    });
  });

  // NF-05: a word or ayah sheet opens in 200 ms. What the sheet waits for is
  // its reads of the pack, the tafsir and the notes; the draw is a frame.
  sheetsTest('has everything it shows within the 200 ms of NF-05', (
    tester,
    world,
  ) async {
    await world.note(world.ayah(1, 2), 'نص أول');
    final model = open(world, 1, 2);
    final took = await timeUntil(
      tester,
      () => model.loaded && model.tafsir.loaded && model.notes.isNotEmpty,
    );

    expect(took, lessThan(const Duration(milliseconds: 200)));
  });
}
