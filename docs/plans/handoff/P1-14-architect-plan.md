# P1-14 plan (flutter-architect, 2026-10-28, from origin/main), approved by the lead

Scope: RD-01, RD-02, RD-05, RD-06, RD-09 (state only), RD-10, RD-11 (downward), RD-12, RD-15 (the sign in text), RD-17 (basic facts), NV-06, §9.5.

Left out on purpose:
- Margin marks (RD-02's margin marks, RD-15's «سجدة» word): SurahSliver never draws MarginMarkView and _BlockHost is private; needs an engine change in lib/ui/core/reader/ that P1-22 owns, and a placement decision for the owner (mark ~90 px vs 28 px inset).
- Previous surah on scrolling up (needs `center` and reverse-growth offset maths).
- Integrity alert component: P1-25 is now merged (#52) and its strings exist (`integrityBaseTitle`/`Body`). Showing the alert is optional here; if the component fits with no new strings, use it on the unavailable state; otherwise show nothing and report.

Last position: ReadingPositionRepository and LocalReadingPositionRepository exist (P1-04) but nothing provides them; `reading_providers.dart` is empty. Commit 6: in `readingProviders`, load LocalReadingPositionRepository over ReadingPositionDao(read<UserDatabase>()) and provideListenable it; if the load fails provide nothing. D-133's condition: if settings fell back to InMemoryAppSettingsRepository, the user DB must be UserDatabase.inMemory() — check how user_database_providers.dart does it today and follow it. The view model reads the repository as optional (as Home does).

View model (`MushafViewModel extends ChangeNotifier`):
- ctor takes QuranTextRepository?, QuranIndexRepository?, ReadingPositionRepository?, PackIntegrityRepository?, QuranAddress? address.
- State: ReaderStatus {loading, ready, unavailable}; List<ReaderSurah> surahs (each {SurahInfo info, SurahText text}); QuranAddress? anchor; QuranPosition? position; PackText? positionSurahName; bool distractionFree.
- `open` (Command0): route address (a word address opens its ayah) if in the edition, else positions.last, else 1:1. Build SurahText from ayahText/words/marks/basmala, pageStartsIn and marginMarksIn over editionMap().
- `loadNext` appends index.nextSurah.
- `showFirstVisible(QuranAddress)` updates position through index.positionOf.
- `saveFirstVisible()` on scroll end after a user scroll only. `leave()` saves only if the user moved, so a reader only opened never overwrites the position.
- Listens to integrity; if index.surahs is empty or any read fails, clear surahs and set unavailable.

Screen (`lib/ui/features/mushaf/views/mushaf_screen.dart`, keep the name MushafScreen; router tests and ARCHITECTURE use it):
- SafeArea › Column › PositionBar › Expanded(MushafScrollView) › ReaderPageNumber.
- MushafScrollView: one CustomScrollView; per surah SliverToBoxAdapter(SurahHeader) then SurahSliver(key: GlobalKey) lazily per block.
- NotificationListener<ScrollNotification>: on update find the first surah sliver with paint extent and call layout.ayahAt(pixels − getOffsetToReveal(sliver, 0).offset); preload when extentAfter < 2 × viewport (named constant); on a user scroll end, save.
- onLayout jumps to anchor at first, and on any new plan (rotation, text scale) back to the current first-visible ayah (landscape and 200% keep their place).
- Leaving: ModalRoute.isCurrentOf false, TickerMode.of false (tab switch), app hidden/paused (AppLifecycleListener), dispose. A reader not the current route neither loads nor saves; when current again it reopens at positions.last (/mushaf/read/x stacks over /mushaf).
- Distraction-free: ShellChrome.tabBarVisible = !distractionFree; hide position bar, page number and info line; header, basmala and text stay; leaving restores the tab bar. (The toggling gesture is P1-23's.)
- SurahHeader gains `VoidCallback? onInfoPressed`; when given the whole header becomes a Pressable: hit area ≥ 48 with no visual change, focus ring on the 14 radius, merged semantics, hint surahIntroTitle.
- PositionBar({PackText surahName, int juz, int hizb}) from the Mushaf board: SurahName in Kufi 20/600 primary, juzHizbLine 13 ink-muted, spread to both ends. Page number in the footer (15/600 accent, pageLabel semantics), as both boards draw it.
- SurahInfoSheet: surahIntroTitle title and SurahHeader(size: lg, info:); the sheet frame copied from .qk-sheet (fifth copy, D-135).

Routes: mushafRoutes: tabRoot → MushafScreen(address: null); tabChildren[mushaf] → RoutePaths.mushafRead with Routes.addressOf(state); sheets → RoutePaths.surahInfoSheet, owner Routes.mushaf. D-063 canonical form (/mushaf/read/hafs:2:255, /sheet/surah-info/2). Malformed redirects home already; well-formed but outside the edition falls back to the last position.

Files:
- lib/ui/features/mushaf/view_models/mushaf_view_model.dart, reader_surah.dart, surah_info_view_model.dart
- lib/ui/features/mushaf/views/mushaf_screen.dart, mushaf_scroll_view.dart, reader_page_number.dart, surah_info_sheet.dart, surah_info_text.dart (`String? surahInfoText(AppLocalizations, SurahInfo)`, null when revelationPlace is null → line hidden)
- lib/ui/core/widgets/position_bar.dart; lib/ui/core/widgets/surah_header.dart (+onInfoPressed)
- lib/ui/core/metrics/reader_screen_metrics.dart (bar 28/24/0, column top 18, footer bottom 10, bar type sizes, sheet frame), each value citing its board
- lib/routing/routes/mushaf_routes.dart
- lib/config/providers/reading_providers.dart (commit 6)
- tests under test/ui/features/mushaf/, test/integrity/reader_text_integrity_test.dart, test/routing/mushaf_routes_test.dart, position_bar_test.dart, surah_header_test.dart, test/ui/core/widgets/position_bar_golden_test.dart

Data: read only the base pack by address; write only the one reading_position row (address only).

Tests (over readerSurahs and ReaderFixture in test/ui/core/reader/reader_fixture.dart):
- every ayah's semantics label equals the pack bytes from pack.raw;
- open at address and with a word address; position bar follows scroll;
- save on scroll end and each leaving case; an unmoved reader never saves (FakeReadingPositionRepository.saved);
- continue into next surah; surah 9 without basmala;
- 200% and the 2.0 step at 320×640 and 640×320: no exception, nothing clipped;
- offline from first run: provideQuran over a bundled synthetic pack, fresh support folder, no network providers, HttpOverrides throwing;
- failed pack: SyntheticFault and a mid-session IntegrityFailed: no QuranText and no ayah semantics either way;
- goldens in four themes tagged golden (generated by CI, not locally).
Pending human checks: 60 fps scroll on device, screen reader, identity reviewer.

Strings: all exist (juzHizbLine, pageLabel, surahInfoLine, revelationMakki/Madani, ayahCount, surahIntroTitle, surahTitle). Add none.

Commits:
1. feat(ds): position bar and tappable surah-header info line (RD-05, RD-17)
2. feat(reader): surah-mode reader with position bar and info line (RD-02)
3. feat(reader): surah-info sheet (RD-17)
4. feat(reader): save and restore the reading position (RD-12)
5. test(reader): byte-exact text, 200%, landscape, offline, failed pack, goldens (RD-01)
6. feat(config): provide the reading position (RD-12)
