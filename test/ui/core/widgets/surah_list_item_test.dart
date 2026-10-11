import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
// Synthetic, never a real surah name.
const _nameValue = 'اسم تجريبي';
const _name = PackText.fromPack(_nameValue);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  TextScaler? textScaler,
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
          ).copyWith(textScaler: textScaler ?? TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

/// A non-linear system scale shaped like Android 14's at 200%: small sizes
/// double, larger ones grow less (14 to 26, 44 to about 50), interpolated
/// linearly between the points.
final class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  static const _from = [8.0, 10.0, 12.0, 14.0, 18.0, 20.0, 24.0, 30.0, 100.0];
  static const _to = [16.0, 20.0, 24.0, 26.0, 30.0, 34.0, 36.0, 38.0, 100.0];

  @override
  double scale(double fontSize) {
    if (fontSize <= _from.first) return fontSize * _to.first / _from.first;
    for (var i = 1; i < _from.length; i++) {
      if (fontSize <= _from[i]) {
        final t = (fontSize - _from[i - 1]) / (_from[i] - _from[i - 1]);
        return _to[i - 1] + t * (_to[i] - _to[i - 1]);
      }
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 2;
}

SurahListItem _item({
  int number = 2,
  RevelationPlace? revelation = RevelationPlace.madani,
  int ayat = 286,
  int? page = 2,
  bool lastRead = false,
  VoidCallback? onPressed,
}) => SurahListItem(
  number: number,
  name: _name,
  ayahCount: ayat,
  revelation: revelation,
  page: page,
  lastRead: lastRead,
  onPressed: onPressed ?? () {},
);

Text _textOf(WidgetTester tester, String data) => tester.widget<Text>(
  find.descendant(of: find.byType(SurahListItem), matching: find.text(data)),
);

Finder _badge() => find.descendant(
  of: find.byType(SurahListItem),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is ShapeDecoration &&
        (widget.decoration! as ShapeDecoration).color ==
            AppColors.paper.primarySoft,
  ),
);

bool _ringDrawn(WidgetTester tester) =>
    tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(FocusRing),
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .foregroundPainter !=
    null;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a 44 quarter star, stroke 4, with the number in accent 14/600', (
    tester,
  ) async {
    await _pump(tester, _item(number: 114));
    final star = tester.widget<StarOutline>(find.byType(StarOutline));
    expect(star.size, 44);
    expect(star.stroke, 4);
    expect(star.color, isNull);
    final number = _textOf(tester, '١١٤');
    expect(number.style!.fontSize, 14);
    expect(number.style!.fontWeight, FontWeight.w600);
    expect(number.style!.color, AppColors.paper.accent);
    expect(
      tester.getCenter(find.text('١١٤')),
      tester.getCenter(find.byType(StarOutline)),
    );
  });

  testWidgets('the name through SurahName, Reem Kufi 20/1.4/600 in ink', (
    tester,
  ) async {
    await _pump(tester, _item());
    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(identical(name.name, _name), isTrue);
    expect(name.format, SurahNameFormat.name);
    expect(name.style.fontFamily, AppFonts.kufi);
    expect(name.style.fontSize, 20);
    expect(name.style.height, 1.4);
    expect(name.style.fontWeight, FontWeight.w600);
    expect(name.style.color, AppColors.paper.ink);
    expect(find.text(_nameValue), findsOneWidget);
  });

  testWidgets('the meta line: place · ayah count, 14 in ink-muted', (
    tester,
  ) async {
    await _pump(tester, _item());
    final madani = _l10n.surahListMeta(_l10n.revelationMadani, '٢٨٦ آية');
    expect(madani, 'مدنية · ٢٨٦ آية');
    final meta = _textOf(tester, madani);
    expect(meta.style!.fontSize, 14);
    expect(meta.style!.color, AppColors.paper.inkMuted);

    await _pump(
      tester,
      _item(revelation: RevelationPlace.makki, ayat: 7, page: 1),
    );
    expect(find.text('مكية · ٧ آيات'), findsOneWidget);
  });

  testWidgets('the start page: the word in 12 muted, the digits 16/600 ink', (
    tester,
  ) async {
    await _pump(tester, _item(page: 50));
    final word = _textOf(tester, _l10n.surahListPage);
    expect(word.style!.fontSize, 12);
    expect(word.style!.color, AppColors.paper.inkMuted);
    final digits = _textOf(tester, '٥٠');
    expect(digits.style!.fontSize, 16);
    expect(digits.style!.fontWeight, FontWeight.w600);
    expect(digits.style!.color, AppColors.paper.ink);
    final column = find.ancestor(
      of: find.text('٥٠'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(column.first).width, greaterThanOrEqualTo(40));
  });

  testWidgets('right to left: number, name, page; 14 apart, padded 12', (
    tester,
  ) async {
    await _pump(tester, _item(page: 50));
    final row = tester.getRect(find.byType(SurahListItem));
    final star = tester.getRect(find.byType(StarOutline));
    final name = tester.getRect(find.byType(SurahName));
    final page = tester.getRect(find.text('٥٠'));
    expect(star.right, row.right);
    expect(star.left - name.right, 14);
    expect(page.right, lessThan(name.left));
    expect(row.width, 360);
    // The main column is the tallest: 12 above it, 12 under it, then the
    // 1 px line; the star is centred across.
    final meta = tester.getRect(find.text('مدنية · ٢٨٦ آية'));
    expect(name.top - row.top, AppSpacing.space3);
    expect(row.bottom - meta.bottom, AppSpacing.space3 + 1);
    expect(star.center.dy, closeTo((name.top + meta.bottom) / 2, 0.01));
    expect(meta.top - name.bottom, 2);
    final face =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(SurahListItem),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(face.color, isNull);
    expect(
      face.border,
      Border(bottom: BorderSide(color: AppColors.paper.line)),
    );
  });

  testWidgets('last read: the badge after the name, its dot in ornament', (
    tester,
  ) async {
    await _pump(tester, _item());
    expect(find.text(_l10n.surahListLastRead), findsNothing);

    await _pump(tester, _item(lastRead: true));
    final badge = tester.widget<Container>(_badge().first);
    final decoration = badge.decoration! as ShapeDecoration;
    expect(decoration.color, AppColors.paper.primarySoft);
    // A pill: radius 12 on the 24 height.
    expect(decoration.shape, const StadiumBorder());
    expect(tester.getSize(_badge().first).height, 24);
    final label = _textOf(tester, _l10n.surahListLastRead);
    expect(label.style!.fontSize, 12);
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(label.style!.color, AppColors.paper.onPrimarySoft);

    final dot = find.descendant(
      of: _badge().first,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                AppColors.paper.ornament,
      ),
    );
    expect(tester.getSize(dot), const Size.square(6));
    expect(
      (tester.widget<Container>(dot).decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(3),
    );
    final badgeRect = tester.getRect(_badge().first);
    final dotRect = tester.getRect(dot);
    expect(badgeRect.right - dotRect.right, 10);
    expect(
      dotRect.left - tester.getRect(find.text(_l10n.surahListLastRead)).right,
      6,
    );
    expect(
      tester.getRect(find.byType(SurahName)).left - badgeRect.right,
      AppSpacing.space2,
    );
  });

  testWidgets('a missing place or page is not shown', (tester) async {
    await _pump(tester, _item(revelation: null, page: null, ayat: 6));
    expect(find.text('٦ آيات'), findsOneWidget);
    expect(find.textContaining(_l10n.revelationMakki), findsNothing);
    expect(find.textContaining(_l10n.revelationMadani), findsNothing);
    expect(find.text(_l10n.surahListPage), findsNothing);
  });

  testWidgets('the whole row is one button, by tap or keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, _item(page: 50, onPressed: () => presses++));
    await tester.tap(find.text(_nameValue));
    await tester.tap(find.byType(StarOutline));
    await tester.tap(find.text('٥٠'));
    expect(presses, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 4);
  });

  testWidgets('reads as one button made of its texts', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _item(lastRead: true));
    final node = tester.getSemantics(find.byType(SurahListItem));
    expect(
      node,
      matchesSemantics(
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        label: [
          '٢',
          _nameValue,
          _l10n.surahListLastRead,
          'مدنية · ٢٨٦ آية',
          _l10n.surahListPage,
          '٢',
        ].join('\n'),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _item());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);
    final ring = tester.widget<FocusRing>(find.byType(FocusRing));
    expect(ring.radius, BorderRadius.zero);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('no overflow at 200% on 360 wide; the star grows with the text', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          _item(number: 114, lastRead: true),
          _item(number: 3, ayat: 200, page: 604),
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(StarOutline).first).width, 88);
    // The badge grows with its text and stays a pill.
    expect(tester.getSize(_badge()).height, greaterThan(24));
    expect(
      (tester.widget<Container>(_badge()).decoration! as ShapeDecoration).shape,
      const StadiumBorder(),
    );
  });

  testWidgets('keeps the number inside the star under a non-linear scale', (
    tester,
  ) async {
    double ratio() =>
        tester.getSize(find.text('١١٤')).width /
        tester.getSize(find.byType(StarOutline)).width;

    await _pump(tester, _item(number: 114));
    final atFull = ratio();
    expect(atFull, lessThan(1));

    await _pump(
      tester,
      _item(number: 114),
      textScaler: const _NonLinearScaler(),
    );
    expect(tester.takeException(), isNull);
    final star = tester.getSize(find.byType(StarOutline)).width;
    expect(star, closeTo(const _NonLinearScaler().scale(44), 0.01));
    expect(ratio(), closeTo(atFull, 0.02));
    final number = _textOf(tester, '١١٤');
    expect(number.textScaler, TextScaler.noScaling);
    expect(number.style!.fontSize, closeTo(star * 14 / 44, 0.01));
    expect(
      tester.getCenter(find.text('١١٤')),
      tester.getCenter(find.byType(StarOutline)),
    );
  });
}
