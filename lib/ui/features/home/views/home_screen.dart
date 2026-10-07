import 'package:flutter/material.dart';

import 'package:holyquran/l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(AppLocalizations.of(context).tabHome));
}
