@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('every icon at 28 in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'icon',
      (context) => SizedBox(
        width: 352,
        child: Wrap(
          spacing: AppSpacing.space4,
          runSpacing: AppSpacing.space4,
          children: [for (final name in IconName.values) Icon(name, size: 28)],
        ),
      ),
      surfaceSize: const Size(400, 240),
    );
  });
}
