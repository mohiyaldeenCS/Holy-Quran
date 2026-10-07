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

  /// The surah name inside the surah header, after the word for surah, as the identity's SurahHeader writes it. name is the surah's name without that word.
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String surahHeaderName(String name);

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
