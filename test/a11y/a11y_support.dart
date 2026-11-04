import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

/// The view sizes of NF-11: a phone and a tablet, each both ways up, and the
/// narrowest phone the 200% text of AX-04 is judged on.
const phonePortrait = Size(390, 844);
const phoneLandscape = Size(844, 390);
const tabletPortrait = Size(768, 1024);
const tabletLandscape = Size(1024, 768);
const narrowPhone = Size(320, 640);

/// A view and the system text scale a screen is drawn at.
typedef A11yView = ({String name, Size size, double textScale});

const List<A11yView> a11yViews = [
  (name: 'phone portrait', size: phonePortrait, textScale: 1),
  (name: 'phone landscape', size: phoneLandscape, textScale: 1),
  (name: 'tablet portrait', size: tabletPortrait, textScale: 1),
  (name: 'tablet landscape', size: tabletLandscape, textScale: 1),
  (name: '320 wide at 200%', size: narrowPhone, textScale: 2),
];

/// A screen in a state that has data, drawn by the harness it already has.
typedef A11yScreen = ({
  String name,
  Future<void> Function(WidgetTester tester, Size size, double textScale) pump,
});

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Markers and marks inside text are 26 px by the identity and exempt from the
// 48 px target under D-097 (WCAG 2.5.8, inline exception); their tap zone is
// the reader's, and the ayah's own node carries the same action at full size.
final RegExp _insideText = RegExp(
  'label: "${RegExp.escape(_l10n.ayahMarkerLabel('').trim())} ',
);

/// Fails on a framework exception, such as an overflow, and on any node
/// [guideline] rejects, but those of markers (D-097, D-169).
Future<void> _expectGuideline(
  WidgetTester tester,
  AccessibilityGuideline guideline,
  String what,
) async {
  final evaluation = await guideline.evaluate(tester);
  if (evaluation.passed) return;
  final nodes = (evaluation.reason ?? '')
      .split('\n')
      .where((line) => line.startsWith('SemanticsNode'))
      .toList();
  expect(nodes, isNotEmpty, reason: 'unreadable failure: ${evaluation.reason}');
  final failures = nodes.where((line) => !_insideText.hasMatch(line));
  expect(failures, isEmpty, reason: what);
}

Iterable<SemanticsNode> _nodes(SemanticsNode root) sync* {
  yield root;
  final children = <SemanticsNode>[];
  root.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield* _nodes(child);
  }
}

SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

bool _isInsideText(SemanticsNode node) => _insideText.hasMatch(node.toString());

/// The nodes a screen reader can tap that a keyboard cannot reach: a tap
/// action with no focus action (WCAG 2.1.1, `AX-09`). Markers are exempt: the
/// ayah's node beside each activates the same ayah. So is a sheet's barrier,
/// which a keyboard dismisses with Escape.
List<String> tapWithoutFocus(WidgetTester tester) => [
  for (final node in _nodes(_root(tester)))
    if (!node.isMergedIntoParent &&
        !node.flagsCollection.isHidden &&
        node.getSemanticsData().hasAction(SemanticsAction.tap) &&
        !node.getSemanticsData().hasAction(SemanticsAction.focus) &&
        !node.getSemanticsData().hasAction(SemanticsAction.dismiss) &&
        !node.flagsCollection.isTextField &&
        !_isInsideText(node))
      '$node',
];

/// What every screen owes at every size: no overflow, a 48 px target and a
/// name for each tap target (`AX-01`, `AX-02`, `AX-04`, `NF-11`), right to
/// left and Arabic only (`NF-18`).
Future<void> expectAccessible(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await _expectGuideline(tester, androidTapTargetGuideline, 'tap target');
  await _expectGuideline(tester, labeledTapTargetGuideline, 'label');
  expectRightToLeft(tester);
  expectArabicDigits(tester);
}

void expectRightToLeft(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  expect(Directionality.of(context), TextDirection.rtl);
  expect(Localizations.localeOf(context).languageCode, 'ar');
}

final RegExp _latinLetter = RegExp('[A-Za-z]');
final RegExp _latinDigit = RegExp('[0-9]');

/// No Latin digit in a visible string. Strings with Latin letters are the
/// synthetic fixtures' own names, not the interface's.
void expectArabicDigits(WidgetTester tester) {
  final strings = <String>[
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null) text.data!,
    for (final node in _nodes(_root(tester)))
      if (!node.flagsCollection.isHidden) node.label,
  ];
  expect(
    strings.where((s) => s.contains(_latinDigit) && !s.contains(_latinLetter)),
    isEmpty,
  );
}

/// How many stops Tab visits before it comes round, and whether the identity's
/// ring (or a text field's own focus ring, `:focus-within`) shows at each.
/// Gives the stops as the rects they cover.
Future<List<Rect>> tabAround(
  WidgetTester tester, {
  int limit = 80,
  bool comesRound = true,
}) async {
  final stops = <Rect>[];
  FocusNode? first;
  for (var i = 0; i < limit; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final focus = FocusManager.instance.primaryFocus;
    // A route with nothing to focus gives focus to its own scope.
    if (focus == null || focus is FocusScopeNode) {
      if (stops.isEmpty && i >= 2) return stops;
      continue;
    }
    if (identical(focus, first)) return stops;
    first ??= focus;
    final inField =
        focus.context?.findAncestorWidgetOfExactType<EditableText>() != null ||
        focus.context?.widget is EditableText;
    expect(
      inField || focusRingDrawn(tester),
      isTrue,
      reason:
          'stop ${stops.length + 1} shows no focus ring: '
          '${focus.rect}',
    );
    stops.add(focus.rect);
  }
  if (comesRound) fail('Tab did not come round in $limit presses');
  return stops;
}

bool focusRingDrawn(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(FocusRing),
        matching: find.byType(CustomPaint),
      ),
    )
    .any(
      (paint) =>
          paint.foregroundPainter is FocusRingPainter ||
          paint.painter is FocusRingPainter,
    );

/// The nodes a screen reader can tap, markers apart.
int tappableCount(WidgetTester tester) => _nodes(_root(tester))
    .where(
      (node) =>
          !node.isMergedIntoParent &&
          !node.flagsCollection.isHidden &&
          node.getSemanticsData().hasAction(SemanticsAction.tap) &&
          !node.getSemanticsData().hasAction(SemanticsAction.dismiss) &&
          !_isInsideText(node),
    )
    .length;

/// Every tap target is reached by Tab, and each stop shows its ring.
///
/// A [long] screen, whose text goes on past anything built, is judged on its
/// first [longStops] stops, since Tab would not come round.
Future<void> expectKeyboardReach(
  WidgetTester tester, {
  bool long = false,
  int longStops = 12,
}) async {
  expect(tapWithoutFocus(tester), isEmpty);
  final stops = await tabAround(
    tester,
    limit: long ? longStops : 80,
    comesRound: !long,
  );
  if (long) {
    expect(stops, isNotEmpty);
  } else {
    expect(stops.length, greaterThanOrEqualTo(tappableCount(tester)));
  }
}

/// The system asks for no animation (`AX-06`).
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
