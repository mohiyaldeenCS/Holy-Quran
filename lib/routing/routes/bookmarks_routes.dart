import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/note_location.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/bookmarks_view_model.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_drafts.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_sheet_view_model.dart';
import 'package:holyquran/ui/features/bookmarks/views/bookmarks_screen.dart';
import 'package:holyquran/ui/features/bookmarks/views/note_sheet_view.dart';
import 'package:provider/provider.dart';

/// The bookmarks and notes screen under «المزيد» (`UD-03`) and the note sheet
/// (`UD-04`). Their repositories are read as optional: without the user's
/// data the screen shows its title alone and the sheet closes at once. The
/// pack's text and index are optional too: without a base pack the cards
/// show no ayah and no way to open it.
final bookmarksRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.bookmarks, builder: _bookmarks)],
  },
  sheets: [
    SheetRoute(
      path: RoutePaths.noteSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
      builder: _note,
    ),
  ],
);

Widget _bookmarks(BuildContext context, GoRouterState state) {
  final bookmarks = context.read<BookmarkRepository?>();
  final notes = context.read<NoteRepository?>();
  final tags = context.read<TagRepository?>();
  final categories = context.read<CategoryRepository?>();
  if (bookmarks == null ||
      notes == null ||
      tags == null ||
      categories == null) {
    return const BookmarksScreen(viewModel: null);
  }
  return ChangeNotifierProvider(
    create: (context) => BookmarksViewModel(
      bookmarks: bookmarks,
      notes: notes,
      tags: tags,
      categories: categories,
      text: context.read<QuranTextRepository?>(),
      index: context.read<QuranIndexRepository?>(),
      integrity: context.read<PackIntegrityRepository?>(),
    ),
    builder: (context, _) => BookmarksScreen(viewModel: context.read()),
  );
}

Widget _note(BuildContext context, GoRouterState state) {
  final address = Routes.addressOf(state)!;
  final noteId = state.uri.queryParameters[noteParameter];
  return SheetNeeds(
    available: (context) =>
        context.read<NoteRepository?>() != null &&
        context.read<TagRepository?>() != null &&
        context.read<CategoryRepository?>() != null,
    child: ChangeNotifierProvider(
      create: (context) => NoteSheetViewModel(
        address: address,
        notes: context.read<NoteRepository>(),
        tags: context.read<TagRepository>(),
        categories: context.read<CategoryRepository>(),
        index: context.read<QuranIndexRepository?>(),
        integrity: context.read<PackIntegrityRepository?>(),
        drafts: context.read<NoteDrafts?>(),
        initialNoteId: noteId,
      ),
      builder: (context, _) => NoteSheetView(viewModel: context.read()),
    ),
  );
}
