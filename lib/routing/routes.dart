import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';

/// The five tabs of the shell, in the tab bar's order.
enum ShellTab {
  home(Routes.home),
  mushaf(Routes.mushaf),
  listen(Routes.listen),
  study(Routes.study),
  more(Routes.more);

  const ShellTab(this.path);

  /// The location of the tab's first screen.
  final String path;
}

/// Every Phase 1 location (D-102), as a constant or a builder whose result is
/// given to `go`, or to `push` for a sheet. Addresses are written in the
/// canonical form of D-063, so a location never holds Arabic-Indic digits.
abstract final class Routes {
  static const home = '/home';
  static const mushaf = '/mushaf';
  static const mushafIndex = '$mushaf/${RoutePaths.mushafIndex}';
  static const listen = '/listen';
  static const recitations = '$listen/${RoutePaths.recitations}';
  static const study = '/study';
  static const search = '$study/${RoutePaths.search}';
  static const more = '/more';
  static const bookmarks = '$more/${RoutePaths.bookmarks}';
  static const resources = '$more/${RoutePaths.resources}';
  static const settings = '$more/${RoutePaths.settings}';
  static const sources = '$more/${RoutePaths.sources}';
  static const onboarding = '/onboarding';
  static const gallery = '/gallery';

  static const goToSheet = RoutePaths.goToSheet;
  static const rangeSheet = RoutePaths.rangeSheet;
  static const repeatSheet = RoutePaths.repeatSheet;
  static const silenceSheet = RoutePaths.silenceSheet;
  static const stopAfterSheet = RoutePaths.stopAfterSheet;
  static const sleepSheet = RoutePaths.sleepSheet;
  static const queueSheet = RoutePaths.queueSheet;
  static const firstUseTafsirSheet = RoutePaths.firstUseTafsirSheet;

  static const addressParameter = 'address';
  static const surahParameter = 'surah';
  static const packQuery = 'pack';

  /// The reader at [address].
  static String mushafRead(QuranAddress address) => '$mushaf/read/$address';

  static String studyTafsir(QuranAddress address) => '$study/tafsir/$address';

  static String contextSheet(QuranAddress address) =>
      '$_sheet/context/$address';

  static String wordSheet(QuranAddress address) => '$_sheet/word/$address';

  static String ayahSheet(QuranAddress address) => '$_sheet/ayah/$address';

  static String surahInfoSheet(int surah) =>
      '$_sheet/surah-info/${_checkedSurah(surah)}';

  static String tafsirSheet(QuranAddress address) => '$_sheet/tafsir/$address';

  static String copySheet(QuranAddress address) => '$_sheet/copy/$address';

  static String shareSheet(QuranAddress address) => '$_sheet/share/$address';

  static String noteSheet(QuranAddress address) => '$_sheet/note/$address';

  static String playOptionsSheet(QuranAddress address) =>
      '$_sheet/play-options/$address';

  /// The «أبلغ عن خطأ» sheet (O-17) for [address], and for an entry of the
  /// pack [pack] when the report is about one.
  static String reportSheet(QuranAddress address, {String? pack}) => Uri(
    path: '$_sheet/report/$address',
    queryParameters: pack == null ? null : {packQuery: pack},
  ).toString();

  /// The address in [state]'s location, or null when it has none or it is
  /// not canonical.
  static QuranAddress? addressOf(GoRouterState state) =>
      switch (state.pathParameters[addressParameter]) {
        final source? => QuranAddress.tryParse(source),
        null => null,
      };

  /// The surah number in [state]'s location, or null when it has none or it
  /// is not a positive number in ASCII digits with no leading zero.
  static int? surahOf(GoRouterState state) =>
      switch (state.pathParameters[surahParameter]) {
        final source? when _surah.hasMatch(source) => int.parse(source),
        _ => null,
      };

  static String? packOf(GoRouterState state) =>
      state.uri.queryParameters[packQuery];

  static const _sheet = '/sheet';
  // At most nine digits, so that the number fits an int on every platform.
  static final _surah = RegExp(r'^[1-9][0-9]{0,8}$');

  static int _checkedSurah(int surah) => surah >= 1
      ? surah
      : throw ArgumentError.value(surah, 'surah', 'must be positive');
}

/// The `path` of each route: relative to its tab's root for a screen in a
/// tab, absolute for a sheet.
abstract final class RoutePaths {
  static const mushafRead = 'read/:${Routes.addressParameter}';
  static const mushafIndex = 'index';
  static const recitations = 'recitations';
  static const search = 'search';
  static const studyTafsir = 'tafsir/:${Routes.addressParameter}';
  static const bookmarks = 'bookmarks';
  static const resources = 'resources';
  static const settings = 'settings';
  static const sources = 'sources';

  static const _address = ':${Routes.addressParameter}';
  static const goToSheet = '${Routes._sheet}/goto';
  static const contextSheet = '${Routes._sheet}/context/$_address';
  static const wordSheet = '${Routes._sheet}/word/$_address';
  static const ayahSheet = '${Routes._sheet}/ayah/$_address';
  static const surahInfoSheet =
      '${Routes._sheet}/surah-info/:${Routes.surahParameter}';
  static const tafsirSheet = '${Routes._sheet}/tafsir/$_address';
  static const copySheet = '${Routes._sheet}/copy/$_address';
  static const shareSheet = '${Routes._sheet}/share/$_address';
  static const noteSheet = '${Routes._sheet}/note/$_address';
  static const playOptionsSheet = '${Routes._sheet}/play-options/$_address';
  static const rangeSheet = '${Routes._sheet}/range';
  static const repeatSheet = '${Routes._sheet}/repeat';
  static const silenceSheet = '${Routes._sheet}/silence';
  static const stopAfterSheet = '${Routes._sheet}/stop-after';
  static const sleepSheet = '${Routes._sheet}/sleep';
  static const queueSheet = '${Routes._sheet}/queue';
  static const firstUseTafsirSheet = '${Routes._sheet}/first-use-tafsir';
  static const reportSheet = '${Routes._sheet}/report/$_address';
}
