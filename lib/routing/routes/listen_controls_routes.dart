import 'package:flutter/widgets.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/play_options_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/range_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/play_options_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/range_sheet.dart';
import 'package:provider/provider.dart';

/// The player's control sheets (M1.9).
final listenControlsRoutes = FeatureRoutes(
  sheets: [
    SheetRoute(
      path: RoutePaths.rangeSheet,
      owner: _player,
      builder: (context, state) => _Scoped(
        create: (context) => RangeSheetViewModel(
          player: context.read(),
          builder: context.read(),
          index: context.read(),
        ),
        builder: (viewModel) => RangeSheet(viewModel: viewModel),
      ),
    ),
    SheetRoute(
      path: RoutePaths.playOptionsSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
      builder: (context, state) => PlayOptionsSheet(
        viewModel: PlayOptionsViewModel(
          address: Routes.addressOf(state)!,
          player: context.read<PlayerRepository>(),
          builder: context.read<PlaybackPlanBuilder>(),
          index: context.read<QuranIndexRepository>(),
        ),
      ),
    ),
  ],
);

String _player(Object _) => Routes.listen;

/// Creates a sheet's view model once, so that the route rebuilding its page
/// keeps what the user has set, and disposes of it with the sheet.
class _Scoped<T extends ChangeNotifier> extends StatefulWidget {
  const _Scoped({required this.create, required this.builder, super.key});

  final T Function(BuildContext context) create;
  final Widget Function(T viewModel) builder;

  @override
  State<_Scoped<T>> createState() => _ScopedState<T>();
}

class _ScopedState<T extends ChangeNotifier> extends State<_Scoped<T>> {
  late final T _viewModel = widget.create(context);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_viewModel);
}
