import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/bookmarks_view_model.dart';
import 'package:holyquran/ui/features/bookmarks/views/bookmarks_screen.dart';
import 'package:provider/provider.dart';

/// The bookmarks and notes screen under «المزيد» (`UD-03`). Its repositories
/// are read as optional: without the user's data the screen shows its title
/// alone. The pack's text and index are optional too: without a base pack the
/// cards show no ayah and no way to open it.
final bookmarksRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.bookmarks, builder: _bookmarks)],
  },
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
    ),
    builder: (context, _) => BookmarksScreen(viewModel: context.read()),
  );
}
