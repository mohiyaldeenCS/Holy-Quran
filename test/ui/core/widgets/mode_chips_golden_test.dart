@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the second mode selected, as its preview shows it', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'mode_chips', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 520,
        child: ModeChips(
          label: l10n.searchModesLabel,
          options: [
            l10n.searchModeWord,
            l10n.searchModeRoot,
            l10n.searchModeBare,
            l10n.searchModeDerived,
            l10n.searchModeTafsir,
          ],
          selectedIndex: 1,
          onChanged: (_) {},
        ),
      );
    }, surfaceSize: const Size(560, 100));
  });
}
