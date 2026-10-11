import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;
// Synthetic, never Quran text.
final _query = _l10n.sampleWord;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: child,
          ),
        ),
      ),
    ),
  );
}

TextEditingController _controller([String text = '']) {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  return controller;
}

SearchField _field({
  String text = '',
  TextEditingController? controller,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) => SearchField(
  controller: controller ?? _controller(text),
  onChanged: onChanged ?? (_) {},
  onSubmitted: onSubmitted ?? (_) {},
);

BoxDecoration _ring(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(SearchField),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Finder _searchIcon() =>
    find.byWidgetPredicate((w) => w is Icon && w.name == IconName.search);

bool _ringDrawn(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(FocusRing),
        matching: find.byType(CustomPaint),
      ),
    )
    .any((paint) => paint.foregroundPainter != null);

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('56 high on surface, radius 16, a 1.5 line-strong ring', (
    tester,
  ) async {
    await _pump(tester, _field());
    expect(tester.getSize(find.byType(SearchField)).height, 56);
    final ring = _ring(tester);
    expect(ring.color, _colors.surface);
    expect(ring.borderRadius, BorderRadius.circular(AppRadius.radiusButton));
    expect(ring.border, Border.all(color: _colors.lineStrong, width: 1.5));
  });

  testWidgets('the ring turns 2 px primary while the field has focus', (
    tester,
  ) async {
    await _pump(tester, _field());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(_ring(tester).border, Border.all(color: _colors.primary, width: 2));

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    expect(
      _ring(tester).border,
      Border.all(color: _colors.lineStrong, width: 1.5),
    );
  });

  testWidgets('the ring is primary while the clear button has focus too', (
    tester,
  ) async {
    await _pump(tester, _field(text: _query));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<IconButton>(), isNotNull);
    expect(_ring(tester).border, Border.all(color: _colors.primary, width: 2));
  });

  testWidgets('right to left: the icon 16 in, 10 before the text', (
    tester,
  ) async {
    await _pump(tester, _field());
    final field = tester.getRect(find.byType(SearchField));
    final icon = tester.getRect(_searchIcon());
    final input = tester.getRect(find.byType(TextField));
    expect(icon.size, const Size.square(22));
    expect(field.right - icon.right, AppSpacing.space4);
    expect(icon.center.dy, field.center.dy);
    expect(icon.left - input.right, 10);
    expect(input.left - field.left, 6);
    expect(tester.widget<Icon>(_searchIcon()).color, _colors.inkMuted);
    expect(
      tester.widget<TextField>(find.byType(TextField)).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('the input is a 48 target centred in the field', (tester) async {
    await _pump(tester, _field());
    final field = tester.getRect(find.byType(SearchField));
    final input = tester.getRect(find.byType(TextField));
    expect(input.height, AppSizes.targetMin);
    expect(input.center.dy, field.center.dy);
    final text = tester.getRect(find.byType(EditableText));
    expect(text.center.dy, closeTo(field.center.dy, 0.5));
  });

  testWidgets('text is 18/600 ink with an ink caret; the hint is the label, '
      '18/400 muted', (tester) async {
    await _pump(tester, _field());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontSize, 18);
    expect(field.style!.fontWeight, FontWeight.w600);
    expect(field.style!.color, _colors.ink);
    expect(field.style!.height, isNull);
    // .qk-search-input sets no caret-color, so the caret is its ink.
    expect(field.cursorColor, _colors.ink);
    expect(field.decoration!.border, InputBorder.none);
    expect(field.decoration!.filled, isNot(isTrue));
    expect(field.decoration!.hintText, _l10n.searchFieldHint);
    expect(field.decoration!.hintStyle!.fontSize, 18);
    expect(field.decoration!.hintStyle!.fontWeight, FontWeight.w400);
    expect(field.decoration!.hintStyle!.color, _colors.inkMuted);
    expect(field.textInputAction, TextInputAction.search);
    expect(find.text(_l10n.searchFieldHint), findsOneWidget);
  });

  testWidgets('reports typing and the search key', (tester) async {
    final changes = <String>[];
    final submitted = <String>[];
    await _pump(
      tester,
      _field(onChanged: changes.add, onSubmitted: submitted.add),
    );
    await tester.enterText(find.byType(TextField), _query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(changes, [_query]);
    expect(submitted, [_query]);
  });

  testWidgets('no button while empty; a 48 clear button once it has text', (
    tester,
  ) async {
    final controller = _controller();
    final changes = <String>[];
    await _pump(tester, _field(controller: controller, onChanged: changes.add));
    expect(find.byType(IconButton), findsNothing);

    await tester.enterText(find.byType(TextField), _query);
    await tester.pump();
    expect(changes, [_query]);
    final clear = tester.widget<IconButton>(find.byType(IconButton));
    expect(clear.icon, IconName.close);
    expect(clear.label, _l10n.searchFieldClear);
    expect(clear.iconSize, 22);
    expect(clear.tone, IconButtonTone.plain);
    final field = tester.getRect(find.byType(SearchField));
    final button = tester.getRect(find.byType(IconButton));
    expect(button.size, const Size.square(AppSizes.targetMin));
    expect(button.left - field.left, 6);
    expect(tester.getRect(find.byType(TextField)).left - button.right, 10);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes, [_query, '']);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('reads as a named text field and a named clear button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _field(text: _query));
    final field = tester.getSemantics(find.byType(EditableText));
    expect(field.label, _l10n.searchFieldHint);
    expect(field.value, _query);
    expect(field.flagsCollection.isTextField, isTrue);
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        label: _l10n.searchFieldClear,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the empty field is named once, by its hint', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _field());
    final field = tester.getSemantics(find.byType(EditableText));
    expect(field.label, _l10n.searchFieldHint);
    expect(field.value, isEmpty);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the clear button rings in keyboard mode only', (tester) async {
    await _pump(tester, _field(text: _query));
    expect(_ringDrawn(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('nothing clips at 200% on 360 wide, empty or with text', (
    tester,
  ) async {
    for (final text in ['', _query]) {
      await _pump(tester, _field(text: text), textScale: 2);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(SearchField));
      expect(field.height, greaterThanOrEqualTo(56));
      final input = tester.getRect(find.byType(EditableText));
      expect(input.top, greaterThanOrEqualTo(field.top));
      expect(input.bottom, lessThanOrEqualTo(field.bottom));
    }
  });
}
