import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';

import '../../testing/fakes/fake_catalogue_repository.dart';
import '../../testing/fakes/fake_pack_install_repository.dart';
import '../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../testing/golden.dart';
import '../ui/features/resources/resources_fixtures.dart';
import 'a11y_support.dart';

// The resource manager with a pack in every state, and the sources screen
// (AX-01, AX-02, AX-04, AX-05, AX-09, NF-11, NF-18).

Future<void> _pump(WidgetTester tester, Widget screen, A11yView view) async {
  tester.view
    ..physicalSize = view.size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(view.textScale)),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _source = SourceCredit(
  name: 'Synthetic source name',
  url: 'https://example.invalid/synthetic/source',
  publisher: 'Synthetic publisher',
  version: '1',
  licenceText: 'Synthetic licence text',
  notice: 'Synthetic credit notice',
);

void main() {
  ResourcesScreen resources() {
    final catalogue = FakeCatalogueRepository(catalogueWith());
    final installs = FakePackInstallRepository();
    final integrity = FakePackIntegrityRepository();
    final entries = catalogue.catalogue!;
    installs
      ..installed = [
        installedTafsir(downloadedId),
        installedTafsir(updateId, version: 1),
        installedTafsir(failedId, bytes: 2000),
      ]
      ..jobs = [
        jobOf(entries, downloadingId, sixtyPercent),
        jobOf(entries, offlineId, downloadFailed(offlineId)),
      ];
    integrity.report(
      failedId,
      const IntegrityFailed(FileHashMismatch(failedId, 'tafsir.sqlite')),
    );
    final viewModel = ResourcesViewModel(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      freeBytes: () async => 6000,
    );
    addTearDown(viewModel.dispose);
    return ResourcesScreen(viewModel: viewModel);
  }

  for (final view in a11yViews) {
    testWidgets('the resource manager is accessible: ${view.name}', (
      tester,
    ) async {
      await _pump(tester, resources(), view);
      await expectAccessible(tester);
    });

    testWidgets('the sources screen is accessible: ${view.name}', (
      tester,
    ) async {
      await _pump(
        tester,
        SourcesList(
          sources: const [_source],
          fontLicences: const ['Synthetic OFL one'],
          linkFailed: false,
          onOpen: (_) {},
        ),
        view,
      );
      await expectAccessible(tester);
    });
  }

  testWidgets('the resource manager is reached by Tab', (tester) async {
    await _pump(tester, resources(), a11yViews.first);
    await expectKeyboardReach(tester);
  });

  testWidgets('the sources are reached by Tab', (tester) async {
    await _pump(
      tester,
      SourcesList(
        sources: const [_source],
        fontLicences: const [],
        linkFailed: false,
        onOpen: (_) {},
      ),
      a11yViews.first,
    );
    await expectKeyboardReach(tester);
  });
}
