import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/tafsir/views/source_details_sheet.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../testing/fakes/fake_tafsir_repository.dart';
import '../../../../testing/golden.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../resources/resources_fixtures.dart';
import 'tafsir_fixture.dart';
import 'tafsir_harness.dart';

// The reader over the synthetic text pack (surahs of 4, 3 and 1 ayat) and a
// synthetic book; every text is synthetic.

void main() {
  QuranAddress at(TafsirFixture fixture, int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  tafsirTest('shows the ayah above its passage, which is as the pack '
      'stores it', (tester, fixture) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    final ayah = tester.widget<AyahRow>(find.byType(AyahRow));
    expect(ayah.number, 1);
    expect(ayah.text, model.ayahText);
    final stored = defaultSyntheticPassages[1].text;
    expect(passageOf(stored), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(of: passageOf(stored), matching: find.byType(Text)),
          )
          .data,
      stored,
    );
    expect(
      tester.getTopLeft(find.byType(AyahRow)).dy,
      lessThan(tester.getTopLeft(passageOf(stored)).dy),
    );
    expect(find.byType(SourceBadge), findsOneWidget);
  });

  tafsirTest('shows the range once for a passage over several ayat', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 2));
    await pumpScreen(tester, reader(model));

    expect(find.text(tafsirL10n.tafsirRange('١', '٣')), findsOneWidget);
    expect(passageOf(defaultSyntheticPassages[0].text), findsOneWidget);
  });

  tafsirTest('shows no range for a passage over one ayah', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    expect(model.page!.range, isNull);
    expect(
      find.textContaining(
        '${tafsirL10n.rangeFrom} ${tafsirL10n.repeatUnitAyah}',
      ),
      findsNothing,
    );
  });

  tafsirTest('says so, in the fixed sentence, when the book has no passage '
      'for the ayah', (tester, fixture) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 4));
    await pumpScreen(tester, reader(model));

    expect(find.text(tafsirL10n.tafsirNoPassage), findsOneWidget);
    expect(find.byType(AyahRow), findsOneWidget);
    // The book is still named, but no text is put in the passage's place.
    expect(find.byType(SourceBadge), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TafsirText && widget.style == AppTextStyles.tafsir,
      ),
      findsNothing,
    );
  });

  tafsirTest('steps from ayah to ayah and back, disabling a step with '
      'nowhere to go', (tester, fixture) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 1));
    await pumpScreen(tester, reader(model));
    final previous = buttonLabelled(tafsirL10n.playerPreviousAyah);
    final next = buttonLabelled(tafsirL10n.playerNextAyah);

    expect(tester.widget<Button>(previous).onPressed, isNull);
    expect(tester.widget<Button>(next).onPressed, isNotNull);

    // The passage over 1:1 to 1:3 is left whole: the step lands on 1:4.
    await tester.tap(next);
    await settle(tester);
    expect(tester.widget<AyahRow>(find.byType(AyahRow)).number, 4);
    expect(find.text(tafsirL10n.tafsirNoPassage), findsOneWidget);

    await tester.tap(next);
    await settle(tester);
    final ayah = tester.widget<AyahRow>(find.byType(AyahRow));
    expect(ayah.number, 1);
    expect(model.address, at(fixture, 2, 1));
    expect(passageOf(defaultSyntheticPassages[1].text), findsOneWidget);

    await tester.tap(previous);
    await settle(tester);
    expect(model.address, at(fixture, 1, 4));

    await tester.tap(previous);
    await settle(tester);
    expect(model.address, at(fixture, 1, 1));
    expect(tester.widget<Button>(previous).onPressed, isNull);
  });

  tafsirTest('the last ayah has no next step', (tester, fixture) async {
    final model = await openModel(tester, fixture, at(fixture, 3, 1));
    await pumpScreen(tester, reader(model));

    expect(
      tester
          .widget<Button>(buttonLabelled(tafsirL10n.playerNextAyah))
          .onPressed,
      isNull,
    );
  });

  tafsirTest('the source badge opens the facts of the book', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    await tester.tap(find.byType(SourceBadge));
    await tester.pumpAndSettle();

    expect(find.byType(SourceDetailsSheet), findsOneWidget);
    expect(find.text(tafsirL10n.sourceAuthor), findsOneWidget);
    expect(find.text(tafsirL10n.sourceEditionOrEditor), findsOneWidget);
    expect(find.text(tafsirL10n.sourceDigitisation), findsOneWidget);
    expect(find.text('Synthetic tafsir source'), findsOneWidget);
    expect(find.text(tafsirL10n.versionLabel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SourceDetailsSheet),
        matching: find.text('١'),
      ),
      findsOneWidget,
    );
    final texts = tester
        .widgetList<TafsirText>(
          find.descendant(
            of: find.byType(SourceDetailsSheet),
            matching: find.byType(TafsirText),
          ),
        )
        .map((text) => text.text);
    expect(texts, [
      PackText.fromPack(defaultSyntheticBook.title),
      PackText.fromPack(defaultSyntheticBook.author),
      PackText.fromPack(defaultSyntheticBook.editor!),
      PackText.fromPack(defaultSyntheticBook.publisher!),
    ]);
    expect(
      find.text(tafsirL10n.sourcePublisher(defaultSyntheticBook.publisher!)),
      findsOneWidget,
    );
    // The edition this book lacks is left out, not filled.
    expect(find.text(tafsirL10n.sourceEditionOrEditor), findsOneWidget);

    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
    expect(find.byType(SourceDetailsSheet), findsNothing);
  });

  tafsirTest('an ayah quoted inside a passage stays source text in the '
      'interface font', (tester, fixture) async {
    const quoting = SyntheticPassage(
      2,
      1,
      1,
      'نص ﴿ نص تجريبي '
      '﴾ مقتبس',
    );
    await tester.runAsync(
      () => fixture.install(
        id: 'synthetic-quoting',
        passages: [
          const SyntheticPassage(1, 1, 3, 'x'),
          quoting,
          const SyntheticPassage(2, 2, 3, 'y'),
          const SyntheticPassage(3, 1, 1, 'z'),
        ],
      ),
    );
    await tester.runAsync(
      () => fixture.tafsirs.setDefaultTafsir('synthetic-quoting'),
    );
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    final style = tester
        .widget<Text>(
          find.descendant(
            of: passageOf(quoting.text),
            matching: find.byType(Text),
          ),
        )
        .style!;
    expect(style.fontFamily, AppFonts.sans);
    // The only Quran text on the screen is the ayah above.
    expect(find.byType(QuranText), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AyahRow),
        matching: find.byType(QuranText),
      ),
      findsOneWidget,
    );
  });

  tafsirTest('copies the passage with its attribution', (
    tester,
    fixture,
  ) async {
    final copied = <String>[];
    final model = await openModel(
      tester,
      fixture,
      at(fixture, 2, 1),
      copied: copied,
    );
    await pumpScreen(tester, reader(model));

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.label == tafsirL10n.toolbarCopy,
      ),
    );
    await settle(tester);

    expect(copied, hasLength(1));
    expect(copied.single, contains(defaultSyntheticPassages[1].text));
    expect(copied.single, contains(defaultSyntheticBook.title));
  });

  tafsirTest('offers no copy for an ayah without a passage', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 4));
    await pumpScreen(tester, reader(model));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.label == tafsirL10n.toolbarCopy,
      ),
      findsNothing,
    );
  });

  group('default tafsir', () {
    tafsirTest('is chosen from the downloaded, apart from the available', (
      tester,
      fixture,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.runAsync(
        () => fixture.install(
          id: 'synthetic-tafsir-b',
          book: const SyntheticBook(title: 'Synthetic second', author: 'B'),
        ),
      );
      final catalogue = FakeCatalogueRepository(catalogueWith());
      addTearDown(catalogue.dispose);
      final model = await openModel(
        tester,
        fixture,
        at(fixture, 2, 1),
        catalogue: catalogue,
      );
      await pumpScreen(tester, reader(model));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text(tafsirL10n.defaultTafsirLabel), findsOneWidget);
      final downloaded = find.text(tafsirL10n.resourcesDownloaded);
      final available = find.text(tafsirL10n.resourcesAvailable);
      expect(downloaded, findsOneWidget);
      expect(available, findsOneWidget);
      expect(
        tester.getTopLeft(downloaded).dy,
        lessThan(tester.getTopLeft(available).dy),
      );
      for (final id in extraTafsirs) {
        expect(find.text(titleOf(id)), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(titleOf(id))).dy,
          greaterThan(tester.getTopLeft(available).dy),
        );
      }
      // The first book is the one shown, chosen in a single-choice list.
      expect(
        tester
            .widgetList<RadioRow>(find.byType(RadioRow))
            .map((r) => r.selected),
        [true, false],
      );
      // The sub-labels are headers for a screen reader.
      for (final label in [
        tafsirL10n.resourcesDownloaded,
        tafsirL10n.resourcesAvailable,
      ]) {
        expect(
          tester.getSemantics(find.text(label)).flagsCollection.isHeader,
          isTrue,
          reason: label,
        );
      }
      handle.dispose();
    });

    tafsirTest('choosing a downloaded book makes it the default and shows '
        'it', (tester, fixture) async {
      await tester.runAsync(
        () => fixture.install(
          id: 'synthetic-tafsir-b',
          book: const SyntheticBook(title: 'Synthetic second', author: 'B'),
        ),
      );
      final model = await openModel(tester, fixture, at(fixture, 2, 1));
      await pumpScreen(tester, reader(model));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is TafsirText &&
              widget.text == const PackText.fromPack('Synthetic second'),
        ),
      );
      await settle(tester);

      expect(fixture.tafsirs.defaultTafsir, 'synthetic-tafsir-b');
      expect(model.page!.packId, 'synthetic-tafsir-b');
      expect(
        tester.widget<SourceBadge>(find.byType(SourceBadge)).name,
        const PackText.fromPack('Synthetic second'),
      );
    });
  });

  tafsirTest('with no tafsir downloaded it says so and offers the download '
      'the catalogue has', (tester, fixture) async {
    final catalogue = FakeCatalogueRepository(catalogueWith());
    addTearDown(catalogue.dispose);
    var offered = 0;
    final model = await openModel(
      tester,
      fixture,
      at(fixture, 1, 1),
      catalogue: catalogue,
    );
    await pumpScreen(tester, reader(model, onOffer: () => offered++));

    expect(find.text(tafsirL10n.noTafsirsYet), findsOneWidget);
    expect(find.byType(AyahRow), findsOneWidget);
    expect(find.byType(SourceBadge), findsNothing);
    expect(find.byType(Button), findsOneWidget);

    await tester.tap(buttonLabelled(tafsirL10n.resourceDownload));
    expect(offered, 1);
  }, install: false);

  tafsirTest('with no tafsir downloaded and none offered it offers nothing', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 1));
    await pumpScreen(tester, reader(model));

    expect(find.text(tafsirL10n.noTafsirsYet), findsOneWidget);
    expect(find.byType(Button), findsNothing);
  }, install: false);

  tafsirTest('a book that fails its checks shows the integrity alert, '
      'not its text', (tester, fixture) async {
    final installed = fixture.installs.installed.single;
    final tafsirs = FakeTafsirRepository(
      installed: [installed],
      books: {
        installed.id: const TafsirBook(
          title: PackText.fromPack('Synthetic'),
          author: PackText.fromPack('Synthetic'),
          publisher: null,
          edition: null,
          editor: null,
        ),
      },
    )..positions = (packId, ayah) => Failure(FileHashMismatch(packId, 'f'));
    addTearDown(tafsirs.dispose);
    final model = await openModel(
      tester,
      fixture,
      at(fixture, 1, 1),
      tafsirs: tafsirs,
    );
    await pumpScreen(tester, reader(model));

    expect(find.byType(IntegrityAlert), findsOneWidget);
    expect(find.text(tafsirL10n.integrityPackTitle), findsOneWidget);
    expect(find.byType(SourceBadge), findsNothing);
    expect(find.byType(AyahRow), findsOneWidget);
  });

  tafsirTest('shows its title alone while the app provides no text pack', (
    tester,
    fixture,
  ) async {
    await pumpScreen(
      tester,
      TafsirReaderScreen(viewModel: null, onOfferDownload: () {}),
    );

    expect(find.text(tafsirL10n.tafsirReaderTitle), findsOneWidget);
    expect(find.byType(AyahRow), findsNothing);
  });

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      tafsirTest('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}%', (tester, fixture) async {
        final catalogue = FakeCatalogueRepository(catalogueWith());
        addTearDown(catalogue.dispose);
        final model = await openModel(
          tester,
          fixture,
          at(fixture, 1, 2),
          catalogue: catalogue,
        );
        await pumpScreen(tester, reader(model), theme: theme, textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }

  tafsirTest('every control is labelled and at least 48', (
    tester,
    fixture,
  ) async {
    final handle = tester.ensureSemantics();
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.bySemanticsLabel(tafsirL10n.back), findsOneWidget);
    expect(find.bySemanticsLabel(tafsirL10n.toolbarCopy), findsOneWidget);
    handle.dispose();
  });

  tafsirTest('a downloaded book that fails its checks shows the integrity '
      'alert in the list, and the others stay chosen', (tester, fixture) async {
    await tester.runAsync(
      () => fixture.install(id: 'synthetic-tafsir-b', corrupt: true),
    );
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byType(IntegrityAlert), findsOneWidget);
    expect(find.text(tafsirL10n.integrityPackTitle), findsOneWidget);
    expect(find.byType(RadioRow), findsOneWidget);
    expect(passageOf(defaultSyntheticPassages[1].text), findsOneWidget);
  });

  tafsirTest('a default that cannot be saved says so', (tester, fixture) async {
    await tester.runAsync(() => fixture.install(id: 'synthetic-tafsir-b'));
    final tafsirs = FakeTafsirRepository(
      installed: fixture.installs.installed,
      books: {
        for (final pack in fixture.installs.installed)
          pack.id: TafsirBook(
            title: PackText.fromPack('Synthetic ${pack.id}'),
            author: const PackText.fromPack('Synthetic'),
            publisher: null,
            edition: null,
            editor: null,
          ),
      },
    )..positions = (packId, ayah) => Failure(FileHashMismatch(packId, 'f'));
    addTearDown(tafsirs.dispose);
    final model = await openModel(
      tester,
      fixture,
      at(fixture, 2, 1),
      tafsirs: _Unsaved(tafsirs),
    );
    await pumpScreen(tester, reader(model));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RadioRow).last);
    await settle(tester);

    expect(find.text(tafsirL10n.userDataNotSaved), findsOneWidget);
    expect(
      tester.widgetList<RadioRow>(find.byType(RadioRow)).map((r) => r.selected),
      [true, false],
    );
  });

  tafsirTest('the steps stay inside a short landscape screen at 200%', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 2));
    tester.view
      ..physicalSize = const Size(640, 320)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: SizedBox.expand(child: reader(model)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final steps = tester.getRect(buttonLabelled(tafsirL10n.playerNextAyah));
    expect(steps.bottom, lessThanOrEqualTo(320));
    expect(steps.top, greaterThanOrEqualTo(0));
  });
}

/// A tafsir repository that cannot save the default.
final class _Unsaved extends ChangeNotifier implements TafsirRepository {
  _Unsaved(this._inner) {
    _inner.addListener(notifyListeners);
  }

  final TafsirRepository _inner;

  @override
  List<InstalledPack> get installed => _inner.installed;

  @override
  String? get defaultTafsir => _inner.defaultTafsir;

  @override
  Future<Result<void>> setDefaultTafsir(String packId) async =>
      const Failure(FormatException('synthetic failure'));

  @override
  Future<Result<TafsirBook>> book(String packId) => _inner.book(packId);

  @override
  Future<Result<TafsirPosition>> positionAt(String packId, QuranAddress ayah) =>
      _inner.positionAt(packId, ayah);

  @override
  void dispose() {
    _inner.removeListener(notifyListeners);
    super.dispose();
  }
}
