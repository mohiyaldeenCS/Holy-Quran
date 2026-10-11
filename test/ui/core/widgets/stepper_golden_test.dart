@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('Stepper between its bounds, at each bound, with a unit', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'stepper', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stepper(
              label: l10n.galleryStepperRepeat,
              value: 7,
              max: 20,
              onChanged: (_) {},
            ),
            Stepper(
              label: l10n.galleryStepperMerge,
              value: 1,
              max: 10,
              onChanged: (_) {},
            ),
            Stepper(
              label: l10n.galleryStepperSilence,
              value: 10,
              min: 0,
              max: 10,
              unit: l10n.galleryStepperSeconds,
              onChanged: (_) {},
            ),
          ],
        ),
      );
    }, surfaceSize: const Size(400, 240));
  });
}
