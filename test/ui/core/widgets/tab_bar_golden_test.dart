@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';

import '../../../../testing/golden.dart';

Widget _bar(BuildContext context, int current) {
  final l10n = AppLocalizations.of(context);
  return TabBar(
    items: [
      TabBarItem(IconName.home, l10n.tabHome),
      TabBarItem(IconName.mushaf, l10n.tabMushaf),
      TabBarItem(IconName.listen, l10n.tabListen),
      TabBarItem(IconName.study, l10n.tabStudy),
      TabBarItem(IconName.more, l10n.tabMore),
    ],
    currentIndex: current,
    onSelected: (_) {},
    semanticLabel: l10n.mainNavigationLabel,
  );
}

void main() {
  testWidgets('home current, in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'tab_bar_home',
      (context) => _bar(context, 0),
      surfaceSize: const Size(360, 120),
    );
  });

  testWidgets('study current, in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'tab_bar_study',
      (context) => _bar(context, 3),
      surfaceSize: const Size(360, 120),
    );
  });
}
