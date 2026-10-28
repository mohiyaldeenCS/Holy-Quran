import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/l10n/ayah_count.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/context_sheet.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
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
// A synthetic pack version for the source badge.
const int _badgeVersion = 1;
// ContextSheet/preview.html: «البقرة · ١٥٣», surah 2 of the Hafs text; the
// ayat 152 to 154, the middle one asked for;
// `defaultValue: 0`, the first amount.
const String _contextRiwaya = 'hafs';
const int _contextSurah = 2;
const int _contextFirst = 152;
const int _contextCount = 3;
const int _contextSelected = 153;
const int _contextAmount = 0;
// ContextSheet in index.jsx: `options`, with 3 ayat and 5 ayat.
const List<int> _contextAyat = [3, 5];

/// The gallery's study and search section: `WordSheet`, `SearchField`,
/// `ModeChips`, `SearchSummary` and `SearchResult`, as their previews show
/// them, then tafsir text under its source badge, on synthetic text.
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
  int _contextChoice = _contextAmount;
  // The results whose long ayah is shown whole: the cards keep no state of
  // their own, so this is the caller's, as a list's is.
  final Set<int> _whole = {};
  ContextPassage? _passage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SearchField/preview.html: the first field holds a word, the second is
    // empty; here the word is the synthetic sample.
    if (_filled.text.isEmpty) {
      _filled.text = AppLocalizations.of(context).sampleWord;
    }
    // One passage for good: the sheet plans its text again when it is a new
    // one. The ayat are the synthetic sample, with no word spans.
    _passage ??= ContextPassage(
      riwaya: _contextRiwaya,
      surah: _contextSurah,
      firstAyah: _contextFirst,
      ayat: [
        for (var k = 0; k < _contextCount; k++)
          AyahText(
            text: GallerySamples.text(AppLocalizations.of(context)),
            words: const [],
          ),
      ],
      selectedAyah: _contextSelected,
    );
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
              for (final controller in [_filled, _empty])
                SearchField(
                  controller: controller,
                  onChanged: _ignore,
                  onSubmitted: _ignore,
                ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionModeChips,
          child: ModeChips(
            label: l10n.searchModesLabel,
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
                  expanded: _whole.contains(result.ayah),
                  onExpand: () => setState(() => _whole.add(result.ayah)),
                  onContext: _none,
                  onOpen: _none,
                ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.tafsirReaderTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TafsirText(GallerySamples.longText(l10n)),
              SourceBadge(
                name: GallerySamples.text(l10n),
                version: _badgeVersion,
                onPressed: _none,
              ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.searchResultContext,
          child: ContextSheet(
            surahName: GallerySamples.surahName(l10n),
            ayahNumber: _contextSelected,
            amounts: [
              l10n.contextOneAyah,
              for (final count in _contextAyat) ayahCount(l10n, count),
              l10n.contextSurah,
            ],
            amount: _contextChoice,
            onAmountSelected: (index) => setState(() => _contextChoice = index),
            passage: _passage,
            onOpen: _none,
            onPlay: _none,
          ),
        ),
      ],
    );
  }
}

void _none() {}

void _ignore(String _) {}
