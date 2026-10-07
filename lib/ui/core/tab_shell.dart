import 'package:flutter/material.dart' hide TabBar;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';

/// Hosts the five tab branches under the identity's [TabBar]. Tapping the
/// current tab returns its branch to the branch's first screen.
class TabShell extends StatelessWidget {
  const TabShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onSelected(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: TabBar(
        items: [
          TabBarItem(IconName.home, l10n.tabHome),
          TabBarItem(IconName.mushaf, l10n.tabMushaf),
          TabBarItem(IconName.listen, l10n.tabListen),
          TabBarItem(IconName.study, l10n.tabStudy),
          TabBarItem(IconName.more, l10n.tabMore),
        ],
        currentIndex: navigationShell.currentIndex,
        onSelected: _onSelected,
        semanticLabel: l10n.mainNavigationLabel,
      ),
    );
  }
}
