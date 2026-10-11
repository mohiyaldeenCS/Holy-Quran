import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;
// Synthetic, never Quran text or a real surah name.
const _name = PackText.fromPack('اسم تجريبي');
const _shortValue = 'نص تجريبي';
const _short = PackText.fromPack(_shortValue);
const _longValue =
    'نص تجريبي طويل يمتد على أسطر كثيرة ليظهر قطع الكلام في البطاقة، '
    'وهو نص تجريبي ليس آية ولا مأخوذًا من أي مصدر، ويتكرر ليطول: '
    'نص تجريبي طويل يمتد على أسطر كثيرة ليظهر قطع الكلام في البطاقة، '
    'وهو نص تجريبي ليس آية ولا مأخوذًا من أي مصدر، ويتكرر ليطول.';
const _long = PackText.fromPack(_longValue);
// .qk-quran-compact: 22px at line height 2.2; three lines (D-089, 7).
const _line = 22 * 2.2;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 1200)
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: child,
          ),
        ),
      ),
    ),
  );
}

SearchResult _result({
  PackText text = _short,
  bool clamp = false,
  int ayah = 45,
  VoidCallback? onContext,
  VoidCallback? onOpen,
}) => SearchResult(
  surahName: _name,
  ayahNumber: ayah,
  ayahText: text,
  clamp: clamp,
  onContext: onContext ?? () {},
  onOpen: onOpen ?? () {},
);

Finder _card() => find
    .descendant(of: find.byType(SearchResult), matching: find.byType(Container))
    .first;

BoxDecoration _cardDecoration(WidgetTester tester) =>
    tester.widget<Container>(_card()).decoration! as BoxDecoration;

Finder _clip() => find.descendant(
  of: find.byType(SearchResult),
  matching: find.byType(ClipRect),
);

Finder _fade() => find.descendant(
  of: find.byType(SearchResult),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).gradient != null,
  ),
);

Finder _more() => find.text(_l10n.searchResultShowWhole);

/// The link's 48 target, the outermost box its label sits in.
Finder _moreTarget() =>
    find.ancestor(of: _more(), matching: find.byType(GestureDetector)).last;

