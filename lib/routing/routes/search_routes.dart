import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/domain/use_cases/parse_direct_jump.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:holyquran/ui/features/search/views/search_screen.dart';
import 'package:provider/provider.dart';

/// The search screen under the study tab (`SR-01` to `SR-07`, `SR-10`). Its
/// repositories are read as optional: without a base pack the screen shows
/// its title alone, and without a history store it keeps no history.
final searchRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.study: [GoRoute(path: RoutePaths.search, builder: _search)],
  },
);

Widget _search(BuildContext context, GoRouterState state) {
  final search = context.read<SearchRepository?>();
  final text = context.read<QuranTextRepository?>();
  final index = context.read<QuranIndexRepository?>();
  if (search == null || text == null || index == null) {
    return const SearchScreen(viewModel: null);
  }
  // Read here: a provider's create callback may not depend on the locale.
  final l10n = AppLocalizations.of(context);
  return ChangeNotifierProvider(
    create: (context) => SearchViewModel(
      search: search,
      text: text,
      index: index,
      words: DirectJumpWords(
        surah: l10n.goToSurah,
        page: l10n.goToPage,
        juz: l10n.goToJuz,
        hizb: l10n.goToHizb,
        rub: l10n.goToRub,
      ),
      addresses: context.read<AddressInputRepository?>(),
      history: context.read<SearchHistoryRepository?>(),
      integrity: context.read<PackIntegrityRepository?>(),
    )..load(),
    builder: (context, _) => SearchScreen(viewModel: context.read()),
  );
}
