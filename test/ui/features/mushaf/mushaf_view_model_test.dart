import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'mushaf_harness.dart';

/// The rig's text, with the ayat of one surah held back until [gate] opens.
final class _GatedText implements QuranTextRepository {
  _GatedText(this._inner, this.surah);

  final QuranTextRepository _inner;
  final int surah;
  final gate = Completer<void>();

  @override
  String get riwaya => _inner.riwaya;

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) async {
    if (address.surah == surah) await gate.future;
    return _inner.ayahText(address);
  }

  @override
  PackFont get font => _inner.font;

  @override
  Future<Result<List<SurahInfo>>> surahs() => _inner.surahs();

  @override
  Future<Result<PackText?>> basmala(int surah) => _inner.basmala(surah);

  @override
  Future<Result<Set<int>>> basmalaSurahs() => _inner.basmalaSurahs();

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) =>
      _inner.words(address);

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) =>
      _inner.marks(address);

  @override
  Future<Result<EditionMap>> editionMap() => _inner.editionMap();

  @override
  Future<Result<bool>> contains(QuranAddress address) =>
      _inner.contains(address);
}

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_view_model');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

  List<int> shown(MushafViewModel viewModel) => [
    for (final surah in viewModel.surahs) surah.info.number,
  ];

  test('a surah read for an old list is not added to a new one', () async {
    final positions = FakeReadingPositionRepository();
    final text = _GatedText(rig.text, 2);
    final viewModel = MushafViewModel(
      text: text,
      index: rig.index,
      positions: positions,
      integrity: rig.integrity,
    );
    addTearDown(viewModel.dispose);
    await viewModel.open.execute();
    expect(shown(viewModel), [1]);

    final loading = viewModel.loadNext.execute();
    positions.last = at(5, 1);
    await viewModel.open.execute();
    expect(shown(viewModel), [5]);

    text.gate.complete();
    await loading;

    expect(shown(viewModel), [5]);
  });

  group('showing a surah for the recitation', () {
    late FakeReadingPositionRepository positions;

    MushafViewModel reader(QuranTextRepository source) {
      final viewModel = MushafViewModel(
        text: source,
        index: rig.index,
        positions: positions,
        integrity: rig.integrity,
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    setUp(() => positions = FakeReadingPositionRepository());

    test('replaces the surahs and opens at the ayah', () async {
      final viewModel = reader(rig.text);
      await viewModel.open.execute();

      await viewModel.showAt(at(6, 1));

      expect(shown(viewModel).first, 6);
      expect(viewModel.anchor, at(6, 1));
    });

    test('is refused for an address outside the edition', () async {
      final viewModel = reader(rig.text);
      await viewModel.open.execute();

      expect(viewModel.canShow(at(6, 1)), isTrue);
      expect(viewModel.canShow(at(400, 1)), isFalse);
      expect(viewModel.canShow(QuranAddress('warsh', 6, 1)), isFalse);
    });

    test('waits for an open that is reading, and lands after it', () async {
      final text = _GatedText(rig.text, 5);
      final viewModel = reader(text);
      await viewModel.open.execute();
      expect(shown(viewModel), [1]);
      positions.last = at(5, 1);
      final reopening = viewModel.open.execute();
      await pumpEventQueue();

      await viewModel.showAt(at(6, 1));
      expect(shown(viewModel), [1]);

      text.gate.complete();
      await reopening;
      await pumpEventQueue();

      expect(shown(viewModel).first, 6);
      expect(viewModel.anchor, at(6, 1));
    });

    test(
      'an open waits for a surah being shown, and replaces it after',
      () async {
        final text = _GatedText(rig.text, 6);
        final viewModel = reader(text);
        await viewModel.open.execute();
        final showing = viewModel.showAt(at(6, 1));
        await pumpEventQueue();
        positions.last = at(5, 1);
        final reopening = viewModel.open.execute();
        await pumpEventQueue();
        expect(shown(viewModel), [1]);

        text.gate.complete();
        await showing;
        await reopening;

        expect(shown(viewModel).first, 5);
        expect(viewModel.anchor, at(5, 1));
      },
    );
  });

  test(
    'a position saved by another reader while shown reopens there',
    () async {
      final positions = FakeReadingPositionRepository();
      final viewModel = rig.viewModel(positions: positions);
      addTearDown(viewModel.dispose);
      await viewModel.open.execute();
      expect(viewModel.anchor, at(1, 1));

      await positions.save(at(5, 1));
      await pumpEventQueue();

      expect(viewModel.anchor, at(5, 1));
      expect(positions.saved, [at(5, 1)]);
    },
  );

  test('a reader shown again keeps the position it saved itself', () async {
    final positions = FakeReadingPositionRepository();
    final viewModel = rig.viewModel(address: at(2, 1), positions: positions);
    addTearDown(viewModel.dispose);
    await viewModel.open.execute();
    final anchor = viewModel.anchor;
    viewModel.showFirstVisible(at(2, 10), byUser: true);
    await viewModel.leave();
    expect(positions.last, at(2, 10));

    await viewModel.open.execute();

    expect(viewModel.anchor, same(anchor));
  });
}
