import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_copy_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_sheet.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/golden.dart';
import 'tafsir_fixture.dart';

final tafsirL10n = lookupAppLocalizations(const Locale('ar'));

/// A model over the fixture's packs at [address], with every text copied
/// collected in [copied]. The first read is waited for in real time.
Future<TafsirViewModel> openModel(
  WidgetTester tester,
  TafsirFixture fixture,
  QuranAddress address, {
  List<String>? copied,
  TafsirRepository? tafsirs,
  CatalogueRepository? catalogue,
}) async {
  final repository = tafsirs ?? fixture.tafsirs;
  final model = TafsirViewModel(
    address: address,
    quran: fixture.quran,
    tafsirs: repository,
    catalogue: catalogue,
    copyText: TafsirCopyText(
      tafsirs: repository,
      quran: fixture.quran,
      l10n: tafsirL10n,
    ),
    copyToClipboard: (text) async {
      copied?.add(text);
      return const Ok(null);
    },
  );
  addTearDown(model.dispose);
  await tester.runAsync(() async {
    for (var i = 0; i < 500 && !model.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  expect(model.loaded, isTrue);
  return model;
}

/// Shows [child] in the app of [theme] on a 360 wide phone, at [textScale]:
/// filling the screen, or, as a sheet, at its bottom.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  bool sheet = false,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: sheet
              ? Align(alignment: Alignment.bottomCenter, child: child)
              : SizedBox.expand(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void tafsirTest(
  String name,
  Future<void> Function(WidgetTester tester, TafsirFixture fixture) body, {
  bool install = true,
}) => testWidgets(name, (tester) async {
  final fixture = (await tester.runAsync(
    () => TafsirFixture.open(install: install),
  ))!;
  try {
    await body(tester, fixture);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(fixture.close);
  }
});

Widget reader(TafsirViewModel model, {VoidCallback? onOffer}) =>
    TafsirReaderScreen(viewModel: model, onOfferDownload: onOffer ?? () {});

/// Lets the reads a tap or a route started end, in real time, and draws the
/// result; with [until], waits for that to be on the screen.
Future<void> settle(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 250; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (until == null || until.evaluate().isNotEmpty) return;
  }
}

Finder passageOf(String text) => find.byWidgetPredicate(
  (widget) => widget is TafsirText && widget.text == PackText.fromPack(text),
);

Finder buttonLabelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Button && widget.label == label,
);

Widget sheetOf(TafsirViewModel model, {VoidCallback? onOpenReader}) =>
    TafsirSheet(
      viewModel: model,
      onOfferDownload: () {},
      onOpenReader: onOpenReader ?? () {},
    );

final class FakeClipboard implements ClipboardService {
  final copied = <String>[];

  @override
  Future<Result<void>> copyText(String text) async {
    copied.add(text);
    return const Ok(null);
  }
}

final clipboard = FakeClipboard();

/// The app over the fixture's packs, as the composition root provides them
/// (the tafsir repository only when [tafsirs]), at its first screen.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  TafsirFixture fixture, {
  bool tafsirs = true,
}) async {
  final router = createRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(),
        ),
        Provider<QuranTextRepository>.value(value: fixture.quran),
        if (tafsirs)
          ListenableProvider<TafsirRepository>.value(value: fixture.tafsirs),
        Provider<ClipboardService>.value(value: clipboard),
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
