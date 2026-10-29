import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/download_progress.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/recitation_card.dart';
import 'package:holyquran/ui/features/listen/view_models/recitation_picker_view_model.dart';
import 'package:holyquran/ui/features/listen/views/recitation_picker_screen.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../testing/fakes/fake_recitation_repository.dart';
import '../resources/recitation_downloads_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

/// The synthetic catalogue: `synthetic-listed` has a complete rights
/// record, `synthetic-rights-pending` does not.
final Catalogue _catalogue = syntheticCatalogue();

const _listedReciter = 'Synthetic reciter synthetic-listed';
const _pendingReciter = 'Synthetic reciter synthetic-rights-pending';
const _style = 'Synthetic style';

String _line(List<String> items) => items.join(_l10n.dataSeparator);

/// A riwaya id is internal: the catalogue has no display name for it yet.
const _riwaya = 'hafs';
const _timedRiwaya = 'synthetic_riwaya';

CatalogueRecitation _timed() => CatalogueRecitation(
  recitation: Recitation(
    id: 'synthetic-timed',
    reciter: 'Synthetic reciter synthetic-timed',
    riwaya: _timedRiwaya,
    style: _style,
    unit: RecitationUnit.surah,
    hasWordTiming: true,
    rightsComplete: true,
  ),
  qualities: const [64],
  packId: 'synthetic-timed-pack',
);

InstalledPack _installed(String id) => InstalledPack(
  manifest: PackManifest(
    formatVersion: 2,
    id: id,
    kind: PackKind.recitation,
    version: 1,
    changelog: const [],
    riwaya: 'hafs',
    sources: const [],
    files: const [],
    counts: const RecitationCounts(files: 1),
    reviews: const [],
  ),
  directory: '/synthetic/$id/1',
  previousVersion: null,
);

