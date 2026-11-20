import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

/// The system bars over [child] on the theme's ground, with icons that stay
/// legible on it.
class SystemBars extends StatelessWidget {
  const SystemBars({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final icons = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: brightness,
        statusBarIconBrightness: icons,
        systemNavigationBarColor: context.colors.ground,
        systemNavigationBarIconBrightness: icons,
      ),
      child: child,
    );
  }
}
