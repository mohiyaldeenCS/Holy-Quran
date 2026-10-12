import 'package:go_router/go_router.dart';

import 'package:holyquran/routing/routes.dart';

/// What one feature of D-101 adds to the route tree. The router composes
/// these, so a feature's task edits only its own `<feature>_routes.dart`.
final class FeatureRoutes {
  const FeatureRoutes({
    this.tabRoot,
    this.tabChildren = const {},
    this.sheets = const [],
    this.topLevel = const [],
  });

  /// The first screen of a tab, given by the feature that is the tab's hub.
  final TabRoot? tabRoot;

  /// Screens stacked over a tab's first screen, with paths relative to it.
  final Map<ShellTab, List<RouteBase>> tabChildren;

  /// Sheets any tab may push.
  final List<SheetRoute> sheets;

  /// Screens outside the shell.
  final List<RouteBase> topLevel;
}

final class TabRoot {
  const TabRoot(this.tab, this.builder);

  final ShellTab tab;
  final GoRouterWidgetBuilder builder;
}

/// A sheet shown as a modal bottom sheet on the root navigator. It is only
/// ever pushed; a cold start at its path goes to [owner] instead.
final class SheetRoute {
  const SheetRoute({
    required this.path,
    required this.builder,
    required this.owner,
  });

  /// One of the sheet paths of [RoutePaths].
  final String path;
  final GoRouterWidgetBuilder builder;

  /// The location of the screen the sheet belongs to. [state]'s parameters
  /// are already known to be well formed.
  final String Function(GoRouterState state) owner;
}
