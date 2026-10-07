@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('every variant, with an icon and disabled, in each theme', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'button', (context) {
      final l10n = AppLocalizations.of(context);
      return goldenColumn([
        for (final variant in ButtonVariant.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.space3,
            children: [
              Button(label: l10n.tabMushaf, onPressed: () {}, variant: variant),
              Button(
                label: l10n.tabListen,
                onPressed: () {},
                variant: variant,
                icon: IconName.play,
              ),
              Button(label: l10n.tabStudy, onPressed: null, variant: variant),
            ],
          ),
      ]);
    }, surfaceSize: const Size(440, 320));
  });
}
