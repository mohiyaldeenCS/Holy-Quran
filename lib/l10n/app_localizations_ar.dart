// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'القرآن الكريم';

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabMushaf => 'المصحف';

  @override
  String get tabListen => 'الاستماع';

  @override
  String get tabStudy => 'الدراسة';

  @override
  String get tabMore => 'المزيد';

  @override
  String get mainNavigationLabel => 'التنقل الرئيسي';

  @override
  String ayahCount(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits آية',
      few: '$digits آيات',
      two: 'آيتان',
      one: 'آية واحدة',
    );
    return '$_temp0';
  }

  @override
  String ayahMarkerLabel(String number) {
    return 'الآية $number';
  }

  @override
  String surahTitle(String name) {
    return 'سورة $name';
  }

  @override
  String surahAyahReference(String name, String ayah) {
    return '$name · الآية $ayah';
  }

  @override
  String surahTitleAyahReference(String name, String ayah) {
    return 'سورة $name · الآية $ayah';
  }

  @override
  String get ayahRowPlayFromHere => 'تشغيل من هنا';

  @override
  String get ayahRowBookmark => 'علامة مرجعية';

  @override
  String get ayahRowStudy => 'مركز الدراسة';

  @override
  String get revelationMakki => 'مكية';

  @override
  String get revelationMadani => 'مدنية';

  @override
  String surahListMeta(String revelation, String count) {
    return '$revelation · $count';
  }

  @override
  String get surahListLastRead => 'آخر قراءة';

  @override
  String get surahListPage => 'صفحة';

  @override
  String percentValue(String digits) {
    return '$digits٪';
  }

  @override
  String timesCount(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits مرة',
      few: '$digits مرات',
      two: 'مرتان',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get playerRepeat => 'تكرار';

  @override
  String playerRepeatTimes(String times) {
    return 'تكرار $times';
  }

  @override
  String get playerPreviousAyah => 'الآية السابقة';

  @override
  String get playerPause => 'إيقاف مؤقت';

  @override
  String get playerPlay => 'تشغيل';

  @override
  String get playerNextAyah => 'الآية التالية';

  @override
  String get playerSleepTimer => 'مؤقت النوم';

  @override
  String get playerPosition => 'موضع التلاوة';

  @override
  String get continueReadingLabel => 'أكمل القراءة';

  @override
  String get continueReadingAction => 'تابع القراءة';

  @override
  String get continueReadingPosition => 'الموضع في المصحف';

  @override
  String resourceDownloadedMeta(String size) {
    return 'تم التنزيل · $size';
  }

  @override
  String get resourceDownloaded => 'تم التنزيل';

  @override
  String resourceAvailableMeta(String size) {
    return 'متاحة · $size';
  }

  @override
  String get resourceAvailable => 'متاحة';

  @override
  String get resourceDelete => 'حذف';

  @override
  String get resourceDownload => 'تنزيل';

  @override
  String resourceDownloading(String title) {
    return 'تنزيل $title';
  }

  @override
  String get wordSheetTabText => 'النص';

  @override
  String get wordSheetTabTafsir => 'التفسير';

  @override
  String get wordSheetTabIrab => 'الإعراب';

  @override
  String get wordSheetTabSarf => 'الصرف';

  @override
  String get wordSheetTabTajweed => 'التجويد';

  @override
  String wordSheetPosition(String n, String m) {
    return 'الكلمة $n من $m';
  }

  @override
  String get tagMemorise => 'حفظ';

  @override
  String get tagReview => 'مراجعة';

  @override
  String get tagStudy => 'دراسة';

  @override
  String get tagImportant => 'آيات مهمة';

  @override
  String stepperDecrease(String label) {
    return 'إنقاص $label';
  }

  @override
  String stepperIncrease(String label) {
    return 'زيادة $label';
  }

  @override
  String stepperValueWithUnit(String value, String unit) {
    return '$value $unit';
  }

  @override
  String get searchFieldHint => 'ابحث في القرآن';

  @override
  String get searchFieldClear => 'مسح';

  @override
  String get searchModesLabel => 'نوع البحث';

  @override
  String get searchModeWord => 'كلمة';

  @override
  String get searchModeRoot => 'الجذر';

  @override
  String get searchModeBare => 'بلا تشكيل';

  @override
  String get searchModeDerived => 'المشتقات';

  @override
  String get searchModeTafsir => 'في التفاسير';

  @override
  String get searchModeTopics => 'الموضوعات';

  @override
  String get searchSortMushafOrder => 'ترتيب المصحف';

  @override
  String get searchResultContext => 'سياق الآية';

  @override
  String get searchResultOpen => 'افتح في المصحف';

  @override
  String get searchResultShowWhole => 'الآية طويلة · اعرضها كاملة';

  @override
  String get homeSearch => 'بحث';

  @override
  String get homeDoorIndex => 'الفهرس';

  @override
  String get homeDoorBookmarks => 'العلامات';

  @override
  String get continueListeningLabel => 'أكمل الاستماع';

  @override
  String get gallerySectionAyahRow => 'صف الآية';

  @override
  String get gallerySectionSurahListItem => 'صف الفهرس';

  @override
  String get gallerySectionTag => 'الوسوم';

  @override
  String get gallerySectionStepper => 'مُعدّل الرقم';

  @override
  String get gallerySectionProgressBar => 'شريط التقدّم';

  @override
  String get gallerySectionMiniPlayer => 'المشغّل';

  @override
  String get gallerySectionContinueCard => 'أكمل القراءة';

  @override
  String get gallerySectionResourceRow => 'مدير التنزيلات';

  @override
  String get gallerySectionReaderPlayerBar => 'شريط المشغّل في القارئ';

  @override
  String get gallerySectionWordSheet => 'ورقة الكلمة';

  @override
  String get gallerySectionSearchField => 'حقل البحث';

  @override
  String get gallerySectionModeChips => 'أنواع البحث';

  @override
  String get gallerySectionSearchSummary => 'ملخص النتائج';

  @override
  String get gallerySectionSearchResult => 'نتيجة البحث';

  @override
  String get gallerySectionHomeHeader => 'رأس الرئيسية';

  @override
  String get gallerySectionHomeDoor => 'أبواب الرئيسية';

  @override
  String get gallerySectionContinueListeningRow => 'أكمل الاستماع';

  @override
  String get gallerySectionShareCard => 'بطاقات مشاركة الآية';

  @override
  String get gallerySectionSplash => 'شاشة البداية';

  @override
  String get galleryTitle => 'معرض المكوّنات';

  @override
  String get themePaper => 'ورق';

  @override
  String get themeNight => 'ليل';

  @override
  String get themeSepia => 'سيبيا';

  @override
  String get themeContrast => 'تباين عالٍ';

  @override
  String get levelLabel => 'مستوى الواجهة';

  @override
  String get levelSimple => 'بسيط';

  @override
  String get levelMedium => 'متوسط';

  @override
  String get levelStudy => 'دراسة';

  @override
  String get gallerySectionMark => 'الرمز';

  @override
  String get gallerySectionLockup => 'الشعار الكامل';

  @override
  String get gallerySectionIcons => 'الأيقونات';

  @override
  String get gallerySectionButtons => 'الأزرار';

  @override
  String get gallerySectionIconButtons => 'أزرار الأيقونات';

  @override
  String get gallerySectionSwitches => 'المفاتيح';

  @override
  String get gallerySectionLevelSwitch => 'مستوى الواجهة';

  @override
  String get gallerySectionTabBar => 'شريط التنقل';

  @override
  String get gallerySectionQuranText => 'النص القرآني';

  @override
  String get gallerySectionAyahMarker => 'فاصلة الآية';

  @override
  String get gallerySectionSurahHeader => 'رأس السورة';

  @override
  String get galleryButtonPrimary => 'ابدأ التلاوة';

  @override
  String get galleryButtonOutline => 'علامة مرجعية';

  @override
  String get galleryButtonTonal => 'أضف إلى مجموعة';

  @override
  String get galleryButtonText => 'إلغاء';

  @override
  String get galleryButtonDisabled => 'غير متاح';

  @override
  String get galleryIconButtonPlayFromHere => 'تشغيل من هنا';

  @override
  String get galleryIconButtonBookmark => 'علامة مرجعية';

  @override
  String get galleryIconButtonStudy => 'مركز الدراسة';

  @override
  String get galleryIconButtonSearch => 'بحث';

  @override
  String get galleryIconButtonPlay => 'تشغيل';

  @override
  String get gallerySwitchTajweed => 'ألوان التجويد';

  @override
  String get gallerySwitchKeepAwake => 'منع إطفاء الشاشة أثناء التلاوة';

  @override
  String get sampleText => 'نص تجريبي للاختبار وليس آية';

  @override
  String get sampleSurahName => 'اسم تجريبي';

  @override
  String get sampleInfo => 'سطر تجريبي';

  @override
  String get galleryStepperRepeat => 'تكرار كل آية';

  @override
  String get galleryStepperMerge => 'تكرار الدمج';

  @override
  String get galleryStepperSilence => 'الصمت بعد كل تكرار';

  @override
  String get galleryStepperSeconds => 'ث';

  @override
  String get gallerySpeed => '١٫٠×';

  @override
  String get sampleReciter => 'قارئ تجريبي';

  @override
  String get sampleResourceTitle => 'مورد تجريبي';

  @override
  String get sampleSize => 'حجم تجريبي';

  @override
  String get sampleWord => 'كلمة تجريبية';

  @override
  String get sampleLongText =>
      'نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام في المكوّنات، وهو ليس آية ولا مأخوذًا من أي مصدر';

  @override
  String get sampleMeta => 'موضع تجريبي · صفحة تجريبية';

  @override
  String get sampleSearchTitle => 'بحث تجريبي';

  @override
  String get sampleSearchCount => 'عدد تجريبي من النتائج';

  @override
  String get sampleRowLabel => 'عنوان تجريبي';

  @override
  String get sampleRowValue => 'قيمة تجريبية';

  @override
  String get sampleNote => 'ملاحظة تجريبية عن المصدر';
}
