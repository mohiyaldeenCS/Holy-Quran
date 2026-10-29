@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/widgets/number_field.dart';

import '../../../../testing/golden.dart';

// An obviously synthetic label.
const _label = 'تسمية تجريبية';

void main() {
  testWidgets('empty with its hint, and holding a number', (tester) async {
    final empty = TextEditingController();
    final filled = TextEditingController(text: '٢٥٥');
    addTearDown(empty.dispose);
    addTearDown(filled.dispose);
    await expectGoldensInThemes(
      tester,
      'number_field',
      (context) => SizedBox(
        width: 320,
        child: goldenColumn([
          for (final controller in [empty, filled])
            NumberField(
              controller: controller,
              label: _label,
              onChanged: (_) {},
            ),
        ]),
      ),
      surfaceSize: const Size(400, 200),
    );
  });
}
