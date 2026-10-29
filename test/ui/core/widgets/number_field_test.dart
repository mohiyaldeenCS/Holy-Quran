import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/widgets/number_field.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

import '../../../../testing/golden.dart';

// An obviously synthetic label.
const _label = 'تسمية تجريبية';

Future<TextEditingController> _pump(
  WidgetTester tester, {
  required ValueChanged<String> onChanged,
  VoidCallback? onSubmitted,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      SizedBox(
        width: 300,
        child: NumberField(
          controller: controller,
          label: _label,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('is the search field box: 56 high, the label as its hint', (
    tester,
  ) async {
    await _pump(tester, onChanged: (_) {});

    expect(find.text(_label), findsOneWidget);
    expect(
      tester.getSize(find.byType(NumberField)).height,
      SearchFieldBox.height,
    );
  });

  testWidgets('reports what is typed, digits of any system', (tester) async {
    final typed = <String>[];
    await _pump(tester, onChanged: typed.add);
    await tester.enterText(find.byType(TextField), '٢٥٥');

    expect(typed, ['٢٥٥']);
  });

  testWidgets('submits from the keyboard', (tester) async {
    var submitted = 0;
    await _pump(tester, onChanged: (_) {}, onSubmitted: () => submitted++);
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(submitted, 1);
  });

  testWidgets('keeps its name once it holds text and the hint is gone', (
    tester,
  ) async {
    await _pump(tester, onChanged: (_) {});
    expect(find.bySemanticsLabel(_label), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1');
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(_label), findsOneWidget);
  });
}
