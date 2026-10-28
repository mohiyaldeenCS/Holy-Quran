import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/data/services/licence_text_service.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/sources/view_models/sources_view_model.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';
import 'package:provider/provider.dart';

/// «المصادر والتراخيص» under «المزيد». It lists the sources of the base pack
/// and of the installed packs; until the app provides the link service and at
/// least one of them, the screen shows its title alone.
final sourcesRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.sources, builder: _sources)],
  },
);

Widget _sources(BuildContext context, GoRouterState state) {
  final basePack = context.read<VerifiedPack?>();
  final installs = context.read<PackInstallRepository?>();
  final links = context.read<LinkService?>();
  if (links == null || (basePack == null && installs == null)) {
    return const SourcesScreen(viewModel: null);
  }
  return ChangeNotifierProvider(
    create: (context) => SourcesViewModel(
      repository: PackSourcesRepository(
        links: links,
        licences: AssetLicenceTextService(),
        basePack: basePack?.manifest,
        installs: installs,
      ),
    ),
    builder: (context, _) => SourcesScreen(viewModel: context.read()),
  );
}
