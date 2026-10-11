@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('both tones, as ProgressBar/preview.html shows them', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'progress_bar', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 360,
        child: goldenColumn([
          ProgressBar(value: 0.7, height: 8, label: l10n.playerPosition),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.player,
              borderRadius: BorderRadius.circular(AppRadius.radiusButton),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: ProgressBar(
                value: 0.46,
                tone: ProgressBarTone.player,
                label: l10n.playerPosition,
              ),
            ),
          ),
        ]),
      );
    }, surfaceSize: const Size(400, 120));
  });
}
