import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';

import 'margin_mark.dart';

/// Builds [builder] with the reader's start gutter (D-181): the width the
/// margin marks take at the system text scale and boldness, measured again
/// only when those or the strings change, since line breaking follows it.
final class MarginGutter extends StatefulWidget {
  const MarginGutter({required this.builder, super.key});

  final Widget Function(BuildContext context, double startGutter) builder;

  @override
  State<MarginGutter> createState() => _MarginGutterState();
}

final class _MarginGutterState extends State<MarginGutter> {
  TextScaler? _scaler;
  bool? _bold;
  AppLocalizations? _strings;
  double _gutter = 0;

  double _measure(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final bold = MediaQuery.boldTextOf(context);
    final strings = AppLocalizations.of(context);
    if (scaler != _scaler || bold != _bold || !identical(strings, _strings)) {
      _scaler = scaler;
      _bold = bold;
      _strings = strings;
      _gutter = ReaderScreenMetrics.startGutter(
        MarginMarkView.widest(strings, scaler, bold: bold),
      );
    }
    return _gutter;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _measure(context));
}
