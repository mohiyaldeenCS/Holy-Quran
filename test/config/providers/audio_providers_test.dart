import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../testing/fakes/fake_audio_engine_service.dart';
import '../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../testing/fakes/fake_listening_position_repository.dart';
import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/fakes/fake_recitation_repository.dart';
import '../../ui/features/listen/controls/controls_harness.dart';

Future<BuildContext> _contextBelow(
  WidgetTester tester,
  List<AreaSetup> areas,
) async {
  final providers = await buildDependencies(areas: areas);
  late BuildContext below;
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: Builder(
        builder: (context) {
          below = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return below;
}

Future<Dependencies> _dependenciesWith(
  void Function(Dependencies dependencies) provide,
) async {
  late Dependencies provided;
  await buildDependencies(
    areas: [
      (dependencies) async => provide(dependencies),
      (dependencies) async => provided = dependencies,
    ],
  );
  return provided;
}

void main() {
  testWidgets('provides the player and the plan builder without touching a '
      'plugin once the base pack serves, and neither before', (tester) async {
    expect(await buildDependencies(areas: [audioProviders]), isEmpty);

    final index = FakeQuranIndexRepository.synthetic();
    final withPack = await _contextBelow(tester, [
      (dependencies) async => dependencies
        ..provide<QuranIndexRepository>(index)
        ..provide<PlaybackPlanBuilder>(syntheticBuilder(index)),
      audioProviders,
    ]);
    final player = withPack.read<PlayerRepository>();
    expect(player.state.speed, PlaybackSpeed.normal);
    expect(player, isA<EnginePlayerRepository>());
    expect(withPack.read<PlaybackPlanBuilder?>(), isNotNull);
  });

  test('provides no player without the plan builder', () async {
    final providers = await buildDependencies(
      areas: [
        (dependencies) async => dependencies.provide<QuranIndexRepository>(
          FakeQuranIndexRepository.synthetic(),
        ),
        audioProviders,
      ],
    );
    expect(providers, hasLength(1));
  });

  testWidgets('keeps where listening pauses in the listening position', (
    tester,
  ) async {
    final index = FakeQuranIndexRepository.synthetic();
    final builder = syntheticBuilder(index);
    final positions = FakeListeningPositionRepository();
    final context = await _contextBelow(tester, [
      (dependencies) async => dependencies
        ..provide<QuranIndexRepository>(index)
        ..provide<PlaybackPlanBuilder>(builder)
        ..provideListenable<ListeningPositionRepository>(positions),
      (dependencies) => provideAudio(
        dependencies,
        createEngine: FakeAudioEngineService.new,
        locate: (recitation, source) async =>
            (uri: Uri.parse('https://audio.test/a.mp3'), streamed: true),
      ),
    ]);
    final player = context.read<PlayerRepository>();

    await player.play(planOf(builder, SingleAyah(at(2, 2))));
    expect(positions.saved, isEmpty);
    await player.pause();

    expect(positions.saved.single.address, at(2, 2));
    expect(positions.saved.single.recitationId, syntheticRecitation().id);
  });

  group('recitationLocatorOf', () {
    RecitationAudio audio({required bool local}) => RecitationAudio(
      file: RecitationFile(
        qualityKbps: 64,
        part: RecitationFilePart.ayah,
        surah: 1,
        ayah: 1,
        path: 'q64/1_1.mp3',
        bytes: 1,
        sha256: syntheticHash(),
        duration: null,
      ),
      uri: Uri.parse(
        local ? 'file:///synthetic/q64' : 'https://example.invalid/q64',
      ),
      local: local,
    );

    Future<LocatedAudio?> locate(
      RecitationRepository? recitations,
      DownloadSettingsRepository? settings,
    ) async {
      final dependencies = await _dependenciesWith((dependencies) {
        if (recitations != null) {
          dependencies.provideListenable<RecitationRepository>(recitations);
        }
        if (settings != null) {
          dependencies.provideListenable<DownloadSettingsRepository>(settings);
        }
      });
      return recitationLocatorOf(dependencies)(
        syntheticCatalogue().recitations.first.recitation,
        AyahFile(QuranAddress('hafs', 1, 1)),
      );
    }

    test('plays a downloaded file from the device', () async {
      final recitations = FakeRecitationRepository(
        syntheticCatalogue().recitations,
      )..answers = (id, surah, ayah, quality) => Ok(audio(local: true));
      final settings = InMemoryDownloadSettingsRepository();

      final found = await locate(recitations, settings);

      expect(found?.uri, Uri.parse('file:///synthetic/q64'));
      expect(found?.streamed, isFalse);
    });

    test('streams what is not on the device', () async {
      final recitations = FakeRecitationRepository(
        syntheticCatalogue().recitations,
      )..answers = (id, surah, ayah, quality) => Ok(audio(local: false));

      final found = await locate(
        recitations,
        InMemoryDownloadSettingsRepository(),
      );

      expect(found?.streamed, isTrue);
    });

    test('finds nothing without the recitations or the choices', () async {
      final recitations = FakeRecitationRepository(
        syntheticCatalogue().recitations,
      );

      expect(await locate(null, InMemoryDownloadSettingsRepository()), isNull);
      expect(await locate(recitations, null), isNull);
    });
  });
}
