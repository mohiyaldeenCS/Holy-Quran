import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:provider/provider.dart';

import '../../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/golden.dart';
import '../resources_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

late FakeCatalogueRepository _catalogue;
late FakePackInstallRepository _installs;
late FakePackIntegrityRepository _integrity;

/// Every state at once: available, downloading at 60 percent, downloaded,
/// an update, a downloaded pack that failed its check, and a job whose
/// download failed.
void _everyState() {
  final catalogue = _catalogue.catalogue!;
  _installs
    ..installed = [
      installedTafsir(downloadedId),
      installedTafsir(updateId, version: 1),
      installedTafsir(failedId, bytes: 2000),
    ]
    ..jobs = [
      jobOf(catalogue, downloadingId, sixtyPercent),
      jobOf(catalogue, offlineId, downloadFailed(offlineId)),
    ];
  _integrity.report(
    failedId,
    const IntegrityFailed(FileHashMismatch(failedId, 'tafsir.sqlite')),
  );
}

Future<ResourcesViewModel> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(400, 2000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final viewModel = ResourcesViewModel(
    catalogue: _catalogue,
    installs: _installs,
    integrity: _integrity,
    freeBytes: () async => 6000,
  );
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ResourcesScreen(viewModel: viewModel),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

Finder _row(String id) => find.byWidgetPredicate(
  (widget) => widget is PackRow && widget.row.entry.id == id,
);

Finder _inRow(String id, Finder finder) =>
    find.descendant(of: _row(id), matching: finder);

void main() {
  setUp(() {
    _catalogue = FakeCatalogueRepository(catalogueWith());
    _installs = FakePackInstallRepository();
    _integrity = FakePackIntegrityRepository();
  });

  testWidgets('titles the screen and each category that holds packs', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text(_l10n.resourceManagerTitle), findsOneWidget);
    expect(find.text(_l10n.resourceCategoryTafsirs), findsOneWidget);
    expect(find.text(_l10n.resourceCategoryRiwayat), findsOneWidget);
    expect(find.text(_l10n.resourceCategoryRecitations), findsNothing);
    expect(
      find.bySemanticsLabel(_l10n.resourceCategoryTafsirs),
      findsNWidgets(2),
    );
  });

  testWidgets('shows each pack in words: name, state, size, source, version', (
    tester,
  ) async {
    _everyState();
    await _pump(tester);
    final entry = _catalogue.catalogue!.pack(firstUseId)!;
    final size = megabytes(_l10n, entry.bytes);
    String line(String state) =>
        [state, 'Synthetic source summary', '٢'].join(_l10n.dataSeparator);

    final available = tester.widget<ResourceRow>(
      _inRow(firstUseId, find.byType(ResourceRow)),
    );
    expect(available.title, 'Synthetic tafsir title');
    expect(available.status, ResourceStatus.available);
    expect(
      _inRow(firstUseId, find.text(line(_l10n.resourceAvailableMeta(size)))),
      findsOne,
    );
    expect(_inRow(firstUseId, find.text(_l10n.resourceDownload)), findsOne);

    final downloading = tester.widget<ResourceRow>(
      _inRow(downloadingId, find.byType(ResourceRow)),
    );
    expect(downloading.status, ResourceStatus.downloading);
    expect(downloading.progress, closeTo(0.6, 1e-9));
    expect(_inRow(downloadingId, find.text('٦٠٪')), findsOneWidget);

    for (final id in [downloadedId, failedId]) {
      expect(
        _inRow(id, find.text(line(_l10n.resourceDownloadedMeta(size)))),
        findsOneWidget,
        reason: id,
      );
      expect(_inRow(id, find.text(_l10n.resourceDelete)), findsOne);
    }
  });

  testWidgets('an update shows what it changes, last on the line', (
    tester,
  ) async {
    _everyState();
    await _pump(tester);
    final size = megabytes(_l10n, _catalogue.catalogue!.pack(updateId)!.bytes);
    expect(
      _inRow(
        updateId,
        find.text(
          [
            _l10n.resourceDownloadedMeta(size),
            'Synthetic source summary',
            '٢',
            'Synthetic change summary',
          ].join(_l10n.dataSeparator),
        ),
      ),
      findsOne,
    );
    expect(find.textContaining('Synthetic change summary'), findsOneWidget);
    expect(_inRow(updateId, find.text(_l10n.resourceDelete)), findsOne);
  });

  testWidgets('a pack that failed its check shows the alert', (tester) async {
    _everyState();
    await _pump(tester);
    expect(_inRow(failedId, find.byType(IntegrityAlert)), findsOneWidget);
    expect(_inRow(failedId, find.text(_l10n.resourceRedownload)), findsOne);
    expect(_inRow(downloadedId, find.byType(IntegrityAlert)), findsNothing);
    expect(_inRow(offlineId, find.text(_l10n.connectionFailed)), findsOne);
  });

  testWidgets('the actions call the installer', (tester) async {
    _everyState();
    await _pump(tester);

    await tester.tap(_inRow(firstUseId, find.text(_l10n.resourceDownload)));
    await tester.tap(_inRow(downloadedId, find.text(_l10n.resourceDelete)));
    await tester.ensureVisible(
      _inRow(failedId, find.text(_l10n.resourceRedownload)),
    );
    await tester.tap(_inRow(failedId, find.text(_l10n.resourceRedownload)));
    await tester.pumpAndSettle();

    expect(_installs.calls, [
      ('install', firstUseId),
      ('delete', downloadedId),
      ('delete', failedId),
      ('install', failedId),
    ]);
  });

  testWidgets('each category has its storage bar out of the whole', (
    tester,
  ) async {
    _everyState();
    final viewModel = await _pump(tester);
    final bars = tester.widgetList<StorageBar>(find.byType(StorageBar));
    expect(
      [for (final bar in bars) bar.label],
      [_l10n.resourceCategoryTafsirs, _l10n.resourceCategoryRiwayat],
    );
    expect([for (final bar in bars) bar.usedBytes], [4000, 0]);
    expect({for (final bar in bars) bar.totalBytes}, {viewModel.storageBytes});
    expect(viewModel.storageBytes, 4000 + 6000);
  });

  testWidgets('says «تعذّر الاتصال» when no catalogue can be had', (
    tester,
  ) async {
    _catalogue.catalogue = null;
    await _pump(tester);
    expect(find.text(_l10n.connectionFailed), findsOneWidget);
    expect(find.byType(PackRow), findsNothing);
  });

  testWidgets('without its repositories it shows its title alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      goldenApp(ReadingTheme.paper, const ResourcesScreen(viewModel: null)),
    );
    expect(find.text(_l10n.resourceManagerTitle), findsOneWidget);
    expect(find.byType(PackRow), findsNothing);
  });

  testWidgets('the back button is labelled and 48 square', (tester) async {
    await _pump(tester);
    final back = find.byType(IconButton);
    expect(tester.widget<IconButton>(back).label, _l10n.back);
    final size = tester.getSize(back);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(_l10n.back), findsOneWidget);
  });

  testWidgets('a download reads its percentage in Arabic-Indic digits', (
    tester,
  ) async {
    _everyState();
    await _pump(tester);
    final bar = _inRow(downloadingId, find.byType(ProgressBar));
    expect(
      tester.getSemantics(bar),
      matchesSemantics(
        label: _l10n.resourceDownloading(titleOf(downloadingId)),
        value: '٦٠٪',
      ),
    );
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out at 200% text on 360 wide in ${theme.name}', (
      tester,
    ) async {
      _everyState();
      await _pump(
        tester,
        theme: theme,
        textScale: 2,
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text(_l10n.resourceCategoryRiwayat),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('the route', () {
    Future<void> pumpApp(WidgetTester tester, {required bool provided}) async {
      final router = createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettingsRepository>.value(
              value: FakeAppSettingsRepository(),
            ),
            if (provided) ...[
              ListenableProvider<CatalogueRepository>.value(value: _catalogue),
              ListenableProvider<PackInstallRepository>.value(value: _installs),
              ListenableProvider<PackIntegrityRepository>.value(
                value: _integrity,
              ),
            ],
          ],
          child: QuranApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go(Routes.resources);
      await tester.pumpAndSettle();
    }

    testWidgets('opens the manager over the provided repositories', (
      tester,
    ) async {
      await pumpApp(tester, provided: true);
      expect(find.byType(ResourcesScreen), findsOneWidget);
      expect(find.byType(PackRow), findsWidgets);
      expect(_catalogue.refreshCount, 1);
    });

    testWidgets('opens it empty while they are not provided', (tester) async {
      await pumpApp(tester, provided: false);
      expect(find.byType(ResourcesScreen), findsOneWidget);
      expect(find.byType(PackRow), findsNothing);
    });

    testWidgets('back returns to «المزيد»', (tester) async {
      await pumpApp(tester, provided: false);
      await tester.tap(find.bySemanticsLabel(_l10n.back));
      await tester.pumpAndSettle();
      expect(find.byType(ResourcesScreen), findsNothing);
    });
  });
}
