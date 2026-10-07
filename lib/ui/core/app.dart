import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';

class QuranApp extends StatelessWidget {
  const QuranApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    debugShowCheckedModeBanner: false,
  );
}
