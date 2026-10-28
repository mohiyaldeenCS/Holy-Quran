import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';
import 'package:provider/provider.dart';

/// The index under «المصحف» (NV-01, NV-02). Its repositories are read as
/// optional: without a base pack the screen shows its title alone.
final indexRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.mushaf: [GoRoute(path: RoutePaths.mushafIndex, builder: _index)],
  },
);

Widget _index(BuildContext context, GoRouterState state) {
  final index = context.read<QuranIndexRepository?>();
  if (index == null) return const IndexScreen(viewModel: null);
  return ChangeNotifierProvider(
    create: (context) => IndexViewModel(
      index: index,
      positions: context.read<ReadingPositionRepository?>(),
      integrity: context.read<PackIntegrityRepository?>(),
    ),
    builder: (context, _) => IndexScreen(viewModel: context.read()),
  );
}
