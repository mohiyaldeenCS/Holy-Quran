import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';

/// Hosts the five tab branches.
///
/// The bar is a label-only placeholder until the identity's tab bar arrives
/// with the design system (M0.2).
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
    final labels = [
      l10n.tabHome,
      l10n.tabMushaf,
      l10n.tabListen,
      l10n.tabStudy,
      l10n.tabMore,
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Semantics(
        label: l10n.mainNavigationLabel,
        container: true,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelected,
          destinations: [
            for (final label in labels)
              NavigationDestination(
                icon: const SizedBox.shrink(),
                label: label,
              ),
          ],
        ),
      ),
    );
  }
}
