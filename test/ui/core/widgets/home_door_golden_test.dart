@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the two Phase 1 doors in a four-column row, in each theme', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'home_door', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 350,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.space2,
          children: [
            Expanded(
              child: HomeDoor(
                icon: IconName.indexIcon,
                label: l10n.homeDoorIndex,
                onPressed: () {},
              ),
            ),
            Expanded(
              child: HomeDoor(
                icon: IconName.bookmark,
                label: l10n.homeDoorBookmarks,
                onPressed: () {},
              ),
            ),
            const Spacer(),
            const Spacer(),
          ],
        ),
      );
    }, surfaceSize: const Size(390, 140));
  });
}
