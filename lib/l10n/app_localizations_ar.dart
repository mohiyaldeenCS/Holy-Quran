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
}
