import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';

import 'margin_mark.dart';
import 'surah_text.dart';

/// How tall a row of margin marks is drawn (D-181): the tallest of its
/// marks, at the system text scale and boldness the screen draws them with.
/// Two are equal when they measure alike, so a plan is made again only when
/// one of those changes.
@immutable
final class MarginRowMeasure {
  const MarginRowMeasure(this.strings, this.scaler, {this.bold = false});

  MarginRowMeasure.of(BuildContext context)
    : this(
        AppLocalizations.of(context),
        MediaQuery.textScalerOf(context),
        bold: MediaQuery.boldTextOf(context),
      );

  final AppLocalizations strings;
  final TextScaler scaler;
  final bool bold;

  double heightOf(List<MarginMark> marks) => marks
      .map((mark) => MarginMarkView.heightOf(mark, strings, scaler, bold: bold))
      .reduce(math.max);

  @override
  bool operator ==(Object other) =>
      other is MarginRowMeasure &&
      identical(other.strings, strings) &&
      other.scaler == scaler &&
      other.bold == bold;

  @override
  int get hashCode => Object.hash(identityHashCode(strings), scaler, bold);
}
