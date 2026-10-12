import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/report/views/report_sheet.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';
import '../settings/text_fit.dart';
import 'report_test_support.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late InstalledPack tafsir;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('report_sheet_test');
    tafsir = await installedSyntheticTafsir(root, version: 12);
  });

  tearDownAll(() => root.delete(recursive: true));

  final address = QuranAddress('hafs', 1, 4);

  Future<void> pushReport(WidgetTester tester, String location) async {
    final router = createRouter();
    final index = FakeQuranIndexRepository.synthetic();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<QuranIndexRepository>.value(value: index),
          ListenableProvider<PackInstallRepository>.value(
            value: FakePackInstallRepository(installed: [tafsir]),
          ),
        ],
        child: QuranApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(location));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the ayah by its surah name and number', (tester) async {
    await pushReport(tester, Routes.reportSheet(address));

    expect(find.byType(ReportSheet), findsOneWidget);
    final name = FakeQuranIndexRepository.synthetic().surahs[0].name.verbatim;
    expect(
      find.text(_l10n.surahAyahReference(name, arabicDigits(4))),
      findsOneWidget,
    );
    expect(find.text(tafsir.id), findsNothing);
  });

  testWidgets("shows an entry's pack id, version and source unchanged", (
    tester,
  ) async {
    await pushReport(tester, Routes.reportSheet(address, pack: tafsir.id));

    final manifest = tafsir.manifest;
    expect(find.byType(SurahName), findsOneWidget);
    expect(find.text(manifest.id), findsOneWidget);
    expect(find.text(arabicDigits(manifest.version)), findsOneWidget);
    expect(find.text(manifest.sources.first.name), findsOneWidget);
  });

  testWidgets('shows nothing for a pack that is not installed', (tester) async {
    await pushReport(tester, Routes.reportSheet(address, pack: 'not-there'));

    expect(find.byType(SurahName), findsOneWidget);
    expect(find.text('not-there'), findsNothing);
    expect(find.text(tafsir.manifest.sources.first.name), findsNothing);
  });

  testWidgets('fits a small phone at 200% text', (tester) async {
    usePhoneAtDoubleText(tester);
    await pushReport(tester, Routes.reportSheet(address, pack: tafsir.id));

    expect(tester.takeException(), isNull);
    expect(find.byType(ReportSheet), findsOneWidget);
    for (final text in [
      tafsir.manifest.id,
      tafsir.manifest.sources.first.name,
    ]) {
      expectWordsFit(tester, find.text(text));
    }
  });

  testWidgets('is not opened over nothing at a cold start', (tester) async {
    final router = createRouter();
    await tester.pumpWidget(QuranApp(router: router));
    router.go(Routes.reportSheet(address, pack: tafsir.id));
    await tester.pumpAndSettle();

    expect(find.byType(ReportSheet), findsNothing);
  });
}
