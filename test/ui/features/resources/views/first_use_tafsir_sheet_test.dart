import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';
import 'package:holyquran/ui/features/resources/view_models/first_use_tafsir_view_model.dart';
import 'package:holyquran/ui/features/resources/views/first_use_tafsir_sheet.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/golden.dart';
import '../resources_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

late FakeCatalogueRepository _catalogue;
late FakePackInstallRepository _installs;

Future<FirstUseTafsirViewModel> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final viewModel = FirstUseTafsirViewModel(
    catalogue: _catalogue,
    installs: _installs,
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
          child: FirstUseTafsirSheet(viewModel: viewModel),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return viewModel;
}

void main() {
  setUp(() {
    _catalogue = FakeCatalogueRepository(catalogueWith(const []));
    _installs = FakePackInstallRepository();
  });

  testWidgets('offers the catalogue\'s first-use tafsir', (tester) async {
    await _pump(tester);
    final row = tester.widget<PackRow>(find.byType(PackRow));
    expect(row.row.entry.id, firstUseId);
    expect(find.text(_l10n.resourceDownload), findsOneWidget);
    expect(_catalogue.refreshCount, 0);
  });

  testWidgets('requests the download once', (tester) async {
    final pending = Completer<Result<InstalledPack>>();
    final installs = _PendingInstalls(pending.future);
    final viewModel = FirstUseTafsirViewModel(
      catalogue: _catalogue,
      installs: installs,
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      goldenApp(ReadingTheme.paper, FirstUseTafsirSheet(viewModel: viewModel)),
    );

    await tester.tap(find.text(_l10n.resourceDownload));
    await tester.tap(find.text(_l10n.resourceDownload));
    await tester.pump();
    expect(installs.requested, [firstUseId]);

    pending.complete(const Failure(AlreadyQueued(firstUseId)));
    await tester.pump();
    await tester.tap(find.text(_l10n.resourceDownload));
    await tester.pump();
    expect(installs.requested, [firstUseId, firstUseId]);
  });

  testWidgets('shows the download under way and the pack once there', (
    tester,
  ) async {
    await _pump(tester);
    _installs.jobs = [jobOf(_catalogue.catalogue!, firstUseId, sixtyPercent)];
    await tester.pump();
    expect(
      tester.widget<ResourceRow>(find.byType(ResourceRow)).status,
      ResourceStatus.downloading,
    );
    _installs
      ..jobs = const []
      ..installed = [installedTafsir(firstUseId)];
    await tester.pump();
    expect(find.text(_l10n.resourceDownloaded), findsOneWidget);
    await tester.tap(find.text(_l10n.resourceDelete));
    expect(_installs.calls, [('delete', firstUseId)]);
  });

  testWidgets('fetches a catalogue it lacks, and says when it cannot', (
    tester,
  ) async {
    _catalogue.catalogue = null;
    await _pump(tester);
    expect(_catalogue.refreshCount, 1);
    expect(find.byType(PackRow), findsNothing);
    expect(
      find.widgetWithText(IntegrityAlert, _l10n.connectionFailed),
      findsOneWidget,
    );
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out at 200% text in ${theme.name}', (tester) async {
      await _pump(tester, theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the route opens it as a sheet over the screen', (tester) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<CatalogueRepository>.value(value: _catalogue),
          ListenableProvider<PackInstallRepository>.value(value: _installs),
        ],
        child: QuranApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.firstUseTafsirSheet));
    await tester.pumpAndSettle();
    expect(find.byType(FirstUseTafsirSheet), findsOneWidget);
    expect(find.byType(PackRow), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(FirstUseTafsirSheet), findsNothing);
  });
}

/// An installer with nothing installed whose installs stay pending until
/// [result] completes.
final class _PendingInstalls extends ChangeNotifier
    implements PackInstallRepository {
  _PendingInstalls(this.result);

  final Future<Result<InstalledPack>> result;
  final requested = <String>[];

  @override
  Future<Result<void>> get started async => const Ok(null);

  @override
  List<InstalledPack> get installed => const [];

  @override
  List<InstallJob> get jobs => const [];

  @override
  Future<Result<InstalledPack>> install(InstallRequest request) {
    requested.add(request.packId);
    return result;
  }

  @override
  Future<void> pause(String packId) async {}

  @override
  Future<void> resume(String packId) async {}

  @override
  Future<void> cancel(String packId) async {}

  @override
  Future<Result<InstalledPack>> rollback(String packId) async =>
      Failure(NoPreviousVersion(packId));

  @override
  Future<Result<void>> delete(String packId) async => const Ok(null);
}
