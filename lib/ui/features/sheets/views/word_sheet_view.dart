import 'package:flutter/widgets.dart';

import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/view_models/word_sheet_view_model.dart';
import 'package:holyquran/ui/features/sheets/views/tafsir_passage_block.dart';

/// The word sheet of the word in [viewModel] (`LX-01`, `LX-11`): the
/// identity's `WordSheet` with the tabs of the installed packs. The text tab
/// shows the word and its place in the ayah and no rows, since no source of
/// word-level facts is ready; the tafsir tab shows the ayah's passage. The
/// sheet closes when the pack stops serving the word.
class WordSheetView extends StatelessWidget {
  const WordSheetView({required this.viewModel, super.key});

  final WordSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      if (viewModel.unavailable) {
        return SheetNeeds(available: (_) => false, child: const SizedBox());
      }
      final ayah = viewModel.ayahText;
      final span = viewModel.span;
      final number = viewModel.address.word;
      if (!viewModel.loaded || ayah == null || span == null || number == null) {
        return const CopySheetFrame(children: []);
      }
      final tab = viewModel.selectedTab;
      return WordSheet(
        word: ayah,
        span: span,
        wordNumber: number,
        wordCount: viewModel.wordCount,
        tabs: viewModel.tabs,
        selectedTab: tab,
        onTabSelected: viewModel.select,
        body: tab == WordSheetTab.tafsir
            ? TafsirPassageBlock(tafsir: viewModel.tafsir)
            : null,
      );
    },
  );
}
