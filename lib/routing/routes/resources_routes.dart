import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/resources/view_models/first_use_tafsir_view_model.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/first_use_tafsir_sheet.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:provider/provider.dart';

/// The resource manager under «المزيد» and the first-use tafsir sheet.
/// Each builds its view model on the repositories the app provides; until
/// it provides them, the screen shows its title alone and the sheet is
/// empty.
final resourcesRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.resources, builder: _resources)],
  },
  sheets: [
    SheetRoute(
      path: RoutePaths.firstUseTafsirSheet,
      builder: _firstUseTafsir,
      owner: (state) => Routes.resources,
    ),
  ],
);

Widget _resources(BuildContext context, GoRouterState state) {
  final catalogue = context.read<CatalogueRepository?>();
  final installs = context.read<PackInstallRepository?>();
  final integrity = context.read<PackIntegrityRepository?>();
  if (catalogue == null || installs == null || integrity == null) {
    return const ResourcesScreen(viewModel: null);
  }
  return ChangeNotifierProvider(
    create: (context) => ResourcesViewModel(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      freeBytes: _freeBytes,
    ),
    builder: (context, _) => ResourcesScreen(viewModel: context.read()),
  );
}

Widget _firstUseTafsir(BuildContext context, GoRouterState state) {
  final catalogue = context.read<CatalogueRepository?>();
  final installs = context.read<PackInstallRepository?>();
  if (catalogue == null || installs == null) return const SizedBox.shrink();
  return ChangeNotifierProvider(
    create: (context) =>
        FirstUseTafsirViewModel(catalogue: catalogue, installs: installs),
    builder: (context, _) => FirstUseTafsirSheet(viewModel: context.read()),
  );
}

/// The free space of the volume the packs are installed on; null when the
/// directory cannot be found.
Future<int?> _freeBytes() async {
  try {
    return await const DiskFreeSpaceService().freeBytesAt(
      await applicationSupportPath(),
    );
  } on Exception {
    return null;
  }
}