Finder _ring(Finder of) =>
    find.descendant(of: of, matching: find.byType(FocusRing)).first;

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

  testWidgets('a surface card, 1 px line border, radius 20', (tester) async {
    await _pump(tester, _result());
    final card = _cardDecoration(tester);
    expect(card.color, _colors.surface);
    expect(card.border, Border.all(color: _colors.line));
    expect(card.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('padded 12, 16 and 14 inside the border; 4 between rows', (
    tester,
  ) async {
    await _pump(tester, _result());
    final card = tester.getRect(_card());
    final context = tester.getRect(find.byType(IconButton).first);
    final reference = tester.getRect(find.byType(SurahName));
    final ayah = tester.getRect(find.byType(QuranText));
    expect(context.top - card.top, 1 + AppSpacing.space3);
    expect(card.right - reference.right, 1 + AppSpacing.space4);
    expect(card.right - ayah.right, 1 + AppSpacing.space4);
    expect(ayah.left - card.left, 1 + AppSpacing.space4);
    expect(ayah.top - context.bottom, AppSpacing.space1);
    expect(card.bottom - ayah.bottom, 1 + 14);
  });

  testWidgets('the reference: the pack name with the ayah, 15/600 primary', (
    tester,
  ) async {
    await _pump(tester, _result(ayah: 153));
    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(identical(name.name, _name), isTrue);
    expect(name.format, SurahNameFormat.withAyah);
    expect(name.ayah, 153);
    expect(name.style.fontSize, 15);
    expect(name.style.fontWeight, FontWeight.w600);
    expect(name.style.color, _colors.primary);
    expect(name.style.height, isNull);
    expect(
      find.text(_l10n.surahAyahReference('اسم تجريبي', '١٥٣')),
      findsOneWidget,
    );
  });

  testWidgets('draws the pack text unchanged, compact and start-aligned', (
    tester,
  ) async {
    await _pump(tester, _result());
    final quran = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(quran.text, _short), isTrue);
    expect(quran.size, QuranTextSize.compact);
    expect(quran.align, QuranTextAlign.start);
    expect(quran.colour, QuranTextColour.quranInk);
    expect(_clip(), findsNothing);
    expect(_fade(), findsNothing);
    expect(_more(), findsNothing);
  });

  testWidgets('right to left: the reference, then context and the mushaf, '
      '48 each, 2 apart, at the end', (tester) async {
    await _pump(tester, _result());
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.map((button) => button.icon), [
      IconName.context,
      IconName.mushaf,
    ]);
    expect(buttons.map((button) => button.label), [
      _l10n.searchResultContext,
      _l10n.searchResultOpen,
    ]);
    for (final button in buttons) {
      expect(button.iconSize, 22);
      expect(button.tone, IconButtonTone.plain);
    }
    final card = tester.getRect(_card());
    final context = tester.getRect(find.byType(IconButton).first);
    final open = tester.getRect(find.byType(IconButton).last);
    expect(context.size, const Size.square(AppSizes.targetMin));
    expect(context.left - open.right, 2);
    expect(open.left - card.left, 1 + AppSpacing.space4);
    final reference = tester.getRect(find.byType(SurahName));
    expect(reference.center.dy, closeTo(context.center.dy, 0.5));
    expect(tester.getRect(find.byType(Text).first).right, reference.right);
  });

  testWidgets('each action calls its own callback', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      _result(
        onContext: () => calls.add('context'),
        onOpen: () => calls.add('open'),
      ),
    );
    await tester.tap(find.bySemanticsLabel(_l10n.searchResultContext));
    await tester.tap(find.bySemanticsLabel(_l10n.searchResultOpen));
    expect(calls, ['context', 'open']);
  });

  testWidgets('clamped: three lines of 22 × 2.2 under a 40 px fade', (
    tester,
  ) async {
    await _pump(tester, _result(text: _long, clamp: true));
    final whole = tester.getSize(find.byType(QuranText)).height;
    expect(whole, greaterThan(3 * _line));
    final clip = tester.getRect(_clip());
    expect(clip.height, closeTo(3 * _line, 0.01));
    final fade = tester.getRect(_fade());
    expect(fade.height, 40);
    expect(fade.bottom, clip.bottom);
    expect(fade.left, clip.left);
    expect(fade.right, clip.right);
    final gradient =
        (tester.widget<DecoratedBox>(_fade()).decoration as BoxDecoration)
                .gradient!
            as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors, [
      _colors.surface.withValues(alpha: 0),
      _colors.surface,
    ]);
  });

  testWidgets('the link: 14/600 primary at the start, 4 under the ayah, '
      'a 48 target 8 past its 32', (tester) async {
    await _pump(tester, _result(text: _long, clamp: true));
    final style = tester.widget<Text>(_more()).style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.primary);
    final card = tester.getRect(_card());
    final clip = tester.getRect(_clip());
    final target = tester.getRect(_moreTarget());
    final face = tester.getRect(
      find.descendant(of: _moreTarget(), matching: find.byType(Pressable)),
    );
    expect(target.height, AppSizes.targetMin);
    expect(face.height, 32);
    expect(face.top - target.top, 8);
    expect(target.bottom - face.bottom, 8);
    expect(face.top - clip.bottom, AppSpacing.space1);
    expect(card.bottom - face.bottom, 1 + 14);
    expect(card.right - target.right, 1 + AppSpacing.space4);
    expect(tester.getRect(_more()).right, target.right);
  });

  testWidgets('the link shows the whole ayah; the reader always has it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _result(text: _long, clamp: true));
    expect(find.bySemanticsLabel(_longValue), findsOneWidget);
    expect(
      tester.getSemantics(_moreTarget()),
      matchesSemantics(
        label: _l10n.searchResultShowWhole,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    final target = tester.getRect(_moreTarget());
    await tester.tapAt(Offset(target.center.dx, target.top + 1));
    await tester.pump();
    expect(_clip(), findsNothing);
    expect(_fade(), findsNothing);
    expect(_more(), findsNothing);
    final quran = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(quran.text, _long), isTrue);
    expect(find.bySemanticsLabel(_longValue), findsOneWidget);
    final card = tester.getRect(_card());
    final ayah = tester.getRect(find.byType(QuranText));
    expect(ayah.height, greaterThan(3 * _line));
    expect(card.bottom - ayah.bottom, 1 + 14);
    handle.dispose();
  });

  testWidgets('the link works from the keyboard', (tester) async {
    await _pump(tester, _result(text: _long, clamp: true));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_more(), findsNothing);
  });

  testWidgets('a new ayah in the same place starts clamped again', (
    tester,
  ) async {
    await _pump(tester, _result(text: _long, clamp: true));
    await tester.tap(_more());
    await tester.pump();
    expect(_more(), findsNothing);
    await _pump(
      tester,
      _result(
        text: const PackText.fromPack('$_longValue $_shortValue'),
        clamp: true,
      ),
    );
    expect(_more(), findsOneWidget);
  });

  testWidgets('reads the reference, two labelled buttons and the ayah', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _result());
    expect(
      find.bySemanticsLabel(_l10n.surahAyahReference('اسم تجريبي', '٤٥')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(_shortValue), findsOneWidget);
    for (final label in [_l10n.searchResultContext, _l10n.searchResultOpen]) {
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

  testWidgets('draws focus rings in keyboard mode only', (tester) async {
    await _pump(tester, _result(text: _long, clamp: true));
    final context = _ring(find.byType(IconButton).first);
    final more = _ring(_moreTarget());
    expect(_ringDrawn(tester, context), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester, context), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester, more), isTrue);
    expect(tester.widget<FocusRing>(more).radius, BorderRadius.zero);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester, more), isFalse);
  });

  testWidgets('at 200% on 360 wide: nothing clips; three scaled lines', (
    tester,
  ) async {
    await _pump(tester, _result(text: _long, clamp: true), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_clip()).height, closeTo(3 * 2 * _line, 0.01));
    expect(
      tester.getSize(_moreTarget()).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
    final card = tester.getRect(_card());
    expect(card.width, 360 - 2 * AppSpacing.space4);
    expect(tester.getRect(_more()).bottom, lessThan(card.bottom));

    await _pump(tester, _result(), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
