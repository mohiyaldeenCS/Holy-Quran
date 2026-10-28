import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_listening_position_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_player_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/fakes/fake_reading_position_repository.dart';
import '../../../../../testing/fakes/fake_recitation_repository.dart';
import '../../listen/controls/controls_harness.dart'
    show syntheticBuilder, syntheticRecitation;
import '../home_harness.dart' show listedRecitation, listenedAt;

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

  group('continue listening', () {
    final recitation = listedRecitation();

    HomeViewModel listening({
      ListeningPosition? last,
      List<CatalogueRecitation>? listed,
      FakePlayerRepository? player,
      FakeListeningPositionRepository? positions,
    }) => HomeViewModel(
      index: index,
      listening: positions ?? FakeListeningPositionRepository(last: last),
      recitations: FakeRecitationRepository(listed ?? [recitation]),
      player: player ?? FakePlayerRepository(),
      plans: syntheticBuilder(index),
    );

    test('names the surah, the ayah and the reciter', () {
      final row = listening(
        last: listenedAt(QuranAddress('hafs', 2, 2)),
      ).continueListening!;

      expect(row.surahName, same(index.surahs[1].name));
      expect(row.ayah, 2);
      expect(row.reciter, recitation.recitation.reciter);
    });

    test('is absent without what it needs', () {
      final last = listenedAt(QuranAddress('hafs', 2, 2));
      expect(listening().continueListening, isNull);
      expect(listening(last: last, listed: []).continueListening, isNull);
      expect(HomeViewModel().continueListening, isNull);
      expect(
        HomeViewModel(
          index: index,
          listening: FakeListeningPositionRepository(last: last),
          recitations: FakeRecitationRepository([recitation]),
          plans: syntheticBuilder(index),
        ).continueListening,
        isNull,
        reason: 'no player',
      );
    });

    test('is absent for a recitation without a complete rights record', () {
      final unrighted = Recitation(
        id: syntheticRecitation().id,
        reciter: 'Synthetic reciter',
        riwaya: 'hafs',
        style: 'Synthetic style',
        unit: RecitationUnit.ayah,
        hasWordTiming: false,
        rightsComplete: false,
      );
      final model = listening(
        last: listenedAt(QuranAddress('hafs', 2, 2)),
        listed: [listedRecitation(unrighted)],
      );

      expect(model.continueListening, isNull);
    });

    test('is absent for a recitation of another riwaya', () {
      final warsh = Recitation(
        id: syntheticRecitation().id,
        reciter: 'Synthetic reciter',
        riwaya: 'warsh',
        style: 'Synthetic style',
        unit: RecitationUnit.ayah,
        hasWordTiming: false,
        rightsComplete: true,
      );
      final model = listening(
        last: listenedAt(QuranAddress('hafs', 2, 2)),
        listed: [listedRecitation(warsh)],
      );

      expect(model.continueListening, isNull);
    });

    test('notifies when the listening position changes', () async {
      final positions = FakeListeningPositionRepository();
      final model = listening(positions: positions);
      addTearDown(model.dispose);
      var notified = 0;
      model.addListener(() => notified++);

      await positions.save(listenedAt(QuranAddress('hafs', 1, 2)));

      expect(notified, 1);
      expect(model.continueListening, isNotNull);
    });

    test('resumes nothing when there is nothing to resume', () async {
      final player = FakePlayerRepository();

      await listening(player: player).resumeListening();

      expect(player.commands, isEmpty);
    });
  });

  group('the base pack', () {
    HomeViewModel withState(PackIntegrity? state, {String? id = 'base'}) =>
        HomeViewModel(
          integrity: state == null
              ? null
              : FakePackIntegrityRepository({'base': state}),
          basePackId: id,
        );

    test('failed is announced', () {
      expect(
        withState(
          const IntegrityFailed(PackInconsistent('base', 'synthetic')),
        ).baseFailed,
        isTrue,
      );
    });

    test('is not announced as failed otherwise', () {
      for (final state in [
        const IntegrityOk(),
        const IntegrityMissing(),
        const IntegrityRepairing(),
        null,
      ]) {
        expect(withState(state).baseFailed, isFalse, reason: '$state');
      }
      expect(
        withState(
          const IntegrityFailed(PackInconsistent('base', 'synthetic')),
          id: null,
        ).baseFailed,
        isFalse,
        reason: 'no base pack bundled',
      );
    });

    test('is announced when it fails', () {
      final integrity = FakePackIntegrityRepository({
        'base': const IntegrityOk(),
      });
      final model = HomeViewModel(integrity: integrity, basePackId: 'base');
      addTearDown(model.dispose);
      var notified = 0;
      model.addListener(() => notified++);

      integrity.report(
        'base',
        const IntegrityFailed(PackInconsistent('base', 'synthetic')),
      );

      expect(notified, 1);
      expect(model.baseFailed, isTrue);
    });
  });
}
