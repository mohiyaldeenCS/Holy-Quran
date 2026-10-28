import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/surah_info_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/surah_info_sheet.dart';

import '../../../../testing/golden.dart';
import 'mushaf_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_info_sheet');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    int surah = 4,
    double textScale = 1,
    ReadingTheme theme = ReadingTheme.paper,
  }) async {
    setReaderView(tester);
    final viewModel = SurahInfoViewModel(
      surah: surah,
      index: rig.index,
      integrity: rig.integrity,
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
            child: SurahInfoSheet(viewModel: viewModel),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the title, the large header and the same facts', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text(_l10n.surahIntroTitle), findsOneWidget);
    final header = tester.widget<SurahHeader>(find.byType(SurahHeader));
    expect(header.size, SurahHeaderSize.lg);
    expect(header.name, rig.index.surahs[3].name);
    expect(
      header.info,
      _l10n.surahInfoLine(
        _l10n.revelationMadani,
        _l10n.ayahCount(1, arabicDigits(1)),
        arabicDigits(4),
      ),
    );
    expect(header.onInfoPressed, isNull);
  });

  testWidgets('hides the facts a pack does not give', (tester) async {
    await pumpSheet(tester, surah: MushafRig.surahWithoutPlace);

    expect(tester.widget<SurahHeader>(find.byType(SurahHeader)).info, isNull);
  });

  testWidgets('shows nothing for a surah the pack does not have', (
    tester,
  ) async {
    await pumpSheet(tester, surah: 400);

    expect(find.byType(SurahHeader), findsNothing);
    expect(find.text(_l10n.surahIntroTitle), findsNothing);
  });

  testWidgets('shows nothing once the pack stops serving', (tester) async {
    await pumpSheet(tester);
    expect(find.byType(SurahHeader), findsOneWidget);
    addTearDown(
      () => rig.integrity.report(MushafRig.packId, const IntegrityOk()),
    );

    rig.integrity.report(MushafRig.packId, const IntegrityRepairing());
    await tester.pump();

    expect(find.byType(SurahHeader), findsNothing);
  });

  testWidgets('its title is a header for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSheet(tester);

    expect(
      tester.getSemantics(find.text(_l10n.surahIntroTitle)),
      matchesSemantics(label: _l10n.surahIntroTitle, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('fits at 200% in every theme', (tester) async {
    for (final theme in ReadingTheme.values) {
      await pumpSheet(tester, textScale: 2, theme: theme);

      expect(tester.takeException(), isNull, reason: theme.name);
      expect(
        tester.getSize(find.byType(SurahInfoSheet)).width,
        readerWidth,
        reason: theme.name,
      );
    }
  });

  testWidgets('fits at 200% in landscape', (tester) async {
    await pumpSheet(tester, textScale: 2);
    tester.view.physicalSize = const Size(640, 320);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
