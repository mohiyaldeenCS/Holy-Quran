import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';

// WordSheet/preview.html: «الكلمة ٢ من ٢»; WordSheet in index.jsx:
// `activeTab = 2`, the third tab.
const int _wordNumber = 2;
const int _wordCount = 2;
const WordSheetTab _initialTab = WordSheetTab.irab;
// The preview's four rows, each the synthetic label and value here.
const int _sampleRows = 4;
// ModeChips/preview.html: `defaultValue: 1`.
const int _initialMode = 1;
// SearchResult/preview.html: ayat 45 and 153, and 61 clamped.
const List<({int ayah, bool clamp})> _results = [
  (ayah: 45, clamp: false),
  (ayah: 153, clamp: false),
  (ayah: 61, clamp: true),
];
// SearchResult/preview.html: the results column has `gap: 10`.
const double _resultGap = 10;

/// The gallery's study and search section: `WordSheet`, `SearchField`,
/// `ModeChips`, `SearchSummary` and `SearchResult`, as their previews show
/// them, on synthetic text.
class StudySearchGallery extends StatefulWidget {
  const StudySearchGallery({super.key});

  @override
  State<StudySearchGallery> createState() => _StudySearchGalleryState();
}

class _StudySearchGalleryState extends State<StudySearchGallery> {
  final TextEditingController _filled = TextEditingController();
  final TextEditingController _empty = TextEditingController();
  WordSheetTab _tab = _initialTab;
  int _mode = _initialMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SearchField/preview.html: the first field holds a word, the second is
    // empty; here the word is the synthetic sample.
    if (_filled.text.isEmpty) {
      _filled.text = AppLocalizations.of(context).sampleWord;
    }
  }

  @override
  void dispose() {
    _filled.dispose();
    _empty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // ModeChips in index.jsx, in its order; topic search is deferred (PRD
    // §13), so it has no chip.
    final modes = [
      l10n.searchModeWord,
      l10n.searchModeRoot,
      l10n.searchModeBare,
      l10n.searchModeDerived,
      l10n.searchModeTafsir,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space6,
      children: [
        GallerySection(
          title: l10n.gallerySectionWordSheet,
          child: WordSheet(
            word: GallerySamples.word(l10n),
            wordNumber: _wordNumber,
            wordCount: _wordCount,
            tabs: WordSheetTab.values.toSet(),
            selectedTab: _tab,
            onTabSelected: (tab) => setState(() => _tab = tab),
            rows: [
              for (var i = 0; i < _sampleRows; i++)
                WordSheetRow(l10n.sampleRowLabel, l10n.sampleRowValue),
            ],
            note: l10n.sampleNote,
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionSearchField,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space4,
            children: [
              SearchField(controller: _filled, onChanged: _ignore),
              SearchField(controller: _empty, onChanged: _ignore),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionModeChips,
          child: ModeChips(
            options: modes,
            selectedIndex: _mode,
            onChanged: (index) => setState(() => _mode = index),
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionSearchSummary,
          child: SearchSummary(
            title: l10n.sampleSearchTitle,
            count: l10n.sampleSearchCount,
            sortLabel: l10n.searchSortMushafOrder,
            onSort: _none,
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionSearchResult,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _resultGap,
            children: [
              for (final result in _results)
                SearchResult(
                  surahName: GallerySamples.surahName(l10n),
                  ayahNumber: result.ayah,
                  ayahText: result.clamp
                      ? GallerySamples.longText(l10n)
                      : GallerySamples.text(l10n),
                  clamp: result.clamp,
                  onContext: _none,
                  onOpen: _none,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

void _none() {}

void _ignore(String _) {}
