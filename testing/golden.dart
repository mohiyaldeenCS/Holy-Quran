// Golden tests carry `@Tags(['golden'])`. Their images are made only by the
// CI workflow started by hand with the task `goldens` on ubuntu-24.04, and
// compared by CI there. Sessions run `flutter test --exclude-tags golden test
// tools/gen/test` and never commit images made on another machine.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Compares [builder]'s widget, centred on the theme's ground, with
/// `goldens/<name>_<theme>.png` for every [ReadingTheme] in enum order.
Future<void> expectGoldensInThemes(
  WidgetTester tester,
  String name,
  WidgetBuilder builder, {
  Size surfaceSize = const Size(400, 300),
}) async {
  tester.view
    ..physicalSize = surfaceSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const root = ValueKey('golden-root');
  for (final theme in ReadingTheme.values) {
    await tester.pumpWidget(
      goldenApp(theme, Builder(builder: builder), key: root),
    );
    await expectLater(
      find.byKey(root),
      matchesGoldenFile('goldens/${name}_${theme.name}.png'),
    );
  }
}

/// The app a golden is drawn in: Arabic, right to left, [theme]'s Material
/// theme, and [child] centred on its ground. [key] marks the drawn surface.
Widget goldenApp(ReadingTheme theme, Widget child, {Key? key}) => MaterialApp(
  theme: buildAppTheme(theme),
  themeAnimationStyle: AnimationStyle.noAnimation,
  locale: const Locale('ar'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  debugShowCheckedModeBanner: false,
  home: _Ground(key: key, child: child),
);

/// Several states of a widget in one image, a fixed gap apart.
Widget goldenColumn(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  spacing: AppSpacing.space4,
  children: children,
);

final class _Ground extends StatelessWidget {
  const _Ground({required this.child, super.key});

  final Widget child;

  // Without a Material ancestor, WidgetsApp's fallback text style applies; the
  // theme's body style keeps text in the theme's ink.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: context.colors.ground,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!,
        child: Center(child: child),
      ),
    ),
  );
}
