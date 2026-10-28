import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:provider/provider.dart';

/// The reader in surah mode, at the mushaf tab's root and at an address
/// (`NV-06`). Its view model reads the pack through repositories the app may
/// not provide yet; without them the reader shows no text.
final mushafRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.mushaf, (context, state) => _reader(context, null)),
  tabChildren: {
    ShellTab.mushaf: [
      GoRoute(
        path: RoutePaths.mushafRead,
        builder: (context, state) => _reader(context, Routes.addressOf(state)),
      ),
    ],
  },
);

Widget _reader(BuildContext context, QuranAddress? address) =>
    ChangeNotifierProvider(
      create: (context) => MushafViewModel(
        text: context.read<QuranTextRepository?>(),
        index: context.read<QuranIndexRepository?>(),
        integrity: context.read<PackIntegrityRepository?>(),
        address: address,
      ),
      // The screen listens to its view model itself.
      child: Builder(
        builder: (context) => MushafScreen(
          viewModel: Provider.of<MushafViewModel>(context, listen: false),
        ),
      ),
    );
