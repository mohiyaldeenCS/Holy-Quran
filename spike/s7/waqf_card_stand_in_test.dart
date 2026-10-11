import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/utils/result.dart';

import '../s1/render/synthetic_surah_pack.dart';
import 'waqf_card_stand_in.dart';

// The surah name is the synthetic pack's, read through the repository.

Future<void> _pump(
  WidgetTester tester,
  PackText name, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(theme),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: WaqfCardStandIn(
            surahName: name,
            ayah: QuranAddress('hafs', syntheticLongSurah, 12),
            mark: 2,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late Directory root;
  late PackText name;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s7_waqf');
    final pack = await openSyntheticSpikePack(root, withMarks: true);
    name = switch (await pack.surahs()) {
      Ok(:final value) => value.first.name,
      Failure(:final error) => throw StateError('$error'),
    };
    pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  for (final theme in ReadingTheme.values) {
    testWidgets('only the ayah reference and the mark number in '
        '${theme.name}', (tester) async {
      await _pump(tester, name, theme: theme);
      final reference = tester.widget<SurahName>(find.byType(SurahName));
      expect(reference.format, SurahNameFormat.withAyah);
      expect(reference.ayah, 12);
      expect(reference.name, same(name));
      expect(find.byType(QuranText), findsNothing);
      final texts = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((t) => t.text.toPlainText())
          .toList();
      expect(texts, hasLength(2));
      expect(texts.last, 'Mark 2');
      for (final text in texts) {
        expect(
          text.runes.where((r) => r >= 0x06D6 && r <= 0x06ED),
          isEmpty,
          reason: 'no mark glyph',
        );
      }
    });
  }

  testWidgets('nothing overflows at 200% text', (tester) async {
    await _pump(tester, name, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
