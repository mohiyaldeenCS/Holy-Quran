import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// The application's name, shown as the window and task-switcher title.
  ///
  /// In ar, this message translates to:
  /// **'القرآن الكريم'**
  String get appTitle;

  /// Label of the main navigation tab for the home screen.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// Label of the main navigation tab for the Mushaf reader.
  ///
  /// In ar, this message translates to:
  /// **'المصحف'**
  String get tabMushaf;

  /// Label of the main navigation tab for listening to recitations.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع'**
  String get tabListen;

  /// Label of the main navigation tab for study: tafsir, search and the ayah sheet.
  ///
  /// In ar, this message translates to:
  /// **'الدراسة'**
  String get tabStudy;

  /// Label of the main navigation tab for bookmarks, notes, resources and settings.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get tabMore;

  /// Accessible name of the main tab bar, read by screen readers.
  ///
  /// In ar, this message translates to:
  /// **'التنقل الرئيسي'**
  String get mainNavigationLabel;

  /// A count of ayat, such as a surah's length. count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{آية واحدة} =2{آيتان} few{{digits} آيات} other{{digits} آية}}'**
  String ayahCount(int count, String digits);

  /// Accessible name of an ayah-end marker, read by screen readers (AX-01). number is the ayah number, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'الآية {number}'**
  String ayahMarkerLabel(String number);

  /// A surah's name after the word for surah, as the identity's SurahHeader writes it. name is the pack's surah name, substituted whole and unchanged (D-084).
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String surahTitle(String name);

  /// A surah's name with an ayah number, as the identity's search results and MiniPlayer write it. name is the pack's surah name, substituted whole and unchanged (D-084); ayah is the ayah number, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{name} · الآية {ayah}'**
  String surahAyahReference(String name, String ayah);

  /// A surah's name after the word for surah, with an ayah number. name is the pack's surah name, substituted whole and unchanged (D-084); ayah is the ayah number, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'سورة {name} · الآية {ayah}'**
  String surahTitleAyahReference(String name, String ayah);

  /// Spoken name of AyahRow's play button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل من هنا'**
  String get ayahRowPlayFromHere;

  /// Spoken name of AyahRow's bookmark button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'علامة مرجعية'**
  String get ayahRowBookmark;

  /// Spoken name of AyahRow's study button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'مركز الدراسة'**
  String get ayahRowStudy;

  /// A Makki surah, in the SurahListItem meta line, as the identity writes it.
  ///
  /// In ar, this message translates to:
  /// **'مكية'**
  String get revelationMakki;

  /// A Madani surah, in the SurahListItem meta line, as the identity writes it.
  ///
  /// In ar, this message translates to:
  /// **'مدنية'**
  String get revelationMadani;

  /// SurahListItem's meta line, as the identity's reference writes it. revelation is revelationMakki or revelationMadani; count is the ayah count from ayahCount.
  ///
  /// In ar, this message translates to:
  /// **'{revelation} · {count}'**
  String surahListMeta(String revelation, String count);

  /// The middle dot between data items on one line, as the identity's rule writes it (docs/DESIGN_SYSTEM.md, Ground rules, 6: «middle dot « · » between data items»; design/design-system/README.md, line 25: «الفاصل بين البيانات نقطة وسطى « · »»). Used where the items are not a fixed phrase, such as a reported pack's id, version and source.
  ///
  /// In ar, this message translates to:
  /// **' · '**
  String get dataSeparator;

  /// The badge on the last-read surah in SurahListItem, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'آخر قراءة'**
  String get surahListLastRead;

  /// The word above a surah's start page in SurahListItem, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get surahListPage;

  /// A percentage, as ResourceRow shows download progress. digits is the number, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{digits}٪'**
  String percentValue(String digits);

  /// A count of times, such as repetitions, as the identity's timesCount writes it. count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} =2{مرتان} few{{digits} مرات} other{{digits} مرة}}'**
  String timesCount(int count, String digits);

  /// Spoken name of MiniPlayer's repeat button with no repetition set, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'تكرار'**
  String get playerRepeat;

  /// Spoken name of MiniPlayer's repeat button with a repetition count (D-087). Its own plural message rather than «تكرار» followed by timesCount: the noun after «تكرار» is genitive («مرتين», not timesCount's «مرتان»). count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تكرار مرة واحدة} =2{تكرار مرتين} few{تكرار {digits} مرات} other{تكرار {digits} مرة}}'**
  String playerRepeatTimes(int count, String digits);

  /// Spoken name of the player's previous-ayah button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'الآية السابقة'**
  String get playerPreviousAyah;

  /// Spoken name of the player's main button while it plays, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get playerPause;

  /// Spoken name of the player's main button while it is paused, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get playerPlay;

  /// Spoken name of the player's next-ayah button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'الآية التالية'**
  String get playerNextAyah;

  /// Spoken name of the player's sleep-timer button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'مؤقت النوم'**
  String get playerSleepTimer;

  /// Spoken name of the player's progress bar, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'موضع التلاوة'**
  String get playerPosition;

  /// The playback speed on the player's chip, such as ١٫٢٥×: the whole part, the Arabic decimal separator, the fraction and the multiplication sign. Both parts are Arabic-Indic digits. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'{whole}٫{fraction}×'**
  String playerSpeedValue(String whole, String fraction);

  /// The small label at the top of ContinueCard, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'أكمل القراءة'**
  String get continueReadingLabel;

  /// ContinueCard's button, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'تابع القراءة'**
  String get continueReadingAction;

  /// Spoken name of ContinueCard's progress bar, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'الموضع في المصحف'**
  String get continueReadingPosition;

  /// ResourceRow's status line for a downloaded resource, as the identity's reference writes it. size is the resource's size.
  ///
  /// In ar, this message translates to:
  /// **'تم التنزيل · {size}'**
  String resourceDownloadedMeta(String size);

  /// ResourceRow's status for a downloaded resource whose size is not known.
  ///
  /// In ar, this message translates to:
  /// **'تم التنزيل'**
  String get resourceDownloaded;

  /// ResourceRow's status line for a resource that can be downloaded, as the identity's reference writes it. size is the resource's size.
  ///
  /// In ar, this message translates to:
  /// **'متاحة · {size}'**
  String resourceAvailableMeta(String size);

  /// ResourceRow's status for a resource that can be downloaded and whose size is not known.
  ///
  /// In ar, this message translates to:
  /// **'متاحة'**
  String get resourceAvailable;

  /// A resource's size in megabytes, as the resource manager's status line writes it after the state. The unit is the PRD's own (docs/prd/PRD.ar.md §10.7, the catalogue table: «م.ب»). digits is the number, already written in Arabic-Indic digits with its decimal mark.
  ///
  /// In ar, this message translates to:
  /// **'{digits} م.ب'**
  String resourceSizeMegabytes(String digits);

  /// ResourceRow's button for a downloaded resource, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get resourceDelete;

  /// ResourceRow's button for an available resource, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل'**
  String get resourceDownload;

  /// Spoken name of ResourceRow's progress bar while a resource downloads, as the identity's reference labels it. title is the resource's title.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل {title}'**
  String resourceDownloading(String title);

  /// WordSheet's text tab, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'النص'**
  String get wordSheetTabText;

  /// WordSheet's tafsir tab, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'التفسير'**
  String get wordSheetTabTafsir;

  /// WordSheet's i'rab tab, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'الإعراب'**
  String get wordSheetTabIrab;

  /// WordSheet's morphology tab, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'الصرف'**
  String get wordSheetTabSarf;

  /// WordSheet's tajweed tab, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'التجويد'**
  String get wordSheetTabTajweed;

  /// The word's position in its ayah in WordSheet, as the identity's preview writes it. n is the word's number and m the ayah's word count, both already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'الكلمة {n} من {m}'**
  String wordSheetPosition(String n, String m);

  /// The memorisation category of Tag, as the identity's preview names it.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get tagMemorise;

  /// The review category of Tag, as the identity's preview names it.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة'**
  String get tagReview;

  /// The study category of Tag, as the identity's preview names it.
  ///
  /// In ar, this message translates to:
  /// **'دراسة'**
  String get tagStudy;

  /// The important-ayat category of Tag, as the identity's preview names it.
  ///
  /// In ar, this message translates to:
  /// **'آيات مهمة'**
  String get tagImportant;

  /// Spoken name of Stepper's minus button, as the identity's reference labels it. label is the setting's name.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص {label}'**
  String stepperDecrease(String label);

  /// Spoken name of Stepper's plus button, as the identity's reference labels it. label is the setting's name.
  ///
  /// In ar, this message translates to:
  /// **'زيادة {label}'**
  String stepperIncrease(String label);

  /// Stepper's value followed by its unit, as the identity's reference writes it. value is the number, already written in Arabic-Indic digits; unit is the unit's word.
  ///
  /// In ar, this message translates to:
  /// **'{value} {unit}'**
  String stepperValueWithUnit(String value, String unit);

  /// SearchField's placeholder and spoken name, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في القرآن'**
  String get searchFieldHint;

  /// Spoken name of the button that clears the search field while it holds text (D-089, 5).
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get searchFieldClear;

  /// Spoken name of the ModeChips group, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'نوع البحث'**
  String get searchModesLabel;

  /// The word search mode in ModeChips, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'كلمة'**
  String get searchModeWord;

  /// The root search mode in ModeChips, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'الجذر'**
  String get searchModeRoot;

  /// The search mode without diacritics in ModeChips, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'بلا تشكيل'**
  String get searchModeBare;

  /// The derived-forms search mode in ModeChips, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'المشتقات'**
  String get searchModeDerived;

  /// The search mode inside tafsir in ModeChips, as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'في التفاسير'**
  String get searchModeTafsir;

  /// SearchSummary's sort control in mushaf order, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب المصحف'**
  String get searchSortMushafOrder;

  /// Spoken name of SearchResult's context button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'سياق الآية'**
  String get searchResultContext;

  /// Spoken name of SearchResult's open-in-the-mushaf button, as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'افتح في المصحف'**
  String get searchResultOpen;

  /// The link under a clamped SearchResult, as the identity's reference writes it.
  ///
  /// In ar, this message translates to:
  /// **'الآية طويلة · اعرضها كاملة'**
  String get searchResultShowWhole;

  /// Spoken name of the search button in the home header, as the Screens board labels it.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get homeSearch;

  /// The index door on the home screen, as the Screens board names it.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get homeDoorIndex;

  /// The bookmarks door on the home screen, as the Screens board names it.
  ///
  /// In ar, this message translates to:
  /// **'العلامات'**
  String get homeDoorBookmarks;

  /// The small label of the home screen's continue-listening row, as the Screens board writes it.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الاستماع'**
  String get continueListeningLabel;

  /// Debug gallery: title of the AyahRow section, for the identity's AyahRow preview.
  ///
  /// In ar, this message translates to:
  /// **'صف الآية'**
  String get gallerySectionAyahRow;

  /// Debug gallery: title of the SurahListItem section, for the identity's SurahListItem preview.
  ///
  /// In ar, this message translates to:
  /// **'صف الفهرس'**
  String get gallerySectionSurahListItem;

  /// Debug gallery: title of the Tag section, for the identity's Tag preview.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم'**
  String get gallerySectionTag;

  /// Debug gallery: title of the Stepper section, for the identity's Stepper preview.
  ///
  /// In ar, this message translates to:
  /// **'مُعدّل الرقم'**
  String get gallerySectionStepper;

  /// Debug gallery: title of the ProgressBar section, for the identity's ProgressBar preview.
  ///
  /// In ar, this message translates to:
  /// **'شريط التقدّم'**
  String get gallerySectionProgressBar;

  /// Debug gallery: title of the MiniPlayer section, for the identity's MiniPlayer preview.
  ///
  /// In ar, this message translates to:
  /// **'المشغّل'**
  String get gallerySectionMiniPlayer;

  /// Debug gallery: title of the ContinueCard section, for the identity's ContinueCard preview.
  ///
  /// In ar, this message translates to:
  /// **'أكمل القراءة'**
  String get gallerySectionContinueCard;

  /// Debug gallery: title of the ResourceRow section, for the identity's ResourceRow preview.
  ///
  /// In ar, this message translates to:
  /// **'مدير التنزيلات'**
  String get gallerySectionResourceRow;

  /// Debug gallery: title of the ReaderPlayerBar section, for the reader's floating player bar of the Screens board.
  ///
  /// In ar, this message translates to:
  /// **'شريط المشغّل في القارئ'**
  String get gallerySectionReaderPlayerBar;

  /// Debug gallery: title of the WordSheet section, for the identity's WordSheet preview.
  ///
  /// In ar, this message translates to:
  /// **'ورقة الكلمة'**
  String get gallerySectionWordSheet;

  /// Debug gallery: title of the SearchField section, for the identity's SearchField preview.
  ///
  /// In ar, this message translates to:
  /// **'حقل البحث'**
  String get gallerySectionSearchField;

  /// Debug gallery: title of the ModeChips section, for the identity's ModeChips preview.
  ///
  /// In ar, this message translates to:
  /// **'أنواع البحث'**
  String get gallerySectionModeChips;

  /// Debug gallery: title of the SearchSummary section, for the identity's SearchSummary preview.
  ///
  /// In ar, this message translates to:
  /// **'ملخص النتائج'**
  String get gallerySectionSearchSummary;

  /// Debug gallery: title of the SearchResult section, for the identity's SearchResult preview.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة البحث'**
  String get gallerySectionSearchResult;

  /// Debug gallery: title of the HomeHeader section, for the home header of the Screens board.
  ///
  /// In ar, this message translates to:
  /// **'رأس الرئيسية'**
  String get gallerySectionHomeHeader;

  /// Debug gallery: title of the HomeDoor section, for the home doors of the Screens board.
  ///
  /// In ar, this message translates to:
  /// **'أبواب الرئيسية'**
  String get gallerySectionHomeDoor;

  /// Debug gallery: title of the ContinueListeningRow section, for the continue-listening row of the Screens board.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الاستماع'**
  String get gallerySectionContinueListeningRow;

  /// Debug gallery: title of the ShareCard section, for the share cards, as the Share board titles them.
  ///
  /// In ar, this message translates to:
  /// **'بطاقات مشاركة الآية'**
  String get gallerySectionShareCard;

  /// Debug gallery: title of the Splash section, for the splash, as the Share board titles it.
  ///
  /// In ar, this message translates to:
  /// **'شاشة البداية'**
  String get gallerySectionSplash;

  /// Title of the debug-only gallery of the design-system widgets, and the label of the debug button on the More tab that opens it.
  ///
  /// In ar, this message translates to:
  /// **'معرض المكوّنات'**
  String get galleryTitle;

  /// Name of the paper reading theme, as the identity names it (docs/DESIGN_SYSTEM.md, Themes).
  ///
  /// In ar, this message translates to:
  /// **'ورق'**
  String get themePaper;

  /// Name of the night reading theme, as the identity names it (docs/DESIGN_SYSTEM.md, Themes).
  ///
  /// In ar, this message translates to:
  /// **'ليل'**
  String get themeNight;

  /// Name of the sepia reading theme, as the identity names it (docs/DESIGN_SYSTEM.md, Themes).
  ///
  /// In ar, this message translates to:
  /// **'سيبيا'**
  String get themeSepia;

  /// Name of the contrast reading theme, as the identity names it (docs/DESIGN_SYSTEM.md, Themes).
  ///
  /// In ar, this message translates to:
  /// **'تباين عالٍ'**
  String get themeContrast;

  /// Accessible name of the interface-level switch (LevelSwitch), as the identity's reference labels it.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الواجهة'**
  String get levelLabel;

  /// The simple option of the interface-level switch (LevelSwitch), as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'بسيط'**
  String get levelSimple;

  /// The medium option of the interface-level switch (LevelSwitch), as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get levelMedium;

  /// The study option of the interface-level switch (LevelSwitch), as the identity's reference names it.
  ///
  /// In ar, this message translates to:
  /// **'دراسة'**
  String get levelStudy;

  /// Debug gallery: title of the Mark section, as the identity's Mark preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'الرمز'**
  String get gallerySectionMark;

  /// Debug gallery: title of the Lockup section, as the identity's Lockup preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'الشعار الكامل'**
  String get gallerySectionLockup;

  /// Debug gallery: title of the Icon section, as the identity's Icon preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'الأيقونات'**
  String get gallerySectionIcons;

  /// Debug gallery: title of the Button section, as the identity's Button preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'الأزرار'**
  String get gallerySectionButtons;

  /// Debug gallery: title of the IconButton section, as the identity's IconButton preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'أزرار الأيقونات'**
  String get gallerySectionIconButtons;

  /// Debug gallery: title of the Switch section, as the identity's Switch preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'المفاتيح'**
  String get gallerySectionSwitches;

  /// Debug gallery: title of the LevelSwitch section, as the identity's LevelSwitch preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'مستوى الواجهة'**
  String get gallerySectionLevelSwitch;

  /// Debug gallery: title of the TabBar section, as the identity's TabBar preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'شريط التنقل'**
  String get gallerySectionTabBar;

  /// Debug gallery: title of the QuranText section, as the identity's QuranText preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'النص القرآني'**
  String get gallerySectionQuranText;

  /// Debug gallery: title of the AyahMarker section, as the identity's AyahMarker preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'فاصلة الآية'**
  String get gallerySectionAyahMarker;

  /// Debug gallery: title of the SurahHeader section, as the identity's SurahHeader preview is titled.
  ///
  /// In ar, this message translates to:
  /// **'رأس السورة'**
  String get gallerySectionSurahHeader;

  /// Debug gallery: label of the primary Button sample, as in the identity's Button preview.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التلاوة'**
  String get galleryButtonPrimary;

  /// Debug gallery: label of the outline Button sample, as in the identity's Button preview.
  ///
  /// In ar, this message translates to:
  /// **'علامة مرجعية'**
  String get galleryButtonOutline;

  /// Debug gallery: label of the tonal Button sample, as in the identity's Button preview.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى مجموعة'**
  String get galleryButtonTonal;

  /// Debug gallery: label of the text Button sample, as in the identity's Button preview.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get galleryButtonText;

  /// Debug gallery: label of the disabled Button sample, as in the identity's Button preview.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get galleryButtonDisabled;

  /// Debug gallery: spoken name of the plain play IconButton sample, as in the identity's IconButton preview.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل من هنا'**
  String get galleryIconButtonPlayFromHere;

  /// Debug gallery: spoken name of the plain bookmark IconButton sample, as in the identity's IconButton preview.
  ///
  /// In ar, this message translates to:
  /// **'علامة مرجعية'**
  String get galleryIconButtonBookmark;

  /// Debug gallery: spoken name of the plain study IconButton sample, as in the identity's IconButton preview.
  ///
  /// In ar, this message translates to:
  /// **'مركز الدراسة'**
  String get galleryIconButtonStudy;

  /// Debug gallery: spoken name of the tint search IconButton sample, as in the identity's IconButton preview.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get galleryIconButtonSearch;

  /// Debug gallery: spoken name of the solid play IconButton sample, as in the identity's IconButton preview.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get galleryIconButtonPlay;

  /// Debug gallery: label of the first Switch sample, as in the identity's Switch preview.
  ///
  /// In ar, this message translates to:
  /// **'ألوان التجويد'**
  String get gallerySwitchTajweed;

  /// Debug gallery: label of the second Switch sample, as in the identity's Switch preview.
  ///
  /// In ar, this message translates to:
  /// **'منع إطفاء الشاشة أثناء التلاوة'**
  String get gallerySwitchKeepAwake;

  /// Debug gallery: a synthetic sample shown in QuranText to display its sizes. It is not Quran text and must never be replaced by Quran text.
  ///
  /// In ar, this message translates to:
  /// **'نص تجريبي للاختبار وليس آية'**
  String get sampleText;

  /// Debug gallery: a synthetic stand-in for a surah name in the SurahHeader sample. Not a real surah name.
  ///
  /// In ar, this message translates to:
  /// **'اسم تجريبي'**
  String get sampleSurahName;

  /// Debug gallery: a synthetic stand-in for the information line under the SurahHeader sample. Not real surah facts.
  ///
  /// In ar, this message translates to:
  /// **'سطر تجريبي'**
  String get sampleInfo;

  /// Debug gallery: label of the first Stepper sample, as in the identity's Stepper preview.
  ///
  /// In ar, this message translates to:
  /// **'تكرار كل آية'**
  String get galleryStepperRepeat;

  /// Debug gallery: label of the second Stepper sample, as in the identity's Stepper preview.
  ///
  /// In ar, this message translates to:
  /// **'تكرار الدمج'**
  String get galleryStepperMerge;

  /// Debug gallery: label of the third Stepper sample, as in the identity's Stepper preview.
  ///
  /// In ar, this message translates to:
  /// **'الصمت بعد كل تكرار'**
  String get galleryStepperSilence;

  /// Debug gallery: the seconds unit of the third Stepper sample, as in the identity's Stepper preview.
  ///
  /// In ar, this message translates to:
  /// **'ث'**
  String get galleryStepperSeconds;

  /// Debug gallery: the playback speed of the MiniPlayer sample, as the identity's reference defaults it.
  ///
  /// In ar, this message translates to:
  /// **'١٫٠×'**
  String get gallerySpeed;

  /// Debug gallery: a synthetic stand-in for a reciter's name. Not a real reciter.
  ///
  /// In ar, this message translates to:
  /// **'قارئ تجريبي'**
  String get sampleReciter;

  /// Debug gallery: a synthetic stand-in for a resource's title. Not a real source.
  ///
  /// In ar, this message translates to:
  /// **'مورد تجريبي'**
  String get sampleResourceTitle;

  /// Debug gallery: a synthetic stand-in for a resource's size.
  ///
  /// In ar, this message translates to:
  /// **'حجم تجريبي'**
  String get sampleSize;

  /// Debug gallery: a synthetic stand-in for one word, shown in QuranText. It is not Quran text and must never be replaced by Quran text.
  ///
  /// In ar, this message translates to:
  /// **'كلمة تجريبية'**
  String get sampleWord;

  /// Debug gallery: a long synthetic sample shown in QuranText to display wrapping. It is not Quran text and must never be replaced by Quran text.
  ///
  /// In ar, this message translates to:
  /// **'نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام في المكوّنات، وهو ليس آية ولا مأخوذًا من أي مصدر'**
  String get sampleLongText;

  /// Debug gallery: a synthetic stand-in for a position line. Not a real position.
  ///
  /// In ar, this message translates to:
  /// **'موضع تجريبي · صفحة تجريبية'**
  String get sampleMeta;

  /// Debug gallery: a synthetic stand-in for SearchSummary's title.
  ///
  /// In ar, this message translates to:
  /// **'بحث تجريبي'**
  String get sampleSearchTitle;

  /// Debug gallery: a synthetic stand-in for SearchSummary's count line.
  ///
  /// In ar, this message translates to:
  /// **'عدد تجريبي من النتائج'**
  String get sampleSearchCount;

  /// Debug gallery: a synthetic stand-in for the label of a WordSheet row.
  ///
  /// In ar, this message translates to:
  /// **'عنوان تجريبي'**
  String get sampleRowLabel;

  /// Debug gallery: a synthetic stand-in for the value of a WordSheet row. Not real linguistic data.
  ///
  /// In ar, this message translates to:
  /// **'قيمة تجريبية'**
  String get sampleRowValue;

  /// Debug gallery: a synthetic stand-in for WordSheet's source note. Not a real source.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة تجريبية عن المصدر'**
  String get sampleNote;

  /// Spoken name of the app-icon tile in HomeHeader, as the Screens board labels it.
  ///
  /// In ar, this message translates to:
  /// **'شعار القرآن الكريم'**
  String get appIconLabel;

  /// Spoken name of the Mark on a share card, as the Share and Logo boards label it.
  ///
  /// In ar, this message translates to:
  /// **'رمز القرآن الكريم'**
  String get markLabel;

  /// The greeting line above the home heading. Source: design/identity-boards/Screens.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'السلام عليكم'**
  String get homeGreeting;

  /// The home heading that leads to the last reading position. Source: design/identity-boards/Screens.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'أكمل من حيث توقفت'**
  String get homeContinueHint;

  /// A reading position: ayah, page and juz, as the continue card on the home screen writes it. ayah is the ayah number; page is the page number; juz is the juz number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah} · صفحة {page} · الجزء {juz}'**
  String readingPositionLine(String ayah, String page, String juz);

  /// The title of the index screen. Same wording as homeDoorIndex, which names the home door. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get indexTitle;

  /// The summary line under the index title. Its noun forms fit the counts the board shows, 114 surahs and 30 juz; do not reuse it for other numbers. surahs is the number of surahs; juz is the number of juz. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'{surahs} سورة · {juz} جزءًا'**
  String indexSummary(String surahs, String juz);

  /// The index tab that lists the surahs. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'السور'**
  String get indexTabSurahs;

  /// The index tab that lists the juz. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الأجزاء'**
  String get indexTabJuz;

  /// The index tab that lists the hizbs. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الأحزاب'**
  String get indexTabHizb;

  /// A juz named by its number, as the page frame writes it. number is the juz number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {number}'**
  String juzLabel(String number);

  /// A hizb named by its number, as it stands after the juz in the page frame line juzHizbLine. number is the hizb number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الحزب {number}'**
  String hizbLabel(String number);

  /// The word for a quarter of a hizb, the first line of the quarter mark in the page margin. The mark's second line, the word for the hizb, has no key yet. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'ربع'**
  String get rubLabel;

  /// A page named by its number, as the listen screen writes it. number is the page number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {number}'**
  String pageLabel(String number);

  /// The position line of the reader: juz and page. juz is the juz number; page is the page number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {juz} · صفحة {page}'**
  String juzPageLine(String juz, String page);

  /// The page frame line: juz and hizb. juz is the juz number; hizb is the hizb number. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {juz} · الحزب {hizb}'**
  String juzHizbLine(String juz, String hizb);

  /// The margin word beside a sajda mark. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'سجدة'**
  String get sajdaLabel;

  /// The information line under a surah header. revelation is revelationMakki or revelationMadani; count is the ayah count from ayahCount; order is the surah's order in the mushaf. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'{revelation} · {count} · ترتيبها {order}'**
  String surahInfoLine(String revelation, String count, String order);

  /// The title the surah information line opens. Source: design/identity-boards/Mushaf.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'مقدمة السورة'**
  String get surahIntroTitle;

  /// The title of the go-to sheet. Source: docs/prd/PRD.ar.md (§7.1 and NV-03).
  ///
  /// In ar, this message translates to:
  /// **'اذهب إلى'**
  String get goToTitle;

  /// Go-to target: a surah. Source: docs/prd/PRD.ar.md (NV-03).
  ///
  /// In ar, this message translates to:
  /// **'سورة'**
  String get goToSurah;

  /// Go-to target: an ayah. Source: docs/prd/PRD.ar.md (NV-03, the ayah of its surah-and-ayah target).
  ///
  /// In ar, this message translates to:
  /// **'آية'**
  String get goToAyah;

  /// Go-to target: a page. Source: docs/prd/PRD.ar.md (NV-03).
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get goToPage;

  /// Go-to target: a juz. Source: docs/prd/PRD.ar.md (NV-03).
  ///
  /// In ar, this message translates to:
  /// **'جزء'**
  String get goToJuz;

  /// Go-to target: a hizb. Source: docs/prd/PRD.ar.md (NV-03).
  ///
  /// In ar, this message translates to:
  /// **'حزب'**
  String get goToHizb;

  /// Go-to target: a quarter of a hizb. Source: docs/prd/PRD.ar.md (NV-03).
  ///
  /// In ar, this message translates to:
  /// **'ربع'**
  String get goToRub;

  /// The go-to error for an ayah number the surah does not have. ayah is the ayah number entered; surah is the surah's name from the pack, unchanged. Numbers arrive already written in Arabic-Indic digits. Source: docs/prd/PRD.ar.md (§8.2 acceptance criteria).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد آية {ayah} في {surah}'**
  String ayahNotInSurah(String ayah, String surah);

  /// The subtitle of the context sheet. Source: design/design-system/components/src/index.jsx (ContextSheet).
  ///
  /// In ar, this message translates to:
  /// **'ما قبلها وما بعدها'**
  String get contextSubtitle;

  /// Spoken name of the context sheet's amount switch. Source: design/design-system/components/src/index.jsx (ContextSheet).
  ///
  /// In ar, this message translates to:
  /// **'مقدار السياق'**
  String get contextAmountLabel;

  /// Context amount: one ayah, the first option of the context sheet's amount switch. Source: design/design-system/components/src/index.jsx (ContextSheet).
  ///
  /// In ar, this message translates to:
  /// **'آية'**
  String get contextOneAyah;

  /// Context amount: the whole surah. Source: design/design-system/components/src/index.jsx (ContextSheet).
  ///
  /// In ar, this message translates to:
  /// **'السورة'**
  String get contextSurah;

  /// Reference aria-label, index.jsx ContextSheet
  ///
  /// In ar, this message translates to:
  /// **'تشغيل من هذه الآية'**
  String get contextPlayFromAyah;

  /// The selected ayah's toolbar: bookmark it. Source: docs/prd/PRD.ar.md (§7.4).
  ///
  /// In ar, this message translates to:
  /// **'علامة'**
  String get toolbarBookmark;

  /// The selected ayah's toolbar: open its study sheet. Source: docs/prd/PRD.ar.md (§7.4).
  ///
  /// In ar, this message translates to:
  /// **'دراسة'**
  String get toolbarStudy;

  /// The selected ayah's toolbar: copy it. Source: docs/prd/PRD.ar.md (§7.4).
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get toolbarCopy;

  /// The selected ayah's toolbar: share it. Source: docs/prd/PRD.ar.md (§7.4).
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get toolbarShare;

  /// The title of the copy sheet. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الآية'**
  String get copySheetTitle;

  /// Copy form: the ayah text only. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'نص الآية فقط'**
  String get copyAyahOnly;

  /// Copy form: the ayah with the surah name. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الآية مع اسم السورة'**
  String get copyWithSurah;

  /// Copy form: the ayah with the surah name and its number. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الآية مع اسم السورة ورقمها'**
  String get copyWithSurahAndNumber;

  /// The copy sheet's action button. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'انسخ'**
  String get copyAction;

  /// The copied text in the full form. ayah is the ayah text taken from the pack by its address, unchanged; surah is the surah's name from the pack, unchanged; number is the ayah number. Numbers arrive already written in Arabic-Indic digits. Source: design/design-system/README.md (the copy format; PRD SH-01 gives the same).
  ///
  /// In ar, this message translates to:
  /// **'﴿{ayah}﴾ [{surah}: {number}]'**
  String copyFormatFull(String ayah, String surah, String number);

  /// The ornate bracket that opens a quoted ayah, before the ayah from the pack, in the copy sheet's preview. The copy format copyFormatFull opens with the same bracket. Source: design/identity-boards/Share.dc.html (the copy sheet's preview).
  ///
  /// In ar, this message translates to:
  /// **'﴿'**
  String get ayahQuoteOpen;

  /// The ornate bracket that closes a quoted ayah, after the ayah from the pack, in the copy sheet's preview. The copy format copyFormatFull closes the ayah with the same bracket. Source: design/identity-boards/Share.dc.html (the copy sheet's preview).
  ///
  /// In ar, this message translates to:
  /// **'﴾'**
  String get ayahQuoteClose;

  /// The copy sheet's preview of the full form: the reference that follows the quoted ayah, from the space after the closing bracket, as copyFormatFull ends; SurahName draws it (D-130). surah is the surah's name from the pack, unchanged; number is the ayah number, already written in Arabic-Indic digits. Source: design/identity-boards/Share.dc.html (the copy sheet's preview).
  ///
  /// In ar, this message translates to:
  /// **' [{surah}: {number}]'**
  String copyReferenceFull(String surah, String number);

  /// Spoken label of the share sheet's switch between the three card designs. Source: design/identity-boards/Share.dc.html (the title of the share cards).
  ///
  /// In ar, this message translates to:
  /// **'بطاقات مشاركة الآية'**
  String get shareDesignSwitchLabel;

  /// Share card design: emerald. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'زمرد'**
  String get shareDesignEmerald;

  /// Share card design: paper. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'ورق'**
  String get shareDesignPaper;

  /// Share card design: night. Source: design/identity-boards/Share.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'ليل'**
  String get shareDesignNight;

  /// Shown when the ayah cannot fit on any share card size. Source: docs/prd/PRD.ar.md (SH-03).
  ///
  /// In ar, this message translates to:
  /// **'الآية أطول من أن تتسع في بطاقة'**
  String get shareTooLong;

  /// The title of the search screen. Source: design/identity-boards/Search.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// Search sort order: nearest match. Source: docs/prd/PRD.ar.md (SR-05).
  ///
  /// In ar, this message translates to:
  /// **'الأقرب'**
  String get searchSortNearest;

  /// Search sort order: most frequent. Source: docs/prd/PRD.ar.md (SR-05).
  ///
  /// In ar, this message translates to:
  /// **'الأكثر ورودًا'**
  String get searchSortFrequent;

  /// Search scope: the whole Quran. Source: docs/prd/PRD.ar.md (SR-06).
  ///
  /// In ar, this message translates to:
  /// **'القرآن كله'**
  String get searchScopeAll;

  /// One of the fixed sentences: the chosen tafsir has no passage for this ayah. Source: docs/DESIGN_SYSTEM.md ("When data is missing"; PRD §8.8 acceptance criteria).
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد تفسير لهذه الآية في هذا الكتاب'**
  String get tafsirNoPassage;

  /// One of the identity's short error sentences: the connection failed. Source: docs/prd/PRD.ar.md (§7.5).
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال'**
  String get connectionFailed;

  /// One of the identity's short empty-state sentences: no bookmarks yet. Source: docs/prd/PRD.ar.md (§7.5).
  ///
  /// In ar, this message translates to:
  /// **'لا توجد علامات بعد'**
  String get noBookmarksYet;

  /// The undo action after a deletion. Source: docs/DESIGN_SYSTEM.md (the icon table, Delete row).
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// Spoken name of the back button of a pushed screen. Source: design/identity-boards/Search.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// The button that returns the reader to the recited ayah after manual scrolling. Source: docs/prd/PRD.ar.md (SY-03).
  ///
  /// In ar, this message translates to:
  /// **'عُد إلى موضع التلاوة'**
  String get returnToRecitation;

  /// The tag on a recitation that has word timing. Source: docs/prd/PRD.ar.md (§8.4 acceptance criteria).
  ///
  /// In ar, this message translates to:
  /// **'توقيت كلمات'**
  String get wordTimingTag;

  /// The title of the resource manager. Source: docs/prd/PRD.ar.md (§7.1 and the §8.17 heading).
  ///
  /// In ar, this message translates to:
  /// **'مدير الموارد'**
  String get resourceManagerTitle;

  /// Resource category: recitations. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'التلاوات'**
  String get resourceCategoryRecitations;

  /// Resource category: tafsirs. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'التفاسير'**
  String get resourceCategoryTafsirs;

  /// Resource category: the page mushaf. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'مصحف الصفحات'**
  String get resourceCategoryPageMushaf;

  /// Resource category: riwayat. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'الروايات'**
  String get resourceCategoryRiwayat;

  /// Resource category: tajweed. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'التجويد'**
  String get resourceCategoryTajweed;

  /// Resource category: linguistic resources. Source: docs/prd/PRD.ar.md (OF-01).
  ///
  /// In ar, this message translates to:
  /// **'الموارد اللغوية'**
  String get resourceCategoryLinguistic;

  /// A resource's state when it can be downloaded, for a masculine noun. Source: docs/prd/PRD.ar.md (OF-02).
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get resourceAvailableMasculine;

  /// The action that downloads a resource again. Source: docs/prd/PRD.ar.md (OF-02).
  ///
  /// In ar, this message translates to:
  /// **'إعادة التنزيل'**
  String get resourceRedownload;

  /// The title of the settings screen. Source: docs/prd/PRD.ar.md (§7.1).
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// The settings entry for the theme. Source: docs/prd/PRD.ar.md (§7.1).
  ///
  /// In ar, this message translates to:
  /// **'السمة'**
  String get themeLabel;

  /// The settings entry for the text. Source: docs/prd/PRD.ar.md (§7.1).
  ///
  /// In ar, this message translates to:
  /// **'النص'**
  String get textSettingsLabel;

  /// The setting that follows the system dark mode. Source: docs/prd/PRD.ar.md (§7.8 and RD-08).
  ///
  /// In ar, this message translates to:
  /// **'اتباع وضع النظام الداكن'**
  String get followSystemDark;

  /// The title of the sources and licences screen. Source: docs/prd/PRD.ar.md (§7.1).
  ///
  /// In ar, this message translates to:
  /// **'المصادر والتراخيص'**
  String get sourcesTitle;

  /// The entry and title for bookmarks and notes. Source: docs/prd/PRD.ar.md (§7.1).
  ///
  /// In ar, this message translates to:
  /// **'العلامات والملاحظات'**
  String get bookmarksAndNotes;

  /// The listen screen's button that changes the recitation. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get playerChange;

  /// The player's position: an ayah of the surah's total. ayah is the ayah number; total is the surah's ayah count. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah} من {total}'**
  String playerAyahOfTotal(String ayah, String total);

  /// The silence between repeats, in seconds. seconds is the number of seconds. Numbers arrive already written in Arabic-Indic digits. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'صمت {seconds} ث'**
  String playerSilenceSeconds(String seconds);

  /// Label of the Stepper that sets the silence between ayat (AU-11). Source: Appendix B of docs/plans/PHASE1.md, approved by the owner (D-128, 4).
  ///
  /// In ar, this message translates to:
  /// **'الصمت بين الآيات'**
  String get playerSilenceBetweenAyat;

  /// The seconds unit after a Stepper's value, as the identity's Stepper preview writes it for the silence.
  ///
  /// In ar, this message translates to:
  /// **'ث'**
  String get playerSecondsUnit;

  /// Title of the range picker sheet and spoken name of its range kinds (PRD §7.7). Source: Appendix B of docs/plans/PHASE1.md, approved by the owner (D-128, 4).
  ///
  /// In ar, this message translates to:
  /// **'محدد النطاق'**
  String get rangeSelectorTitle;

  /// Spoken name of the queue button. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التشغيل'**
  String get queueLabel;

  /// A recitation's line: its riwaya, downloaded. riwaya is the riwaya's name from the pack, unchanged. Source: design/identity-boards/Screens2.dc.html.
  ///
  /// In ar, this message translates to:
  /// **'{riwaya} · محمّلة'**
  String recitationDownloadedLine(String riwaya);

  /// Play from the ayah tools: this ayah only. Source: docs/prd/PRD.ar.md (AU-03).
  ///
  /// In ar, this message translates to:
  /// **'الآية فقط'**
  String get playOnlyAyah;

  /// Play from the ayah tools: to the end of the page. Source: docs/prd/PRD.ar.md (AU-03).
  ///
  /// In ar, this message translates to:
  /// **'حتى نهاية الصفحة'**
  String get playToPageEnd;

  /// Play from the ayah tools: to the end of the surah. Source: docs/prd/PRD.ar.md (AU-03).
  ///
  /// In ar, this message translates to:
  /// **'حتى نهاية السورة'**
  String get playToSurahEnd;

  /// Play from the ayah tools: to the end of the juz. Source: docs/prd/PRD.ar.md (AU-03).
  ///
  /// In ar, this message translates to:
  /// **'حتى نهاية الجزء'**
  String get playToJuzEnd;

  /// Play from the ayah tools: until the user stops it. Source: docs/prd/PRD.ar.md (AU-03).
  ///
  /// In ar, this message translates to:
  /// **'حتى أوقفه'**
  String get playUntilStopped;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'فتح التطبيق على آخر موضع'**
  String get openAtLastPosition;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'منع إطفاء الشاشة أثناء القراءة أو التلاوة'**
  String get keepScreenAwake;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'حجم النص'**
  String get textSizeLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'وضع بلا تشتيت'**
  String get distractionFreeMode;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'السرعة'**
  String get playerSpeed;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'نهاية الآية'**
  String get playerEndOfAyah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'نهاية السورة'**
  String get playerEndOfSurah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'التوقف بعد الآية'**
  String get stopAfterAyah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'التوقف بعد الصفحة'**
  String get stopAfterPage;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'التوقف بعد السورة'**
  String get stopAfterSurah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get playerStop;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'السورة التالية'**
  String get nextSurah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'السورة السابقة'**
  String get previousSurah;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'الجودة'**
  String get qualityLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'Wi-Fi فقط'**
  String get wifiOnly;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get sortNewest;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get noteLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'وسوم'**
  String get tagsLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'سجل البحث'**
  String get searchHistoryTitle;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get resourceUpdate;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'جارٍ · {percent}'**
  String resourceInProgress(String percent);

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'بلا نهاية'**
  String get repeatUnlimited;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'قارئ التفسير'**
  String get tafsirReaderTitle;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'اختيار التلاوة'**
  String get recitationPickerTitle;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'التفسير الافتراضي'**
  String get defaultTafsirLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'المنزَّل'**
  String get resourcesDownloaded;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'المتاح'**
  String get resourcesAvailable;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'المؤلف'**
  String get sourceAuthor;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'الطبعة أو المحقق'**
  String get sourceEditionOrEditor;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'مصدر الرقمنة'**
  String get sourceDigitisation;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get versionLabel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'﴿{ayah}﴾'**
  String copyFormatAyahOnly(String ayah);

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'﴿{ayah}﴾ [{surah}]'**
  String copyFormatWithSurah(String ayah, String surah);

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'أبلغ عن خطأ'**
  String get reportError;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'وضع العرض'**
  String get setupStepDisplayMode;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'المستوى'**
  String get setupStepLevel;

  /// Owner, 2026-10-28 (D-128 (4)); wording from docs/plans/PHASE1.md section 8, Appendix B (PRD requirement text).
  ///
  /// In ar, this message translates to:
  /// **'التلاوة'**
  String get setupStepRecitation;

  /// Owner, 2026-10-28 (D-130). The copy preview's reference part of copyFormatWithSurah: the space after the closing bracket, then the surah's name from the pack, unchanged, in square brackets.
  ///
  /// In ar, this message translates to:
  /// **' [{surah}]'**
  String copyReferenceSurah(String surah);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'اختر طريقة عرض المصحف'**
  String get setupDisplayModePrompt;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'اختر مستوى الواجهة، ويمكنك تغييره متى شئت من الإعدادات'**
  String get setupLevelPrompt;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'اختر التلاوة التي تستمع إليها'**
  String get setupRecitationPrompt;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get setupContinue;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'ابدأ القراءة'**
  String get setupFinish;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'أرسل البلاغ'**
  String get reportSend;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'يفتح البلاغ تطبيق البريد برسالة فيها الموضع والمصدر وإصداره، وتراها قبل أن ترسلها.'**
  String get reportNote;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'نص المصحف لم يجتز التحقق'**
  String get integrityBaseTitle;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لن يُعرض نص لم يجتز التحقق. حدّث التطبيق أو أعد تثبيته.'**
  String get integrityBaseBody;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'هذه الحزمة لم تجتز التحقق'**
  String get integrityPackTitle;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لن يُعرض محتواها حتى تُنزَّل من جديد.'**
  String get integrityPackBody;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get integrityIconLabel;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد صفحة {page}'**
  String pageNotFound(String page);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد جزء {juz}'**
  String juzNotFound(String juz);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حزب {hizb}'**
  String hizbNotFound(String hizb);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد ربع {rub}'**
  String rubNotFound(String rub);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سورة بهذا الاسم'**
  String get surahNotFound;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد سورة {surah}'**
  String surahNumberNotFound(String surah);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لم نتعرّف على الموضع المكتوب'**
  String get addressUnreadable;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'أظهر هذه الأداة دائمًا'**
  String get levelAlwaysShow;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'المساحة المتاحة في الجهاز لا تكفي'**
  String get lowSpace;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'المستخدم {used} · المتاح {free}'**
  String storageSummary(String used, String free);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'الحجم {size}'**
  String downloadSize(String size);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'بانتظار شبكة Wi-Fi'**
  String get waitingForWifi;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'يتوفر إصدار جديد'**
  String get updateAvailable;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'حذف الحزمة'**
  String get deletePackTitle;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تنزيلها من جديد متى شئت.'**
  String get deletePackBody;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حفظ الملف'**
  String get downloadNotSaved;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ملاحظات بعد'**
  String get noNotesYet;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لم نجد نتائج'**
  String get noSearchResults;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تفاسير منزَّلة بعد'**
  String get noTafsirsYet;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تلاوات منزَّلة بعد'**
  String get noRecitationsYet;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'قائمة التشغيل فارغة'**
  String get queueEmpty;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'اكتب ملاحظتك'**
  String get noteHint;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get noteSave;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'احذف الملاحظة'**
  String get noteDelete;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الآية'**
  String get shareSheetTitle;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى قائمة التشغيل'**
  String get addToQueue;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'التكرار {current} من {total}'**
  String repeatCounter(String current, String total);

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get rangeFrom;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get rangeTo;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'الآية'**
  String get repeatUnitAyah;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'النطاق'**
  String get repeatUnitRange;

  /// Lead, 2026-10-28, D-128 (5)
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح بيانات التطبيق، فلن تُحفظ تغييراتك في هذه الجلسة.'**
  String get userDataNotSaved;

  /// Lead, 2026-10-28, D-128 (5). count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, zero{لا مواضع} one{موضع واحد} two{موضعان} few{{digits} مواضع} many{{digits} موضعًا} other{{digits} موضع}}'**
  String searchPlaces(int count, String digits);

  /// Lead, 2026-10-28, D-128 (5). count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, one{دقيقة واحدة} two{دقيقتان} few{{digits} دقائق} many{{digits} دقيقة} other{{digits} دقيقة}}'**
  String minutesCount(int count, String digits);

  /// Lead, 2026-10-28, D-128 (5). A source's version, made of the approved label versionLabel (TF-05) and the number. version is the pack's version, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String sourceVersion(String version);

  /// Lead, 2026-10-28, D-128 (5). A tafsir book's publisher as the source details list it (TF-05). publisher is the publisher from the pack, substituted whole and unchanged.
  ///
  /// In ar, this message translates to:
  /// **'الناشر: {publisher}'**
  String sourcePublisher(String publisher);

  /// Lead, 2026-10-28, D-128 (5). The ayat a tafsir passage explains together (TF-04), made of the approved words rangeFrom, rangeTo and repeatUnitAyah. from and to are ayah numbers, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'من الآية {from} إلى الآية {to}'**
  String tafsirRange(String from, String to);

  /// Lead, 2026-10-28, D-128 (5). A run of ayah numbers inside the reference of a copied tafsir passage, with an en dash and no word. from and to are ayah numbers, already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{from}–{to}'**
  String ayahsRangeShort(String from, String to);

  /// Pending the owner: credit wording (SOURCES.md, Zaydi Library). A copied tafsir passage with its attribution (TF-10). passage, title, author and surah are text from the pack, substituted whole and unchanged; ayahs is the passage's ayah number or ayahsRangeShort; source is the digitisation source's name from the manifest; version is sourceVersion with the pack's version.
  ///
  /// In ar, this message translates to:
  /// **'{passage}\n\n{title} · {author}\n[{surah}: {ayahs}]\n{source} · {version}'**
  String tafsirCopyFormat(
    String passage,
    String title,
    String author,
    String surah,
    String ayahs,
    String source,
    String version,
  );

  /// The bookmarks screen's search field: its hint and spoken name. Wording of SR-08 in docs/prd/PRD.ar.md. P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'ابحث في العلامات والملاحظات'**
  String get bookmarksSearchHint;

  /// The bookmarks tab of the bookmarks screen. First half of the screen title, docs/prd/PRD.ar.md (§7.1). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'العلامات'**
  String get bookmarksTabBookmarks;

  /// The notes tab of the bookmarks screen. Second half of the screen title, docs/prd/PRD.ar.md (§7.1). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات'**
  String get bookmarksTabNotes;

  /// The number of bookmarks listed. P1-24, proposed for the lead to approve under D-128 (5). count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{علامة واحدة} =2{علامتان} few{{digits} علامات} other{{digits} علامة}}'**
  String bookmarksCount(int count, String digits);

  /// The number of notes listed. P1-24, proposed for the lead to approve under D-128 (5). count chooses the Arabic plural form; digits is the same number already written in Arabic-Indic digits.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ملاحظة واحدة} =2{ملاحظتان} few{{digits} ملاحظات} other{{digits} ملاحظة}}'**
  String notesCount(int count, String digits);

  /// Name of the category group of tags, in the filter and in the note editor. Wording of UD-03 in docs/prd/PRD.ar.md. P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get categoryLabel;

  /// Spoken name of the delete button of a bookmark, beside noteDelete. P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'احذف العلامة'**
  String get bookmarkDelete;

  /// The line beside the undo action after a bookmark or a note is deleted (UD-07). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف'**
  String get itemDeleted;

  /// The button that starts another note on an ayah that has some (UD-04). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة جديدة'**
  String get noteAdd;

  /// Hint and spoken name of the field that makes a free tag (UD-02). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'وسم جديد'**
  String get tagNewHint;

  /// The button that makes the free tag typed in the note editor (UD-02). P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'أضف'**
  String get tagAdd;

  /// The spoken hint of a tag on a bookmark's or note's card, whose press opens the editor of its category and tags. Wording of UD-03 in docs/prd/PRD.ar.md. P1-24, proposed for the lead to approve under D-128 (5).
  ///
  /// In ar, this message translates to:
  /// **'غيّر التصنيف والوسوم'**
  String get tagsEditHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
