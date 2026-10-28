import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/context_sheet.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/golden.dart';
import '../../features/index/index_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('context_sheet_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  /// [count] ayat of [surah] from [first], read as the context view model
  /// reads them, with [selected] the one asked for.
  Future<ContextPassage> passage(
    int surah,
    int first,
    int count,
    int selected,
  ) async {
    final ayat = <AyahText>[];
    for (var ayah = first; ayah < first + count; ayah++) {
      final at = QuranAddress(fixture.text.riwaya, surah, ayah);
      ayat.add(
        AyahText(
          text: _ok(await fixture.text.ayahText(at)),
          words: _ok(await fixture.text.words(at)),
          marks: _ok(await fixture.text.marks(at)),
        ),
      );
    }
    return ContextPassage(
      riwaya: fixture.text.riwaya,
      surah: surah,
      firstAyah: first,
      ayat: ayat,
      selectedAyah: selected,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required ContextPassage? passage,
    int amount = 0,
    ValueChanged<int>? onAmountSelected,
    VoidCallback? onOpen,
    VoidCallback? onPlay,
    ReadingTheme theme = ReadingTheme.paper,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size
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
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ContextSheet(
                surahName: fixture.surahs[1].name,
                ayahNumber: 5,
                amounts: [
                  _l10n.contextOneAyah,
                  _l10n.ayahCount(3, arabicDigits(3)),
                  _l10n.ayahCount(5, arabicDigits(5)),
                  _l10n.contextSurah,
                ],
                amount: amount,
                onAmountSelected: onAmountSelected ?? (_) {},
                passage: passage,
                onOpen: onOpen ?? () {},
                onPlay: onPlay,
              ),
            ),
          ),
        ),
      ),
    );
  }

  SemanticsNode semanticsRoot(WidgetTester tester) => tester
      .renderObject(find.byType(ContextSheet))
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;

  Iterable<SemanticsNode> walk(SemanticsNode node) sync* {
    yield node;
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      yield* walk(child);
    }
  }

  /// Every semantics label on screen, in traversal order.
  List<String> labels(WidgetTester tester) => [
    for (final node in walk(semanticsRoot(tester)))
      if (node.label.isNotEmpty) node.label,
  ];

  testWidgets('shows the title, the subtitle, the reference and the choice', (
    tester,
  ) async {
    await pump(tester, passage: await passage(2, 5, 1, 5));
    expect(find.text(_l10n.searchResultContext), findsOneWidget);
    expect(find.text(_l10n.contextSubtitle), findsOneWidget);
    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(name.name, fixture.surahs[1].name);
    expect(name.ayah, 5);
    expect(name.format, SurahNameFormat.withAyah);
    final choice = tester.widget<LevelSwitch>(find.byType(LevelSwitch));
    expect(choice.options, [
      _l10n.contextOneAyah,
      _l10n.ayahCount(3, '٣'),
      _l10n.ayahCount(5, '٥'),
      _l10n.contextSurah,
    ]);
    expect(choice.semanticLabel, _l10n.contextAmountLabel);
    expect(find.widgetWithText(Button, _l10n.searchResultOpen), findsOneWidget);
  });

  testWidgets('draws the pack\'s ayat unchanged, each between its marker '
      'numbered as in its surah', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, passage: await passage(2, 4, 3, 5));
    final stored = [
      for (final (number, bytes) in fixture.pack.raw.ayat(2))
        if (number >= 4 && number <= 6) utf8.decode(bytes),
    ];
    final read = labels(tester);
    var at = 0;
    for (final (index, text) in stored.indexed) {
      final ayah = read.indexOf(text, at);
      expect(ayah, greaterThanOrEqualTo(at), reason: 'ayah ${index + 4}');
      final marker = read.indexOf(
        _l10n.ayahMarkerLabel(arabicDigits(4 + index)),
        ayah,
      );
      expect(marker, ayah + 1, reason: 'marker ${4 + index}');
      at = marker + 1;
    }
    handle.dispose();
  });

  testWidgets('the ayah asked for is framed and told to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, passage: await passage(2, 4, 3, 5));
    final stored = utf8.decode(fixture.pack.raw.ayat(2)[4].$2);
    final selected = [
      for (final node in walk(semanticsRoot(tester)))
        if (node.flagsCollection.isSelected == Tristate.isTrue) node,
    ];
    // The choice's own item is selected too; the other is the ayah.
    final ayah = selected.where(
      (node) => walk(node).any((child) => child.label == stored),
    );
    expect(ayah, hasLength(1));
    const colors = AppColors.paper;
    final painter = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_BlockPainter',
    );
    expect(
      tester.renderObject(painter),
      paints
        ..rrect(color: colors.selection)
        ..rrect(color: colors.selectionLine),
    );
    handle.dispose();
  });

  testWidgets('the ayah alone is also framed', (tester) async {
    await pump(tester, passage: await passage(2, 5, 1, 5));
    final painter = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_BlockPainter',
    );
    expect(
      tester.renderObject(painter),
      paints..rrect(color: AppColors.paper.selection),
    );
  });

  testWidgets('draws nothing for the text while the passage is being read', (
    tester,
  ) async {
    await pump(tester, passage: null);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.widgetWithText(Button, _l10n.searchResultOpen), findsOneWidget);
  });

  testWidgets('a choice is reported by its index', (tester) async {
    final chosen = <int>[];
    await pump(
      tester,
      passage: await passage(2, 5, 1, 5),
      onAmountSelected: chosen.add,
    );
    await tester.tap(find.text(_l10n.contextSurah));
    await tester.tap(find.text(_l10n.ayahCount(3, '٣')));
    expect(chosen, [3, 1]);
  });

  testWidgets('«افتح في المصحف» opens; the play button is shown only with a '
      'callback', (tester) async {
    var opened = 0;
    var played = 0;
    await pump(
      tester,
      passage: await passage(2, 5, 1, 5),
      onOpen: () => opened++,
    );
    expect(find.bySemanticsLabel(_l10n.contextPlayFromAyah), findsNothing);
    await tester.tap(find.widgetWithText(Button, _l10n.searchResultOpen));
    expect(opened, 1);

    await pump(
      tester,
      passage: await passage(2, 5, 1, 5),
      onPlay: () => played++,
    );
    final play = find.bySemanticsLabel(_l10n.contextPlayFromAyah);
    expect(play, findsOneWidget);
    expect(tester.getSize(play), const Size(52, 52));
    await tester.tap(play);
    expect(played, 1);
  });

  testWidgets('a long passage scrolls inside the sheet and keeps its '
      'buttons in view', (tester) async {
    final all = fixture.surahs[1].ayahCount;
    await pump(
      tester,
      passage: await passage(2, 1, all, 5),
      amount: 3,
      size: const Size(390, 560),
    );
    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(ContextSheet));
    expect(sheet.top, greaterThanOrEqualTo(AppSpacing.space7));
    expect(sheet.bottom, 560);
    final open = tester.getRect(
      find.widgetWithText(Button, _l10n.searchResultOpen),
    );
    expect(open.bottom, lessThanOrEqualTo(560));
    final view = tester.getRect(find.byType(CustomScrollView));
    final last = find.text(arabicDigits(all));
    expect(tester.getRect(last).top, greaterThan(view.bottom));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(view.bottom));
    expect(tester.getRect(last).top, greaterThanOrEqualTo(view.top));
  });

  testWidgets('sets the text across the sheet at 23 of the 25 of the '
      'reader', (tester) async {
    await pump(tester, passage: await passage(2, 4, 3, 5));
    expect(tester.getSize(find.byType(CustomScrollView)).width, 390 - 44);
    // The markers follow the text scale the engine is given: 26 at 25 is
    // 23.92 at 23.
    final marker = tester.getSize(find.byType(AyahMarker).first);
    expect(marker.width, closeTo(AppSizes.ayahMarker * 23 / 25, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out without overflow in ${theme.name} at 200%', (
      tester,
    ) async {
      await pump(
        tester,
        passage: await passage(2, 3, 5, 5),
        amount: 2,
        theme: theme,
        textScale: 2,
        size: const Size(360, 700),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every control is a labelled target of at least 48', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, passage: await passage(2, 5, 1, 5), onPlay: () {});
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
