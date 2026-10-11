@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('Tag in its four shapes, selected and not', (tester) async {
    await expectGoldensInThemes(tester, 'tag', (context) {
      final l10n = AppLocalizations.of(context);
      final colors = context.colors;
      final categories = [
        (TagShape.circle, l10n.tagMemorise, colors.primary),
        (TagShape.square, l10n.tagReview, colors.accent),
        (TagShape.diamond, l10n.tagStudy, colors.info),
        (TagShape.ring, l10n.tagImportant, colors.error),
      ];
      return goldenColumn([
        for (final selected in [true, false])
          Wrap(
            spacing: AppSpacing.space3,
            children: [
              for (final (shape, label, color) in categories)
                Tag(
                  label: label,
                  shape: shape,
                  color: color,
                  selected: selected,
                  onPressed: () {},
                ),
            ],
          ),
      ]);
    }, surfaceSize: const Size(520, 160));
  });
}
