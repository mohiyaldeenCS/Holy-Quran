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
