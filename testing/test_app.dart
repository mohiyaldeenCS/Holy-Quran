import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_app_settings_repository.dart';

/// [QuranApp] over [router] under [settings], or under fresh settings on the
/// defaults when none are given.
Widget testApp(GoRouter router, {AppSettingsRepository? settings}) =>
    ChangeNotifierProvider<AppSettingsRepository>.value(
      value: settings ?? FakeAppSettingsRepository(),
      child: QuranApp(router: router),
    );
