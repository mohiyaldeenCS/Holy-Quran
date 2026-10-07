import 'package:flutter/material.dart';

import 'package:holyquran/l10n/app_localizations.dart';

class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(AppLocalizations.of(context).tabListen));
}
