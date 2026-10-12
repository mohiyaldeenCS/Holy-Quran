import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_index_repository.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/fakes/fake_reading_position_repository.dart';

void main() {
  final index = FakeQuranIndexRepository.synthetic();

  HomeViewModel viewModel(QuranAddress? last) => HomeViewModel(
    positions: FakeReadingPositionRepository(last: last),
    index: index,
  );

  test('has no card before the first position', () {
    expect(viewModel(null).continueReading, isNull);
  });

  test('places the last ayah in the mushaf', () {
    final address = QuranAddress('hafs', 2, 3);
    final reading = viewModel(address).continueReading!;

    expect(reading.address, address);
    expect(reading.surahName, same(index.surahs[1].name));
    expect(reading.page, 3);
    expect(reading.juz, 2);
    expect(reading.progress, 3 / index.count(Division.page));
  });

  test('has no card without the repositories', () {
    expect(HomeViewModel().continueReading, isNull);
    expect(
      HomeViewModel(
        positions: FakeReadingPositionRepository(
          last: QuranAddress('hafs', 1, 1),
        ),
      ).continueReading,
      isNull,
    );
    expect(HomeViewModel(index: index).continueReading, isNull);
  });

  test('has no card for a position outside the pack', () {
    for (final address in [
      QuranAddress('warsh', 1, 1),
      QuranAddress('hafs', 4, 1),
      QuranAddress('hafs', 3, 2),
    ]) {
      expect(viewModel(address).continueReading, isNull, reason: '$address');
    }
  });

  test('has no card while the pack serves no surah names', () {
    final silent = FakeQuranIndexRepository(
      surahs: const [],
      map: EditionMap(
        edition: 'synthetic-edition',
        starts: {
          for (final division in Division.values)
            division: [QuranAddress('hafs', 1, 1)],
        },
        sajdas: const {},
      ),
    );

    expect(
      HomeViewModel(
        positions: FakeReadingPositionRepository(
          last: QuranAddress('hafs', 1, 1),
        ),
        index: silent,
      ).continueReading,
      isNull,
    );
  });

  test('tells its listeners when the position changes', () async {
    final positions = FakeReadingPositionRepository();
    final model = HomeViewModel(positions: positions, index: index);
    addTearDown(model.dispose);
    var notified = 0;
    model.addListener(() => notified++);

    await positions.save(QuranAddress('hafs', 1, 4));

    expect(notified, 1);
    expect(model.continueReading!.page, 2);
  });

  test('hides the card once the pack fails, and says so', () {
    final integrity = FakePackIntegrityRepository({
      'base': const IntegrityOk(),
    });
    final served = switch (PackQuranIndexRepository.build(
      riwaya: 'hafs',
      surahs: index.surahs,
      map: EditionMap(
        edition: 'synthetic-edition',
        starts: {
          for (final division in Division.values)
            division: [QuranAddress('hafs', 1, 1)],
        },
        sajdas: const {},
      ),
      serving: () => integrity.stateOf('base') is IntegrityOk,
    )) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
    final model = HomeViewModel(
      positions: FakeReadingPositionRepository(
        last: QuranAddress('hafs', 2, 1),
      ),
      index: served,
      integrity: integrity,
    );
    addTearDown(model.dispose);
    var notified = 0;
    model.addListener(() => notified++);
    expect(model.continueReading, isNotNull);

    integrity.report(
      'base',
      const IntegrityFailed(PackInconsistent('base', 'synthetic failure')),
    );

    expect(notified, 1);
    expect(model.continueReading, isNull);
  });

  test('stops listening when disposed', () async {
    final positions = FakeReadingPositionRepository();
    final integrity = FakePackIntegrityRepository();
    HomeViewModel(
      positions: positions,
      index: index,
      integrity: integrity,
    ).dispose();
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    // A disposed view model still listening reports a use after dispose.
    await positions.save(QuranAddress('hafs', 1, 4));
    integrity.report('base', const IntegrityOk());

    expect(reported, isEmpty);
  });
}
