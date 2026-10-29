import 'dart:io';

import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/routing/routes/sheets_routes.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../mushaf/mushaf_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// The reader meets the real sheets: a word tap at the medium level and the
// toolbar's study button reach them through the routes they register, with
// no change to the reader (D-147, 1 and 4).

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('reader_to_sheets');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  late MushafViewModel viewModel;
  late GoRouter router;

  Future<void> pumpReader(WidgetTester tester, {UiLevel? level}) async {
    setReaderView(tester);
    viewModel = rig.viewModel(
      address: QuranAddress('hafs', 2, 1),
      settings: FakeAppSettingsRepository(level: level ?? UiLevel.medium),
    );
    addTearDown(viewModel.dispose);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => SizedBox.fromSize(
            size: const Size(readerWidth, readerHeight),
            child: MushafScreen(
              key: ObjectKey(viewModel),
              viewModel: viewModel,
            ),
          ),
        ),
        for (final sheet in sheetsRoutes.sheets)
          GoRoute(
            path: sheet.path,
            pageBuilder: (context, state) => SheetPage<Object?>(
              key: state.pageKey,
              child: sheet.builder(context, state),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<QuranTextRepository>.value(value: rig.text),
          ListenableProvider<PackIntegrityRepository>.value(
            value: rig.integrity,
          ),
        ],
        child: readerRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset wordPoint(WidgetTester tester) {
    final layout = tester
        .widget<ReaderBlock>(find.byType(ReaderBlock).first)
        .layout;
    final origin = tester.getTopLeft(find.byType(ReaderBlock).first);
    final rect = TargetGeometry.of(layout).words.values.firstWhere(
      (r) => (origin + r.center).dy < readerHeight - 160,
    );
    return origin + rect.center;
  }

  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 250 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a word tap at the medium level opens the word sheet of that '
      'word', (tester) async {
    await pumpReader(tester);

    await tester.tapAt(wordPoint(tester));
    await settle(tester, find.byType(WordSheet));

    expect(find.byType(WordSheet), findsOneWidget);
    final word = QuranAddress.parse(
      router.state.uri.path.replaceFirst('/sheet/word/', ''),
    );
    expect(word.isWord, isTrue);
    final ayah = await tester.runAsync(
      () => rig.text.ayahText(word.ayahAddress),
    );
    final spans = await tester.runAsync(() => rig.text.words(word.ayahAddress));
    final drawn = tester
        .widget<RichText>(
          find.descendant(
            of: find.descendant(
              of: find.byType(WordSheet),
              matching: find.byType(QuranText),
            ),
            matching: find.byType(RichText),
          ),
        )
        .text
        .toPlainText();
    final text = (ayah! as Ok<PackText>).value.verbatim;
    final span = (spans! as Ok<List<WordSpan>>).value.firstWhere(
      (span) => span.number == word.word,
    );
    expect(drawn, text.substring(span.start, span.end));
    expect(viewModel.distractionFree, isFalse);
  });

  testWidgets('a word tap at the simple level still only toggles the '
      'interface', (tester) async {
    await pumpReader(tester, level: UiLevel.simple);

    await tester.tapAt(wordPoint(tester));
    await tester.pumpAndSettle();

    expect(find.byType(WordSheet), findsNothing);
    expect(viewModel.distractionFree, isTrue);
  });

  testWidgets('the study button of the toolbar opens the mini ayah sheet of '
      'the ayah', (tester) async {
    await pumpReader(tester);

    await tester.longPressAt(wordPoint(tester));
    await tester.pumpAndSettle();
    final selected = viewModel.selectedAyah!;
    expect(find.byType(AyahToolbar), findsOneWidget);
    final study = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.label == _l10n.toolbarStudy,
    );
    expect(study, findsOneWidget);
    await tester.tap(study);
    await settle(tester, find.byType(AyahSheetView));

    expect(find.byType(AyahSheetView), findsOneWidget);
    expect(router.state.uri.path, Routes.ayahSheet(selected));
    final row = tester.widget<AyahRow>(
      find.descendant(
        of: find.byType(AyahSheetView),
        matching: find.byType(AyahRow),
      ),
    );
    expect(row.number, selected.ayah);
  });
}
