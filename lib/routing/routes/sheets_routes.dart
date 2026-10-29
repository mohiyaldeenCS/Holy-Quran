import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_sheet_view_model.dart';
import 'package:holyquran/ui/features/sheets/view_models/word_sheet_view_model.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';
import 'package:holyquran/ui/features/sheets/views/word_sheet_view.dart';
import 'package:provider/provider.dart';

/// The word sheet (`LX-01`), which a word tap opens at the medium and study
/// levels, and the mini ayah sheet (`ST-01`), which the toolbar's study
/// button opens. Both read the text pack and close at once without one. The
/// tafsir repository, the user's notes and the player are read as optional:
/// a section whose data the app does not provide is not shown.
final sheetsRoutes = FeatureRoutes(
  sheets: [
    SheetRoute(
      path: RoutePaths.wordSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!.ayahAddress),
      builder: _word,
    ),
    SheetRoute(
      path: RoutePaths.ayahSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!.ayahAddress),
      builder: _ayah,
    ),
  ],
);

Widget _word(BuildContext context, GoRouterState state) {
  final address = Routes.addressOf(state)!;
  return SheetNeeds(
    available: (context) =>
        address.isWord && context.read<QuranTextRepository?>() != null,
    child: ChangeNotifierProvider(
      create: (context) => WordSheetViewModel(
        address: address,
        text: context.read<QuranTextRepository>(),
        tafsirs: context.read<TafsirRepository?>(),
        integrity: context.read<PackIntegrityRepository?>(),
      ),
      builder: (context, _) => WordSheetView(viewModel: context.read()),
    ),
  );
}

Widget _ayah(BuildContext context, GoRouterState state) {
  final address = Routes.addressOf(state)!;
  return SheetNeeds(
    available: (context) => context.read<QuranTextRepository?>() != null,
    child: ChangeNotifierProvider(
      create: (context) => AyahSheetViewModel(
        address: address,
        text: context.read<QuranTextRepository>(),
        tafsirs: context.read<TafsirRepository?>(),
        notes: _notes(context),
        player: _player(context),
        integrity: context.read<PackIntegrityRepository?>(),
      ),
      builder: (context, _) => AyahSheetView(viewModel: context.read()),
    ),
  );
}

// The note sheet needs the tags and categories as well, so notes are offered
// only where it can open (D-138, 3).
NoteRepository? _notes(BuildContext context) =>
    context.read<TagRepository?>() != null &&
        context.read<CategoryRepository?>() != null
    ? context.read<NoteRepository?>()
    : null;

// The play options sheet needs the same objects as the toolbar's play.
PlayerRepository? _player(BuildContext context) =>
    context.read<PlaybackPlanBuilder?>() != null &&
        context.read<QuranIndexRepository?>() != null
    ? context.read<PlayerRepository?>()
    : null;
