@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('each item selected in turn, in each theme', (tester) async {
    await expectGoldensInThemes(tester, 'level_switch', (context) {
      final l10n = AppLocalizations.of(context);
      final options = [l10n.tabMushaf, l10n.tabListen, l10n.tabStudy];
      return SizedBox(
        width: 328,
        child: goldenColumn([
          for (var selected = 0; selected < options.length; selected++)
            LevelSwitch(
              options: options,
              selectedIndex: selected,
              onChanged: (_) {},
              semanticLabel: l10n.mainNavigationLabel,
            ),
        ]),
      );
    }, surfaceSize: const Size(360, 220));
  });
}
