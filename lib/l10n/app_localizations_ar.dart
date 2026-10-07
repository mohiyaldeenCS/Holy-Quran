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
  String surahHeaderName(String name) {
    return 'سورة $name';
  }

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
}
