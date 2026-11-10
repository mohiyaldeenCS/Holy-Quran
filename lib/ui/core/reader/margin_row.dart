import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';

import 'margin_mark.dart';
import 'surah_text.dart';

/// How margin marks are measured for their rows (D-181, D-183): each mark's
/// size at the system text scale and boldness the screen draws them with.
/// Two are equal when they measure alike, so a plan is made again only when
/// one of those changes. A mark is measured once; a pinch step, which plans
/// again with an equal measure kept, measures nothing.
final class MarginRowMeasure {
  MarginRowMeasure(this.strings, this.scaler, {this.bold = false});

  MarginRowMeasure.of(BuildContext context)
    : this(
        AppLocalizations.of(context),
        MediaQuery.textScalerOf(context),
        bold: MediaQuery.boldTextOf(context),
      );

  final AppLocalizations strings;
  final TextScaler scaler;
  final bool bold;

  /// By what a mark's drawing depends on: two sajdas look alike.
  final _sizes = <(MarginMarkKind, int?, int?, int?), Size>{};

  /// How many different marks have been measured.
  @visibleForTesting
  int get measured => _sizes.length;

  Size sizeOf(MarginMark mark) => _sizes.putIfAbsent((
    mark.kind,
    mark.hizb,
    mark.juz,
    mark.quarter,
  ), () => MarginMarkView.sizeOf(mark, strings, scaler, bold: bold));

  double widthOf(MarginMark mark) => sizeOf(mark).width;

  /// How tall a row of [marks] is drawn: the tallest of them.
  double heightOf(List<MarginMark> marks) =>
      marks.map((mark) => sizeOf(mark).height).reduce(math.max);

  @override
  bool operator ==(Object other) =>
      other is MarginRowMeasure &&
      identical(other.strings, strings) &&
      other.scaler == scaler &&
      other.bold == bold;

  @override
  int get hashCode => Object.hash(identityHashCode(strings), scaler, bold);
}
