@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('holding a word, with the clear button, and empty', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final filled = TextEditingController(text: l10n.sampleWord);
    final empty = TextEditingController();
    addTearDown(filled.dispose);
    addTearDown(empty.dispose);
    await expectGoldensInThemes(
      tester,
      'search_field',
      (context) => SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.space4,
          children: [
            for (final controller in [filled, empty])
              SearchField(
                controller: controller,
                onChanged: (_) {},
                onSubmitted: (_) {},
              ),
          ],
        ),
      ),
      surfaceSize: const Size(460, 180),
    );
  });
}
