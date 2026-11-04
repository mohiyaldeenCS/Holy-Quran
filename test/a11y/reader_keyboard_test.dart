import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/reader/reader_block.dart';

import 'a11y_support.dart';
import 'screens.dart';

// D-169 (1): the reader's ayat take keyboard focus, show the focus ring round
// their rectangle, scroll into view, and Enter or Space activates them.
void main() {
  final world = A11yWorld();
  setUpAll(world.open);
  tearDownAll(world.close);

  bool inAyah(FocusNode focus) =>
      focus.context?.findAncestorWidgetOfExactType<ReaderBlock>() != null;

  Future<FocusNode> tabToAyah(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      if (focus != null && inAyah(focus)) return focus;
    }
    fail('Tab reached no ayah');
  }

  testWidgets('an ayah takes focus, shows its ring and stays in view', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final screen = world.screens.firstWhere((s) => s.name == 'reader');
    await screen.pump(tester, phonePortrait, 1);

    final focus = await tabToAyah(tester);

    expect(focusRingDrawn(tester), isTrue);
    expect(focus.rect.top, greaterThanOrEqualTo(0));
    expect(focus.rect.bottom, lessThanOrEqualTo(phonePortrait.height));
    final node = tester.getSemantics(find.byWidget(focus.context!.widget));
    expect(node.getSemanticsData().hasAction(SemanticsAction.focus), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('${key.keyLabel} on a focused ayah activates it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final screen = world.screens.firstWhere((s) => s.name == 'reader');
      await screen.pump(tester, phonePortrait, 1);
      expect(world.readerModel!.selectedAyah, isNull);

      await tabToAyah(tester);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();

      expect(world.readerModel!.selectedAyah, isNotNull);
      handle.dispose();
    });
  }
}
