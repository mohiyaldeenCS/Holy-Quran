import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/index/view_models/go_to_view_model.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';
import 'package:holyquran/ui/features/index/views/go_to_sheet.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';
import 'package:provider/provider.dart';

/// The index under «المصحف» (NV-01, NV-02) and the go-to sheet (NV-03). Their
/// repositories are read as optional: without a base pack the index shows its
/// title alone and the sheet closes at once.
final indexRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.mushaf: [GoRoute(path: RoutePaths.mushafIndex, builder: _index)],
  },
  sheets: [
    SheetRoute(
      path: RoutePaths.goToSheet,
      owner: (state) => Routes.mushaf,
      builder: _goTo,
    ),
  ],
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

Widget _goTo(BuildContext context, GoRouterState state) => SheetNeeds(
  available: (context) => context.read<QuranIndexRepository?>() != null,
  child: ChangeNotifierProvider(
    create: (context) =>
        GoToViewModel(index: context.read<QuranIndexRepository>()),
    builder: (context, _) => GoToSheet(viewModel: context.read()),
  ),
);
