import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/sources/view_models/sources_view_model.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';
import 'package:provider/provider.dart';

/// «المصادر والتراخيص» under «المزيد». Until the app provides the installer
/// and the link service, the screen shows its title alone.
final sourcesRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.sources, builder: _sources)],
  },
);

Widget _sources(BuildContext context, GoRouterState state) {
  final installs = context.read<PackInstallRepository?>();
  final links = context.read<LinkService?>();
  if (installs == null || links == null) {
    return const SourcesScreen(viewModel: null);
  }
  return ChangeNotifierProvider(
    create: (context) => SourcesViewModel(installs: installs, links: links),
    builder: (context, _) => SourcesScreen(viewModel: context.read()),
  );
}
