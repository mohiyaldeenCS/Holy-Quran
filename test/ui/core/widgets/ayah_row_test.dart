import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
// Synthetic, never Quran text.
const _text = PackText.fromPack('نص تجريبي');
const _longText = PackText.fromPack(
  'نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام وليس آية',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

AyahRow _row({
  int number = 5,
  PackText text = _text,
  VoidCallback? onPlay,
  VoidCallback? onBookmark,
  VoidCallback? onStudy,
  bool all = true,
}) => AyahRow(
  number: number,
  text: text,
  onPlay: onPlay ?? (all ? () {} : null),
  onBookmark: onBookmark ?? (all ? () {} : null),
  onStudy: onStudy ?? (all ? () {} : null),
);

BoxDecoration _card(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(AyahRow),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

bool _ringDrawn(WidgetTester tester, Finder ring) =>
    tester
        .widget<CustomPaint>(
          find.descendant(of: ring, matching: find.byType(CustomPaint)).first,
        )
        .foregroundPainter !=
    null;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a surface card, radius 20, with a 1 px line border', (
    tester,
  ) async {
    await _pump(tester, _row());
    final card = _card(tester);
    expect(card.color, AppColors.paper.surface);
    expect(card.borderRadius, BorderRadius.circular(20));
    expect(card.border, Border.all(color: AppColors.paper.line));
  });

  testWidgets('pads 8, 24 and 12 inside the border; 2 between the parts', (
    tester,
  ) async {
    await _pump(tester, _row());
    final card = tester.getRect(find.byType(AyahRow));
    final marker = tester.getRect(find.byType(AyahMarker));
    final buttons = find.byType(IconButton);
    final text = tester.getRect(find.byType(QuranText));
    const border = 1;
    expect(card.right - marker.right, border + AppSpacing.space5);
    expect(
      tester.getRect(buttons.last).left - card.left,
      border + AppSpacing.space5,
    );
    expect(
      tester.getRect(buttons.first).top - card.top,
      border + AppSpacing.space2,
    );
    expect(card.bottom - text.bottom, border + AppSpacing.space3);
    expect(text.top - tester.getRect(buttons.first).bottom, 2);
    expect(marker.center.dy, tester.getRect(buttons.first).center.dy);
  });

  testWidgets('a 36 marker with a 1.5 ring, the number in it', (tester) async {
    await _pump(tester, _row(number: 286));
    final marker = tester.widget<AyahMarker>(find.byType(AyahMarker));
    expect(marker.number, 286);
    expect(marker.size, 36);
    expect(marker.ringWidth, 1.5);
    expect(tester.getSize(find.byType(AyahMarker)), const Size.square(36));
  });

  testWidgets('draws the pack text unchanged in QuranText at the ayah size', (
    tester,
  ) async {
    await _pump(tester, _row());
    final quran = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(quran.text, _text), isTrue);
    expect(quran.size, QuranTextSize.ayah);
    expect(quran.align, QuranTextAlign.start);
    expect(quran.colour, QuranTextColour.quranInk);
  });

  testWidgets('right to left: the marker on the right, then play, bookmark, '
      'study, 4 apart', (tester) async {
    await _pump(tester, _row());
    final icons = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .map((button) => button.icon);
    expect(icons, [IconName.play, IconName.bookmark, IconName.study]);
    final rects = [
      for (var i = 0; i < 3; i++) tester.getRect(find.byType(IconButton).at(i)),
    ];
    expect(rects[0].left - rects[1].right, AppSpacing.space1);
    expect(rects[1].left - rects[2].right, AppSpacing.space1);
    expect(
      tester.getRect(find.byType(AyahMarker)).left,
      greaterThan(rects[0].right),
    );
    for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.color, AppColors.paper.primary);
    }
  });

  testWidgets('each action calls its own callback', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      _row(
        onPlay: () => calls.add('play'),
        onBookmark: () => calls.add('bookmark'),
        onStudy: () => calls.add('study'),
      ),
    );
    for (final label in [
      _l10n.ayahRowPlayFromHere,
      _l10n.ayahRowBookmark,
      _l10n.ayahRowStudy,
    ]) {
      await tester.tap(find.bySemanticsLabel(label));
    }
    expect(calls, ['play', 'bookmark', 'study']);
  });

  testWidgets('an action with no callback is not shown', (tester) async {
    await _pump(tester, _row(all: false, onBookmark: () {}));
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.map((button) => button.icon), [IconName.bookmark]);

    await _pump(tester, _row(all: false));
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(AyahMarker), findsOneWidget);
    expect(find.byType(QuranText), findsOneWidget);
  });

  testWidgets('reads the marker, three labelled buttons and the text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _row());
    expect(find.bySemanticsLabel('الآية ٥'), findsOneWidget);
    for (final label in [
      _l10n.ayahRowPlayFromHere,
      _l10n.ayahRowBookmark,
      _l10n.ayahRowStudy,
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _row());
    final ring = find
        .descendant(
          of: find.byType(IconButton).first,
          matching: find.byType(FocusRing),
        )
        .first;
    expect(_ringDrawn(tester, ring), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester, ring), isTrue);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester, ring), isFalse);
  });

  testWidgets('wraps long text without overflow at 200% on 360 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      SingleChildScrollView(child: _row(number: 286, text: _longText)),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AyahRow)).width, 360);
    expect(tester.getSize(find.byType(AyahMarker)), const Size.square(72));
  });
}
