import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/view_models/surah_info_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/surah_info_sheet.dart';
import 'package:provider/provider.dart';

/// The reader in surah mode, at the mushaf tab's root and at an address
/// (`NV-06`), and the sheet «مقدمة السورة». Their view models read the pack
/// through repositories the app may not provide yet; without them the reader
/// shows no text and the sheet is empty.
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
  sheets: [
    SheetRoute(
      path: RoutePaths.surahInfoSheet,
      builder: (context, state) => SheetNeeds(
        available: (context) => context.read<QuranIndexRepository?>() != null,
        child: ChangeNotifierProvider(
          create: (context) => SurahInfoViewModel(
            surah: Routes.surahOf(state)!,
            index: context.read<QuranIndexRepository?>(),
            integrity: context.read<PackIntegrityRepository?>(),
          ),
          child: Builder(
            builder: (context) => SurahInfoSheet(
              viewModel: Provider.of<SurahInfoViewModel>(
                context,
                listen: false,
              ),
            ),
          ),
        ),
      ),
      owner: (state) => Routes.mushaf,
    ),
  ],
);

Widget _reader(BuildContext context, QuranAddress? address) =>
    ChangeNotifierProvider(
      create: (context) => MushafViewModel(
        text: context.read<QuranTextRepository?>(),
        index: context.read<QuranIndexRepository?>(),
        positions: context.read<ReadingPositionRepository?>(),
        integrity: context.read<PackIntegrityRepository?>(),
        address: address,
        settings: context.read<AppSettingsRepository?>(),
        bookmarks: context.read<BookmarkRepository?>(),
        categories: context.read<CategoryRepository?>(),
        keepAwake: context.read<KeepAwakeRepository?>(),
        tools: _ayahTools(context),
      ),
      // The screen listens to its view model itself.
      child: Builder(
        builder: (context) => MushafScreen(
          viewModel: Provider.of<MushafViewModel>(context, listen: false),
        ),
      ),
    );

// The tools whose sheets read objects that only a verified base pack, or the
// player, provide; an entry point hides what cannot work (D-138, 3).
AyahTools _ayahTools(BuildContext context) {
  final hasText = context.read<QuranTextRepository?>() != null;
  return AyahTools(
    play:
        context.read<PlayerRepository?>() != null &&
        context.read<PlaybackPlanBuilder?>() != null &&
        context.read<QuranIndexRepository?>() != null,
    copy: hasText && context.read<ClipboardService?>() != null,
    share: hasText && context.read<ShareService?>() != null,
  );
}
