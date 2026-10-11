import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/rendering.dart';
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

import '../../../../testing/clip.dart';
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
// .qk-result-body.is-clamped: max-height 92px, grown as the ayah's text is.
const _clampHeight = 92.0;
// .qk-quran-compact: the ayah's font size before the text scale.
const _compactSize = 22.0;

/// A non-linear text scaler shaped like Android 14's at 200%
/// (FontScaleConverterFactory's table for 2.0): small sizes double, larger
/// ones grow less, and 100 not at all.
final class _Android14At200 extends TextScaler {
  const _Android14At200();

  static const _from = [8.0, 10, 12, 14, 18, 20, 24, 30, 100];
  static const _to = [16.0, 20, 24, 26, 30, 34, 36, 38, 100];

  @override
  double scale(double fontSize) {
    if (fontSize <= _from.first) return fontSize * 2;
    if (fontSize >= _from.last) return fontSize;
    var i = 1;
    for (; fontSize > _from[i]; i++) {}
    final t = (fontSize - _from[i - 1]) / (_from[i] - _from[i - 1]);
    return _to[i - 1] + t * (_to[i] - _to[i - 1]);
  }

  @override
  double get textScaleFactor => 2;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
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
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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

Finder _ayahText() => find.descendant(
  of: find.byType(QuranText),
  matching: find.byType(RichText),
);

RenderParagraph _ayah(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(_ayahText());

RenderObject _resultBox(WidgetTester tester) =>
    tester.renderObject(find.byType(SearchResult));

/// The lines [paragraph] is laid out in.
int _lines(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
      boxHeightStyle: BoxHeightStyle.max,
    )
    .map((box) => box.top)
    .toSet()
    .length;

/// How many of [ayah]'s lines the result shows, cut or whole.
double _linesShown(WidgetTester tester, RenderParagraph ayah) =>
    shownRect(ayah, _resultBox(tester)).height /
    (ayah.size.height / _lines(ayah));

/// Where the alphabetic baseline of [text] lies below [box]'s top.
double _baselineIn(WidgetTester tester, RenderBox box, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  return tester.getTopLeft(text).dy -
      box.localToGlobal(Offset.zero).dy +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

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

/// Whether keyboard focus is on [control] or inside it.
bool _focusedIn(Finder control) {
  final focused = FocusManager.instance.primaryFocus?.context;
  return find
      .descendant(
        of: control,
        matching: find.byElementPredicate((element) => element == focused),
      )
      .evaluate()
      .isNotEmpty;
}

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
    final ayah = _ayah(tester);
    expect(
      shownRect(ayah, _resultBox(tester)).height,
      closeTo(ayah.size.height, 0.01),
    );
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

  for (final scale in [1.0, 2.0]) {
    testWidgets('a long ayah is cut at 92 × the text scale under a 40 px '
        'fade, at ${(scale * 100).round()}%', (tester) async {
      await _pump(
        tester,
        _result(text: _long, clamp: true),
        textScaler: TextScaler.linear(scale),
      );
      expect(tester.takeException(), isNull);
      final ayah = _ayah(tester);
      final whole = tester.getRect(_ayahText());
      final shown = shownRect(ayah, _resultBox(tester));
      expect(ayah.size.height, greaterThan(_clampHeight * scale));
      expect(shown.top, whole.top);
      expect(shown.height, closeTo(_clampHeight * scale, 0.01));
      final card = tester.getRect(_card());
      expect(shown.left, card.left + 1 + AppSpacing.space4);
      expect(shown.right, card.right - 1 - AppSpacing.space4);
      // The cut is painted, not only declared.
      expect(
        find.byType(SearchResult),
        paints..clipRect(
          rect: cutClip(ayah, _resultBox(tester), _clampHeight * scale),
        ),
      );
      expect(find.byType(SearchResult), paintsExactlyCountTimes(#clipRect, 1));

      final fade = tester.getRect(_fade());
      expect(fade.height, 40);
      expect(fade.bottom, closeTo(shown.bottom, 0.01));
      expect(fade.left, shown.left);
      expect(fade.right, shown.right);
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
      expect(_more(), findsOneWidget);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('a short ayah asked to clamp shows whole, with no fade and '
        'no link, at ${(scale * 100).round()}%', (tester) async {
      await _pump(
        tester,
        _result(clamp: true),
        textScaler: TextScaler.linear(scale),
      );
      final ayah = _ayah(tester);
      expect(ayah.size.height, lessThanOrEqualTo(_clampHeight * scale));
      expect(
        shownRect(ayah, _resultBox(tester)).height,
        closeTo(ayah.size.height, 0.01),
      );
      expect(_fade(), findsNothing);
      expect(_more(), findsNothing);
      expect(find.byType(SearchResult), paintsExactlyCountTimes(#clipRect, 0));
      final card = tester.getRect(_card());
      expect(card.bottom - tester.getRect(_ayahText()).bottom, 1 + 14);

      await _pump(tester, _result(), textScaler: TextScaler.linear(scale));
      expect(tester.getRect(_card()), card);
    });
  }

  testWidgets('the link: 14/600 primary at the start, 4 under the ayah, '
      'a 48 target 8 past its 32', (tester) async {
    await _pump(tester, _result(text: _long, clamp: true));
    final style = tester.widget<Text>(_more()).style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.primary);
    final card = tester.getRect(_card());
    final shown = shownRect(_ayah(tester), _resultBox(tester));
    final target = tester.getRect(_moreTarget());
    final face = tester.getRect(
      find.descendant(of: _moreTarget(), matching: find.byType(Pressable)),
    );
    expect(target.height, AppSizes.targetMin);
    expect(face.height, 32);
    expect(face.top - target.top, 8);
    expect(target.bottom - face.bottom, 8);
    expect(face.top - shown.bottom, closeTo(AppSpacing.space1, 0.01));
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
    expect(_fade(), findsNothing);
    expect(_more(), findsNothing);
    final quran = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(quran.text, _long), isTrue);
    expect(find.bySemanticsLabel(_longValue), findsOneWidget);
    final ayah = _ayah(tester);
    expect(ayah.size.height, greaterThan(_clampHeight));
    expect(
      shownRect(ayah, _resultBox(tester)).height,
      closeTo(ayah.size.height, 0.01),
    );
    final card = tester.getRect(_card());
    expect(card.bottom - tester.getRect(_ayahText()).bottom, 1 + 14);
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
    expect(
      shownRect(_ayah(tester), _resultBox(tester)).height,
      closeTo(_clampHeight, 0.01),
    );

    await _pump(tester, _result(clamp: true));
    expect(_more(), findsNothing);
    expect(_fade(), findsNothing);
    await _pump(tester, _result(text: _long, clamp: true));
    expect(_more(), findsOneWidget);
    expect(_fade(), findsOneWidget);
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

  testWidgets('a screen reader hears the reference, the ayah, then the '
      'actions', (tester) async {
    final handle = tester.ensureSemantics();
    List<String> heard() => [
      for (final node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.label.isNotEmpty) node.label,
    ];
    final reference = _l10n.surahAyahReference('اسم تجريبي', '٤٥');
    await _pump(tester, _result());
    expect(heard(), [
      reference,
      _shortValue,
      _l10n.searchResultContext,
      _l10n.searchResultOpen,
    ]);

    await _pump(tester, _result(text: _long, clamp: true));
    expect(heard(), [
      reference,
      _longValue,
      _l10n.searchResultShowWhole,
      _l10n.searchResultContext,
      _l10n.searchResultOpen,
    ]);
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

  testWidgets('under a non-linear text scaler, as Android 14 has at 200%, '
      'the clamp shows the share of the ayah it shows at 100%', (tester) async {
    await _pump(tester, _result(text: _long, clamp: true));
    final atFull = _linesShown(tester, _ayah(tester));
    expect(atFull, closeTo(1.9, 0.05));

    const scaler = _Android14At200();
    // The scaler grows the ayah by more than half and a size of 92 by less
    // than a tenth, so scaling 92 itself would show far less of the ayah.
    expect(scaler.scale(_compactSize) / _compactSize, greaterThan(1.5));
    expect(scaler.scale(_clampHeight) / _clampHeight, lessThan(1.1));
    await _pump(tester, _result(text: _long, clamp: true), textScaler: scaler);
    expect(tester.takeException(), isNull);
    final ayah = _ayah(tester);
    // Within the test font's rounding of each line to a whole pixel.
    expect(_linesShown(tester, ayah), closeTo(atFull, 0.05));
    expect(
      find.byType(SearchResult),
      paints..clipRect(
        rect: cutClip(
          ayah,
          _resultBox(tester),
          _clampHeight * scaler.scale(_compactSize) / _compactSize,
        ),
      ),
    );
    expect(_more(), findsOneWidget);
  });

  testWidgets('under an ayah that fits, the fade and link are not drawn, '
      'read or focused', (tester) async {
    final handle = tester.ensureSemantics();
    // Room under the card, so that the hidden link lies inside the scroll
    // view and only the clamp keeps it from being drawn or read.
    Widget withRoomBelow(SearchResult result) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [result, const SizedBox(height: 200)],
    );
    await _pump(tester, withRoomBelow(_result(clamp: true)));
    final result = find.byType(SearchResult);
    // The reference and the ayah, and no link.
    expect(result, paintsExactlyCountTimes(#drawParagraph, 2));
    final link = find.text(_l10n.searchResultShowWhole, skipOffstage: false);
    expect(link, findsOneWidget);
    final view = tester.getRect(find.byType(SingleChildScrollView));
    final linkRect = tester.getRect(link);
    expect(linkRect.top, greaterThan(tester.getRect(_card()).bottom));
    expect(linkRect.bottom, lessThan(view.bottom));
    expect(find.semantics.byLabel(_l10n.searchResultShowWhole), findsNothing);
    // Defensive: the hidden link lies under the card, outside every box a hit
    // test of the card enters, so this holds even if the clamp hit it.
    final hit = tester.hitTestOnBinding(tester.getCenter(link));
    final linkBox = tester.renderObject(link);
    expect(hit.path.any((entry) => entry.target == linkBox), isFalse);
    final linkFocus = Focus.of(tester.element(link), createDependency: false);
    expect(linkFocus.canRequestFocus, isFalse);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(linkFocus.hasFocus, isFalse);
    }

    await _pump(tester, withRoomBelow(_result(text: _long, clamp: true)));
    expect(result, paintsExactlyCountTimes(#drawParagraph, 3));
    expect(find.semantics.byLabel(_l10n.searchResultShowWhole), findsOneWidget);
    expect(
      Focus.of(
        tester.element(_more()),
        createDependency: false,
      ).canRequestFocus,
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('when the ayah comes to fit, focus leaves the link for the '
      'control focused before it, and Tab goes on from there', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space4,
        children: [
          _result(text: _long, clamp: true),
          _result(text: _long, clamp: true),
        ],
      ),
    );
    final buttons = find.byType(IconButton);
    // The first result's context and mushaf buttons, then its link.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    final link = Focus.of(
      tester.element(_more().first),
      createDependency: false,
    );
    expect(link.hasPrimaryFocus, isTrue);

    // Wide enough for each ayah on one line.
    tester.view.physicalSize = const Size(8000, 1200);
    await tester.pump();
    await tester.pump();
    expect(_more(), findsNothing);
    expect(link.hasFocus, isFalse);
    expect(link.canRequestFocus, isFalse);
    expect(_focusedIn(buttons.at(1)), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedIn(buttons.at(2)), isTrue);
  });

  for (final (name, text, clamp) in [
    ('a cut ayah', _long, true),
    ('a short ayah asked to clamp', _short, true),
    ('an ayah shown whole', _long, false),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$name measures as it lays out, at '
          '${(scale * 100).round()}%: intrinsic height, dry layout and '
          'baseline', (tester) async {
        final textScaler = TextScaler.linear(scale);
        await _pump(
          tester,
          _result(text: text, clamp: clamp),
          textScaler: textScaler,
        );
        final box = tester.renderObject<RenderBox>(find.byType(SearchResult));
        final laidOut = box.size;
        expect(box.getDryLayout(box.constraints), laidOut);
        expect(box.getMinIntrinsicHeight(laidOut.width), laidOut.height);
        expect(box.getMaxIntrinsicHeight(laidOut.width), laidOut.height);
        if (clamp) {
          // The clamp's is the ayah's, at its top.
          final ayah = _ayah(tester);
          final clampBox = ayah.parent! as RenderBox;
          expect(clampBox.getDryLayout(clampBox.constraints), clampBox.size);
          expect(
            clampBox.getDryBaseline(
              clampBox.constraints,
              TextBaseline.alphabetic,
            ),
            closeTo(_baselineIn(tester, clampBox, _ayahText()), 0.01),
          );
        }

        await _pump(
          tester,
          IntrinsicHeight(
            child: _result(text: text, clamp: clamp),
          ),
          textScaler: textScaler,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(IntrinsicHeight)).height,
          laidOut.height,
        );
        expect(tester.getSize(find.byType(SearchResult)), laidOut);
      });
    }
  }

  testWidgets('at 200% on 360 wide: nothing else clips', (tester) async {
    await _pump(
      tester,
      _result(text: _long, clamp: true),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(_moreTarget()).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
    final card = tester.getRect(_card());
    expect(card.width, 360 - 2 * AppSpacing.space4);
    expect(tester.getRect(_more()).bottom, lessThan(card.bottom));

    await _pump(tester, _result(), textScaler: const TextScaler.linear(2));
    expect(tester.takeException(), isNull);
  });
}
