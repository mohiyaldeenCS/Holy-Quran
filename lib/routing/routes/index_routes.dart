import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/index/view_models/context_sheet_view_model.dart';
import 'package:holyquran/ui/features/index/view_models/go_to_view_model.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';
import 'package:holyquran/ui/features/index/views/context_sheet_view.dart';
import 'package:holyquran/ui/features/index/views/go_to_sheet.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';
import 'package:provider/provider.dart';

/// The index under «المصحف» (NV-01, NV-02), the go-to sheet (NV-03) and the
/// ayah-context sheet (NV-05). Their repositories are read as optional:
/// without a base pack the index shows its title alone and the sheets close at
/// once.
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
    SheetRoute(
      path: RoutePaths.contextSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
      builder: _context,
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

Widget _context(BuildContext context, GoRouterState state) {
  final address = Routes.addressOf(state)!;
  return SheetNeeds(
    available: (context) {
      final index = context.read<QuranIndexRepository?>();
      return index != null &&
          context.read<QuranTextRepository?>() != null &&
          ContextSheetViewModel.canShow(index, address);
    },
    child: ChangeNotifierProvider(
      create: (context) => ContextSheetViewModel(
        address: address,
        text: context.read<QuranTextRepository>(),
        index: context.read<QuranIndexRepository>(),
        integrity: context.read<PackIntegrityRepository?>(),
      ),
      builder: (context, _) => ContextSheetView(viewModel: context.read()),
    ),
  );
}
