import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

import '../index/index_fixture.dart';
import '../search/search_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('study_screen_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  List<String> entries(WidgetTester tester) => [
    for (final button in tester.widgetList<Button>(find.byType(Button)))
      button.label,
  ];

  testWidgets('has the title and an entry to the search', (tester) async {
    final router = await pumpSearchApp(
      tester,
      fixture,
      search: searchFinding(const []),
      location: Routes.study,
    );

    expect(find.text(_l10n.tabStudy), findsWidgets);
    expect(entries(tester), [_l10n.searchTitle, _l10n.tafsirReaderTitle]);
    await tester.tap(find.text(_l10n.searchTitle));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.search);
  });

  testWidgets('opens the tafsir reader at the first ayah', (tester) async {
    final router = await pumpSearchApp(
      tester,
      fixture,
      search: searchFinding(const []),
      location: Routes.study,
    );

    await tester.tap(find.text(_l10n.tafsirReaderTitle));
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      Routes.studyTafsir(QuranAddress(fixture.index.riwaya, 1, 1)),
    );
  });

  testWidgets('has no tafsir entry without a text pack', (tester) async {
    await pumpSearchApp(
      tester,
      fixture,
      search: searchFinding(const []),
      location: Routes.study,
      withPack: false,
    );

    expect(entries(tester), [_l10n.searchTitle]);
  });
}
