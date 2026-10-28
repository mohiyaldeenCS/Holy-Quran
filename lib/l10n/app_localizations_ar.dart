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
  String get dataSeparator => ' · ';

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
  String playerRepeatTimes(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تكرار $digits مرة',
      few: 'تكرار $digits مرات',
      two: 'تكرار مرتين',
      one: 'تكرار مرة واحدة',
    );
    return '$_temp0';
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
  String playerSpeedValue(String whole, String fraction) {
    return '$whole٫$fraction×';
  }

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
  String resourceSizeMegabytes(String digits) {
    return '$digits م.ب';
  }

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

  @override
  String get appIconLabel => 'شعار القرآن الكريم';

  @override
  String get markLabel => 'رمز القرآن الكريم';

  @override
  String get homeGreeting => 'السلام عليكم';

  @override
  String get homeContinueHint => 'أكمل من حيث توقفت';

  @override
  String readingPositionLine(String ayah, String page, String juz) {
    return 'الآية $ayah · صفحة $page · الجزء $juz';
  }

  @override
  String get indexTitle => 'الفهرس';

  @override
  String indexSummary(String surahs, String juz) {
    return '$surahs سورة · $juz جزءًا';
  }

  @override
  String get indexTabSurahs => 'السور';

  @override
  String get indexTabJuz => 'الأجزاء';

  @override
  String get indexTabHizb => 'الأحزاب';

  @override
  String juzLabel(String number) {
    return 'الجزء $number';
  }

  @override
  String hizbLabel(String number) {
    return 'الحزب $number';
  }

  @override
  String get rubLabel => 'ربع';

  @override
  String pageLabel(String number) {
    return 'صفحة $number';
  }

  @override
  String juzPageLine(String juz, String page) {
    return 'الجزء $juz · صفحة $page';
  }

  @override
  String juzHizbLine(String juz, String hizb) {
    return 'الجزء $juz · الحزب $hizb';
  }

  @override
  String get sajdaLabel => 'سجدة';

  @override
  String surahInfoLine(String revelation, String count, String order) {
    return '$revelation · $count · ترتيبها $order';
  }

  @override
  String get surahIntroTitle => 'مقدمة السورة';

  @override
  String get goToTitle => 'اذهب إلى';

  @override
  String get goToSurah => 'سورة';

  @override
  String get goToAyah => 'آية';

  @override
  String get goToPage => 'صفحة';

  @override
  String get goToJuz => 'جزء';

  @override
  String get goToHizb => 'حزب';

  @override
  String get goToRub => 'ربع';

  @override
  String ayahNotInSurah(String ayah, String surah) {
    return 'لا توجد آية $ayah في $surah';
  }

  @override
  String get contextSubtitle => 'ما قبلها وما بعدها';

  @override
  String get contextAmountLabel => 'مقدار السياق';

  @override
  String get contextOneAyah => 'آية';

  @override
  String get contextSurah => 'السورة';

  @override
  String get toolbarBookmark => 'علامة';

  @override
  String get toolbarStudy => 'دراسة';

  @override
  String get toolbarCopy => 'نسخ';

  @override
  String get toolbarShare => 'مشاركة';

  @override
  String get copySheetTitle => 'نسخ الآية';

  @override
  String get copyAyahOnly => 'نص الآية فقط';

  @override
  String get copyWithSurah => 'الآية مع اسم السورة';

  @override
  String get copyWithSurahAndNumber => 'الآية مع اسم السورة ورقمها';

  @override
  String get copyAction => 'انسخ';

  @override
  String copyFormatFull(String ayah, String surah, String number) {
    return '﴿$ayah﴾ [$surah: $number]';
  }

  @override
  String get ayahQuoteOpen => '﴿';

  @override
  String get ayahQuoteClose => '﴾';

  @override
  String copyReferenceFull(String surah, String number) {
    return ' [$surah: $number]';
  }

  @override
  String get shareDesignSwitchLabel => 'بطاقات مشاركة الآية';

  @override
  String get shareDesignEmerald => 'زمرد';

  @override
  String get shareDesignPaper => 'ورق';

  @override
  String get shareDesignNight => 'ليل';

  @override
  String get shareTooLong => 'الآية أطول من أن تتسع في بطاقة';

  @override
  String get searchTitle => 'البحث';

  @override
  String get searchSortNearest => 'الأقرب';

  @override
  String get searchSortFrequent => 'الأكثر ورودًا';

  @override
  String get searchScopeAll => 'القرآن كله';

  @override
  String get tafsirNoPassage => 'لا يوجد تفسير لهذه الآية في هذا الكتاب';

  @override
  String get connectionFailed => 'تعذّر الاتصال';

  @override
  String get noBookmarksYet => 'لا توجد علامات بعد';

  @override
  String get undo => 'تراجع';

  @override
  String get back => 'رجوع';

  @override
  String get returnToRecitation => 'عُد إلى موضع التلاوة';

  @override
  String get wordTimingTag => 'توقيت كلمات';

  @override
  String get resourceManagerTitle => 'مدير الموارد';

  @override
  String get resourceCategoryRecitations => 'التلاوات';

  @override
  String get resourceCategoryTafsirs => 'التفاسير';

  @override
  String get resourceCategoryPageMushaf => 'مصحف الصفحات';

  @override
  String get resourceCategoryRiwayat => 'الروايات';

  @override
  String get resourceCategoryTajweed => 'التجويد';

  @override
  String get resourceCategoryLinguistic => 'الموارد اللغوية';

  @override
  String get resourceAvailableMasculine => 'متاح';

  @override
  String get resourceRedownload => 'إعادة التنزيل';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get themeLabel => 'السمة';

  @override
  String get textSettingsLabel => 'النص';

  @override
  String get followSystemDark => 'اتباع وضع النظام الداكن';

  @override
  String get sourcesTitle => 'المصادر والتراخيص';

  @override
  String get bookmarksAndNotes => 'العلامات والملاحظات';

  @override
  String get playerChange => 'تغيير';

  @override
  String playerAyahOfTotal(String ayah, String total) {
    return 'الآية $ayah من $total';
  }

  @override
  String playerSilenceSeconds(String seconds) {
    return 'صمت $seconds ث';
  }

  @override
  String get playerSilenceBetweenAyat => 'الصمت بين الآيات';

  @override
  String get playerSecondsUnit => 'ث';

  @override
  String get rangeSelectorTitle => 'محدد النطاق';

  @override
  String get queueLabel => 'قائمة التشغيل';

  @override
  String recitationDownloadedLine(String riwaya) {
    return '$riwaya · محمّلة';
  }

  @override
  String get playOnlyAyah => 'الآية فقط';

  @override
  String get playToPageEnd => 'حتى نهاية الصفحة';

  @override
  String get playToSurahEnd => 'حتى نهاية السورة';

  @override
  String get playToJuzEnd => 'حتى نهاية الجزء';

  @override
  String get playUntilStopped => 'حتى أوقفه';

  @override
  String get openAtLastPosition => 'فتح التطبيق على آخر موضع';

  @override
  String get keepScreenAwake => 'منع إطفاء الشاشة أثناء القراءة أو التلاوة';

  @override
  String get textSizeLabel => 'حجم النص';

  @override
  String get distractionFreeMode => 'وضع بلا تشتيت';

  @override
  String get playerSpeed => 'السرعة';

  @override
  String get playerEndOfAyah => 'نهاية الآية';

  @override
  String get playerEndOfSurah => 'نهاية السورة';

  @override
  String get stopAfterAyah => 'التوقف بعد الآية';

  @override
  String get stopAfterPage => 'التوقف بعد الصفحة';

  @override
  String get stopAfterSurah => 'التوقف بعد السورة';

  @override
  String get playerStop => 'إيقاف';

  @override
  String get nextSurah => 'السورة التالية';

  @override
  String get previousSurah => 'السورة السابقة';

  @override
  String get qualityLabel => 'الجودة';

  @override
  String get wifiOnly => 'Wi-Fi فقط';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get noteLabel => 'ملاحظة';

  @override
  String get tagsLabel => 'وسوم';

  @override
  String get searchHistoryTitle => 'سجل البحث';

  @override
  String get resourceUpdate => 'تحديث';

  @override
  String resourceInProgress(String percent) {
    return 'جارٍ · $percent';
  }

  @override
  String get repeatUnlimited => 'بلا نهاية';

  @override
  String get tafsirReaderTitle => 'قارئ التفسير';

  @override
  String get recitationPickerTitle => 'اختيار التلاوة';

  @override
  String get defaultTafsirLabel => 'التفسير الافتراضي';

  @override
  String get resourcesDownloaded => 'المنزَّل';

  @override
  String get resourcesAvailable => 'المتاح';

  @override
  String get sourceAuthor => 'المؤلف';

  @override
  String get sourceEditionOrEditor => 'الطبعة أو المحقق';

  @override
  String get sourceDigitisation => 'مصدر الرقمنة';

  @override
  String get versionLabel => 'الإصدار';

  @override
  String copyFormatAyahOnly(String ayah) {
    return '﴿$ayah﴾';
  }

  @override
  String copyFormatWithSurah(String ayah, String surah) {
    return '﴿$ayah﴾ [$surah]';
  }

  @override
  String get reportError => 'أبلغ عن خطأ';

  @override
  String get setupStepDisplayMode => 'وضع العرض';

  @override
  String get setupStepLevel => 'المستوى';

  @override
  String get setupStepRecitation => 'التلاوة';

  @override
  String copyReferenceSurah(String surah) {
    return ' [$surah]';
  }

  @override
  String get setupDisplayModePrompt => 'اختر طريقة عرض المصحف';

  @override
  String get setupLevelPrompt =>
      'اختر مستوى الواجهة، ويمكنك تغييره متى شئت من الإعدادات';

  @override
  String get setupRecitationPrompt => 'اختر التلاوة التي تستمع إليها';

  @override
  String get setupContinue => 'متابعة';

  @override
  String get setupFinish => 'ابدأ القراءة';

  @override
  String get reportSend => 'أرسل البلاغ';

  @override
  String get reportNote =>
      'يفتح البلاغ تطبيق البريد برسالة فيها الموضع والمصدر وإصداره، وتراها قبل أن ترسلها.';

  @override
  String get integrityBaseTitle => 'نص المصحف لم يجتز التحقق';

  @override
  String get integrityBaseBody =>
      'لن يُعرض نص لم يجتز التحقق. حدّث التطبيق أو أعد تثبيته.';

  @override
  String get integrityPackTitle => 'هذه الحزمة لم تجتز التحقق';

  @override
  String get integrityPackBody => 'لن يُعرض محتواها حتى تُنزَّل من جديد.';

  @override
  String get integrityIconLabel => 'تنبيه';

  @override
  String pageNotFound(String page) {
    return 'لا توجد صفحة $page';
  }

  @override
  String juzNotFound(String juz) {
    return 'لا يوجد جزء $juz';
  }

  @override
  String hizbNotFound(String hizb) {
    return 'لا يوجد حزب $hizb';
  }

  @override
  String rubNotFound(String rub) {
    return 'لا يوجد ربع $rub';
  }

  @override
  String get surahNotFound => 'لا توجد سورة بهذا الاسم';

  @override
  String get addressUnreadable => 'لم نتعرّف على الموضع المكتوب';

  @override
  String get levelAlwaysShow => 'أظهر هذه الأداة دائمًا';

  @override
  String get lowSpace => 'المساحة المتاحة في الجهاز لا تكفي';

  @override
  String storageSummary(String used, String free) {
    return 'المستخدم $used · المتاح $free';
  }

  @override
  String downloadSize(String size) {
    return 'الحجم $size';
  }

  @override
  String get waitingForWifi => 'بانتظار شبكة Wi-Fi';

  @override
  String get updateAvailable => 'يتوفر إصدار جديد';

  @override
  String get deletePackTitle => 'حذف الحزمة';

  @override
  String get deletePackBody => 'يمكنك تنزيلها من جديد متى شئت.';

  @override
  String get downloadNotSaved => 'تعذّر حفظ الملف';

  @override
  String get noNotesYet => 'لا توجد ملاحظات بعد';

  @override
  String get noSearchResults => 'لم نجد نتائج';

  @override
  String get noTafsirsYet => 'لا توجد تفاسير منزَّلة بعد';

  @override
  String get noRecitationsYet => 'لا توجد تلاوات منزَّلة بعد';

  @override
  String get queueEmpty => 'قائمة التشغيل فارغة';

  @override
  String get noteHint => 'اكتب ملاحظتك';

  @override
  String get noteSave => 'احفظ';

  @override
  String get noteDelete => 'احذف الملاحظة';

  @override
  String get shareSheetTitle => 'مشاركة الآية';

  @override
  String get addToQueue => 'أضف إلى قائمة التشغيل';

  @override
  String repeatCounter(String current, String total) {
    return 'التكرار $current من $total';
  }

  @override
  String get rangeFrom => 'من';

  @override
  String get rangeTo => 'إلى';

  @override
  String get repeatUnitAyah => 'الآية';

  @override
  String get repeatUnitRange => 'النطاق';

  @override
  String get userDataNotSaved =>
      'تعذّر فتح بيانات التطبيق، فلن تُحفظ تغييراتك في هذه الجلسة.';

  @override
  String searchPlaces(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits موضع',
      many: '$digits موضعًا',
      few: '$digits مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
      zero: 'لا مواضع',
    );
    return '$_temp0';
  }

  @override
  String minutesCount(int count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits دقيقة',
      many: '$digits دقيقة',
      few: '$digits دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String sourceVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String tafsirRange(String from, String to) {
    return 'من الآية $from إلى الآية $to';
  }

  @override
  String ayahsRangeShort(String from, String to) {
    return '$from–$to';
  }

  @override
  String tafsirCopyFormat(
    String passage,
    String title,
    String author,
    String surah,
    String ayahs,
    String source,
    String version,
  ) {
    return '$passage\n\n$title · $author\n[$surah: $ayahs]\n$source · الإصدار $version';
  }
}
