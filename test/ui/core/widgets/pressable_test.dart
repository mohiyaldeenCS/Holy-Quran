import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _radius = BorderRadius.circular(AppRadius.radiusButton);
const _face = ValueKey('face');

Widget _pressable(VoidCallback? onPressed) => Semantics(
  container: true,
  label: _l10n.tabHome,
  child: Pressable(
    onPressed: onPressed,
    focusRadius: _radius,
    child: const SizedBox(key: _face, width: 120, height: AppSizes.targetMin),
  ),
);

Future<void> _pump(WidgetTester tester, VoidCallback? onPressed) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, _pressable(onPressed)));

Future<void> _focusByKeyboard(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

bool _ringDrawn(WidgetTester tester) =>
    tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(FocusRing),
            matching: find.byType(CustomPaint),
          ),
        )
        .foregroundPainter !=
    null;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('calls onPressed when tapped anywhere on its child', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, () => presses++);

    await tester.tap(find.byKey(_face));
    await tester.tapAt(
      tester.getTopLeft(find.byKey(_face)) + const Offset(1, 1),
    );
    expect(presses, 2);
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('calls onPressed on ${key.keyLabel} with keyboard focus', (
      tester,
    ) async {
      var presses = 0;
      await _pump(tester, () => presses++);

      await _focusByKeyboard(tester);
      await tester.sendKeyEvent(key);
      expect(presses, 1);
    });
  }

  testWidgets('shows the click cursor, the basic one when disabled', (
    tester,
  ) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await _pump(tester, () {});
    await mouse.addPointer(location: tester.getCenter(find.byKey(_face)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );

    await _pump(tester, null);
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, () {});
    expect(_ringDrawn(tester), isFalse);

    await _focusByKeyboard(tester);
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(_ringDrawn(tester), isTrue);
    final ring = tester.widget<FocusRing>(find.byType(FocusRing));
    expect(ring.radius, _radius);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('disabled: no tap, no keyboard focus, no activation', (
    tester,
  ) async {
    await _pump(tester, null);

    await tester.tap(find.byKey(_face), warnIfMissed: false);
    await _focusByKeyboard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(_ringDrawn(tester), isFalse);
    expect(
      tester
          .widget<FocusableActionDetector>(find.byType(FocusableActionDetector))
          .enabled,
      isFalse,
    );
  });

  testWidgets('joins the caller node as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () {});
    expect(
      tester.getSemantics(find.byType(Pressable)),
      matchesSemantics(
        label: _l10n.tabHome,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('reads as disabled when it is', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, null);
    expect(
      tester.getSemantics(find.byType(Pressable)),
      matchesSemantics(
        label: _l10n.tabHome,
        isButton: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });
}
