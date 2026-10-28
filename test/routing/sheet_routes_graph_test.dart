import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/config/providers/share_providers.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_audio_engine_service.dart';
import '../../testing/packs/synthetic_pack.dart';
import '../../testing/test_app.dart';

const _id = 'synthetic-text';

/// Serves the files of [directory] as the bundled pack synthetic-text/1;
/// with no directory, the app bundles no pack.
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  final Directory? directory;

  @override
  Future<ByteData> load(String key) async {
    const prefix = 'assets/packs/$_id/1/';
    final file = File('${directory?.path}/${key.substring(prefix.length)}');
    if (directory == null || !key.startsWith(prefix) || !file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

final _sheets = [for (final feature in appFeatures) ...feature.sheets];

// The sheets that read nothing a base pack provides, so they stay open.
const _needNoBasePack = {
  RoutePaths.reportSheet,
  RoutePaths.firstUseTafsirSheet,
};

/// The location of [path] with its parameters filled in, over ayah 1:1.
String _locationOf(String path) => path
    .replaceAll(':${Routes.addressParameter}', 'hafs:1:1')
    .replaceAll(':${Routes.surahParameter}', '1');

final _recitation = Recitation(
  id: 'synthetic-ayah',
  reciter: 'Synthetic reciter',
  riwaya: 'hafs',
  style: 'Synthetic style',
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('sheet_routes'));
  tearDown(() => root.deleteSync(recursive: true));

  /// The app over the Quran, audio and share areas as `appAreas` sets them
  /// up, with a fake engine in place of the plugin and the synthetic pack as
  /// the bundled base pack, or with no base pack.
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required bool basePack,
  }) async {
    final providers = await tester.runAsync(() async {
      final pack = basePack
          ? await buildSyntheticPack(Directory('${root.path}/bundle'))
          : null;
      final service = BasePackService(
        id: _id,
        version: 1,
        bundle: _DirectoryBundle(pack?.directory),
        supportDirectory: () async =>
            Directory('${root.path}/support').create(),
      );
      return buildDependencies(
        areas: [
          (dependencies) => provideQuran(
            dependencies,
            basePack: service,
            signatures: const SignatureNotConfigured(),
          ),
          (dependencies) => provideAudio(
            dependencies,
            createEngine: FakeAudioEngineService.new,
            locate: (recitation, source) async =>
                (uri: Uri.parse('https://audio.test/a.mp3'), streamed: true),
          ),
          shareProviders,
        ],
      );
    });
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: testApp(router)),
    );
    await tester.pumpAndSettle();
    if (basePack) {
      // The area keeps the pack open for the app's life; Windows refuses to
      // delete an open file.
      addTearDown(
        (tester
                    .element(find.byType(Navigator).first)
                    .read<QuranTextRepository>()
                as PackQuranTextRepository)
            .close,
      );
    }
    return router;
  }

  test('the sheets include the five player controls', () {
    expect(
      _sheets.map((sheet) => sheet.path),
      containsAll([
        RoutePaths.rangeSheet,
        RoutePaths.playOptionsSheet,
        RoutePaths.repeatSheet,
        RoutePaths.silenceSheet,
        RoutePaths.queueSheet,
      ]),
    );
  });

  // The app ships with a base pack and nothing playing, since no recitation
  // can be located yet; a plan playing is the state the sheets are for.
  for (final playing in [false, true]) {
    testWidgets('every sheet opens over a verified base pack, '
        '${playing ? 'with a plan playing' : 'with nothing played'}', (
      tester,
    ) async {
      final router = await pumpApp(tester, basePack: true);
      final context = tester.element(find.byType(Navigator).first);
      final builder = context.read<PlaybackPlanBuilder?>();
      final player = context.read<PlayerRepository?>();
      expect(builder, isNotNull);
      expect(player, isNotNull);
      if (playing) {
        final plan =
            (builder!.build(_recitation, WholeSurah(1)) as PlanReady).plan;
        await tester.runAsync(() => player!.play(plan));
        await tester.pump();
      }

      for (final sheet in _sheets) {
        final location = _locationOf(sheet.path);
        expect(location, isNot(contains('/:')), reason: sheet.path);
        unawaited(router.push(location));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: location);
        expect(
          router.state.uri.path,
          Uri.parse(location).path,
          reason: location,
        );
        router.pop();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('every sheet opens, or closes at once, with no base pack', (
    tester,
  ) async {
    final router = await pumpApp(tester, basePack: false);
    final context = tester.element(find.byType(Navigator).first);
    expect(context.read<PlaybackPlanBuilder?>(), isNull);
    expect(context.read<PlayerRepository?>(), isNull);

    for (final sheet in _sheets) {
      final location = _locationOf(sheet.path);
      unawaited(router.push(location));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: location);
      if (!_needNoBasePack.contains(sheet.path)) {
        expect(router.state.uri.path, Routes.home, reason: location);
      } else {
        router.pop();
        await tester.pumpAndSettle();
      }
    }
  });
}