RecitationPickerViewModel _viewModel({
  List<CatalogueRecitation>? recitations,
  FakePackInstallRepository? installs,
  FakeRecitationDownloadRepository? downloads,
  DownloadSettingsRepository? settings,
  bool withCatalogue = true,
}) {
  final viewModel = RecitationPickerViewModel(
    recitations: FakeRecitationRepository(
      recitations ?? _catalogue.recitations,
    ),
    catalogue: withCatalogue ? FakeCatalogueRepository(_catalogue) : null,
    installs: installs ?? FakePackInstallRepository(),
    downloads: downloads,
    settings: settings,
  );
  addTearDown(viewModel.dispose);
  return viewModel;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  RecitationPickerViewModel viewModel, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.recitations,
    routes: [
      GoRoute(
        path: Routes.listen,
        builder: (context, state) => const SizedBox.expand(),
        routes: [
          GoRoute(
            path: RoutePaths.recitations,
            builder: (context, state) =>
                Scaffold(body: RecitationPickerScreen(viewModel: viewModel)),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: buildAppTheme(theme),
      themeAnimationStyle: AnimationStyle.noAnimation,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('lists no recitation without a complete rights record (AU-01)', (
    tester,
  ) async {
    await _pump(tester, _viewModel());

    expect(find.text(_listedReciter), findsOneWidget);
    expect(find.text(_pendingReciter), findsNothing);
    expect(find.byType(RecitationCard), findsOneWidget);
  });

  testWidgets('shows the style and the download state', (tester) async {
    final installs = FakePackInstallRepository();
    await _pump(tester, _viewModel(installs: installs));
    expect(find.text(_line([_style, _l10n.resourceAvailable])), findsOneWidget);

    installs.jobs = [
      InstallJob(
        _catalogue
            .pack('synthetic-recitation')!
            .installRequest(wifiOnly: false),
        const InstallDownloading(
          DownloadProgress(receivedBytes: 40, totalBytes: 100),
        ),
      ),
    ];
    await tester.pump();
    expect(
      find.text(_line([_style, _l10n.percentValue(arabicDigits(40))])),
      findsOneWidget,
    );

    installs
      ..jobs = const []
      ..installed = [_installed('synthetic-recitation')];
    await tester.pump();
    expect(
      find.text(_line([_style, _l10n.resourceDownloaded])),
      findsOneWidget,
    );
  });

  group('with the audio downloads (AU-13)', () {
    testWidgets(
      'a recitation is available, partly downloaded, then downloaded',
      (tester) async {
        final installs = FakePackInstallRepository(
          installed: [_installed('synthetic-recitation')],
        );
        final downloads = FakeRecitationDownloadRepository();
        await _pump(
          tester,
          _viewModel(installs: installs, downloads: downloads),
        );

        expect(
          find.text(_line([_style, _l10n.resourceAvailable])),
          findsOneWidget,
        );

        downloads.arrive({ayahPath(128, 1, 1)});
        await tester.pumpAndSettle();
        expect(
          find.text(_line([_style, _l10n.recitationPartial])),
          findsOneWidget,
        );

        downloads.arrive({
          for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
            for (var a = 1; a <= ayat; a++) ayahPath(128, surah, a),
        });
        await tester.pumpAndSettle();
        expect(
          find.text(_line([_style, _l10n.resourceDownloaded])),
          findsOneWidget,
        );
      },
    );

    testWidgets('judges the quality the user chose', (tester) async {
      final installs = FakePackInstallRepository(
        installed: [_installed('synthetic-recitation')],
      );
      final downloads = FakeRecitationDownloadRepository()
        ..onDevice = {
          for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
            for (var a = 1; a <= ayat; a++) ayahPath(128, surah, a),
        };
      final settings = InMemoryDownloadSettingsRepository(
        qualities: {'synthetic-listed': 64},
      );
      await _pump(
        tester,
        _viewModel(
          installs: installs,
          downloads: downloads,
          settings: settings,
        ),
      );

      expect(
        find.text(_line([_style, _l10n.resourceAvailable])),
        findsOneWidget,
      );
    });

    testWidgets('says a download is queued or waits for the network', (
      tester,
    ) async {
      final downloads = FakeRecitationDownloadRepository();
      await _pump(tester, _viewModel(downloads: downloads));
      final target = RecitationTarget(
        syntheticContents(),
        64,
        const RecitationSurah(1),
      );

      downloads.jobs = [jobFor(target, const RecitationQueued())];
      await tester.pump();
      expect(find.text(_line([_style, _l10n.resourceQueued])), findsOneWidget);

      downloads.jobs = [
        jobFor(target, const RecitationWaitingForNetwork(wifiOnly: true)),
      ];
      await tester.pump();
      expect(find.text(_line([_style, _l10n.waitingForWifi])), findsOneWidget);
    });

    testWidgets('keeps an update of the pack in view', (tester) async {
      final json = syntheticCatalogueJson();
      ((json['packs']! as List<Object?>)[2]!
              as Map<String, Object?>)['version'] =
          2;
      final installs = FakePackInstallRepository(
        installed: [_installed('synthetic-recitation')],
      );
      final viewModel = RecitationPickerViewModel(
        recitations: FakeRecitationRepository(_catalogue.recitations),
        catalogue: FakeCatalogueRepository(
          (parseCatalogue(catalogueBytes(json)) as Ok<Catalogue>).value,
        ),
        installs: installs,
        downloads: FakeRecitationDownloadRepository(),
      );
      addTearDown(viewModel.dispose);
      await _pump(tester, viewModel);

      expect(find.text(_line([_style, _l10n.updateAvailable])), findsOneWidget);
    });

    testWidgets('shows the percent of the job that runs', (tester) async {
      final downloads = FakeRecitationDownloadRepository();
      await _pump(tester, _viewModel(downloads: downloads));

      downloads.jobs = [
        jobFor(
          RecitationTarget(syntheticContents(), 64, const RecitationSurah(1)),
          downloadingBytes(40, 100),
        ),
      ];
      await tester.pump();

      expect(
        find.text(_line([_style, _l10n.percentValue(arabicDigits(40))])),
        findsOneWidget,
      );
    });

    testWidgets('shows the pack in the state it is in without audio', (
      tester,
    ) async {
      final installs = FakePackInstallRepository(
        installed: [_installed('synthetic-recitation')],
      );
      await _pump(
        tester,
        _viewModel(
          installs: installs,
          downloads: FakeRecitationDownloadRepository(),
        ),
      );

      expect(
        find.text(_line([_style, _l10n.resourceDownloaded])),
        findsNothing,
      );
    });
  });

  testWidgets('says «توقيت كلمات» where the recitation has word timing', (
    tester,
  ) async {
    await _pump(
      tester,
      _viewModel(recitations: [_timed()], withCatalogue: false),
    );

    expect(find.text(_line([_style, _l10n.wordTimingTag])), findsOneWidget);
  });

  testWidgets('never shows the riwaya id', (tester) async {
    await _pump(
      tester,
      _viewModel(recitations: [..._catalogue.recitations, _timed()]),
    );

    expect(find.textContaining(_riwaya), findsNothing);
    expect(find.textContaining(_timedRiwaya), findsNothing);
  });

  testWidgets('with no recitation the list is empty', (tester) async {
    await _pump(tester, _viewModel(recitations: const []));

    expect(find.byType(RecitationCard), findsNothing);
    expect(find.text(_l10n.resourceCategoryRecitations), findsOneWidget);
  });

  testWidgets('with no repository nothing is listed', (tester) async {
    final viewModel = RecitationPickerViewModel();
    addTearDown(viewModel.dispose);
    await _pump(tester, viewModel);

    expect(find.byType(RecitationCard), findsNothing);
  });

  testWidgets('«رجوع» goes back to the player', (tester) async {
    final router = await _pump(tester, _viewModel());

    await tester.tap(find.bySemanticsLabel(_l10n.back));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.listen);
  });

  testWidgets('every control is labelled with a hit area of at least 48', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester, _viewModel());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide', (tester) async {
        await _pump(
          tester,
          _viewModel(recitations: [..._catalogue.recitations, _timed()]),
          theme: theme,
          textScale: scale,
          size: const Size(360, 740),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('matches the picker in the four themes', tags: 'golden', (
    tester,
  ) async {
    final viewModel = _viewModel(
      recitations: [..._catalogue.recitations, _timed()],
    );
    for (final theme in ReadingTheme.values) {
      await _pump(tester, viewModel, theme: theme);
      await expectLater(
        find.byType(RecitationPickerScreen),
        matchesGoldenFile('goldens/recitation_picker_${theme.name}.png'),
      );
    }
  });
}
