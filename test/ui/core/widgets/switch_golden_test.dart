@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('off and on in each theme', (tester) async {
    await expectGoldensInThemes(tester, 'switch', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 320,
        child: goldenColumn([
          Switch(label: l10n.tabListen, value: false, onChanged: (_) {}),
          Switch(label: l10n.tabStudy, value: true, onChanged: (_) {}),
        ]),
      );
    }, surfaceSize: const Size(360, 160));
  });
}
