@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the three states, as ResourceRow/preview.html lists them', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'resource_row', (context) {
      final l10n = AppLocalizations.of(context);
      final colors = context.colors;
      // ResourceRow/preview.html: a surface card, radius 24, padded 8 by 24.
      return Container(
        width: 380,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.space2,
          horizontal: AppSpacing.space5,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppRadius.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResourceRow(
              title: l10n.sampleResourceTitle,
              status: ResourceStatus.downloaded,
              size: l10n.sampleSize,
              onAction: () {},
            ),
            ResourceRow(
              title: l10n.sampleResourceTitle,
              status: ResourceStatus.downloading,
              progress: 0.6,
            ),
            ResourceRow(
              title: l10n.sampleResourceTitle,
              status: ResourceStatus.available,
              size: l10n.sampleSize,
              onAction: () {},
              divider: false,
            ),
          ],
        ),
      );
    }, surfaceSize: const Size(420, 320));
  });
}
