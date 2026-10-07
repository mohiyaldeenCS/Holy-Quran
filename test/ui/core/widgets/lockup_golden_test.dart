@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';

import '../../../../testing/golden.dart';

Widget _onEmerald(Widget child) => ColoredBox(
  color: Ramps.emerald700,
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.space4),
    child: child,
  ),
);

void main() {
  testWidgets('Lockup sizes, stacked and on emerald', (tester) async {
    await expectGoldensInThemes(
      tester,
      'lockup',
      (context) => goldenColumn([
        const Lockup(),
        const Lockup(size: 32),
        _onEmerald(const Lockup(onEmerald: true)),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.space4,
          children: [
            const Lockup(stacked: true),
            _onEmerald(const Lockup(stacked: true, onEmerald: true)),
          ],
        ),
      ]),
      surfaceSize: const Size(420, 480),
    );
  });
}
