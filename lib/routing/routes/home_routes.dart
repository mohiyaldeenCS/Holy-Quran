import 'package:flutter/widgets.dart';

import 'package:holyquran/config/base_pack.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';

// The repositories are read as optional: without a base pack or a user
// database they are not provided, and home then shows no card.
final homeRoutes = FeatureRoutes(
  tabRoot: TabRoot(
    ShellTab.home,
    (context, state) => ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        positions: context.read<ReadingPositionRepository?>(),
        index: context.read<QuranIndexRepository?>(),
        integrity: context.read<PackIntegrityRepository?>(),
        listening: context.read<ListeningPositionRepository?>(),
        recitations: context.read<RecitationRepository?>(),
        player: context.read<PlayerRepository?>(),
        plans: context.read<PlaybackPlanBuilder?>(),
        basePackId: bundledBasePack?.id,
      ),
      // The screen listens to its view model itself.
      child: Builder(
        builder: (context) => HomeScreen(
          viewModel: Provider.of<HomeViewModel>(context, listen: false),
        ),
      ),
    ),
  ),
);
