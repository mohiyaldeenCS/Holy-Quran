import 'package:flutter/material.dart';

import 'package:holyquran/ui/core/widgets/sheet_route.dart';

/// A sheet route's page, drawn by [sheetRoute].
final class SheetPage<T> extends Page<T> {
  const SheetPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => sheetRoute<T>(
    context,
    settings: this,
    // The route's settings follow a rebuilt page, so its child does too.
    builder: (context) =>
        (ModalRoute.settingsOf(context)! as SheetPage<T>).child,
  );
}
