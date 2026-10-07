@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('every tone at 48 and drawn at 40, in each theme', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'icon_button', (context) {
      final l10n = AppLocalizations.of(context);
      return goldenColumn([
        for (final size in const [AppSizes.targetMin, 40.0])
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.space3,
            children: [
              for (final (tone, icon) in const [
                (IconButtonTone.plain, IconName.bookmark),
                (IconButtonTone.tint, IconName.search),
                (IconButtonTone.solid, IconName.play),
              ])
                IconButton(
                  icon: icon,
                  label: l10n.tabHome,
                  onPressed: () {},
                  tone: tone,
                  size: size,
                ),
            ],
          ),
      ]);
    }, surfaceSize: const Size(240, 160));
  });
}
