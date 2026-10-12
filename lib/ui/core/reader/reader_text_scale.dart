import 'package:flutter/widgets.dart';

/// The surah-mode text sizes (`RD-07`: 80% to 200%): S7's eight steps,
/// adopted with the owner's question M0.4-13 by D-097.
const List<double> readerTextSteps = [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

/// The index of the 100% step, where a reader starts.
final int defaultReaderTextStep = readerTextSteps.indexOf(1);

/// The index of the step nearest to [factor], for a pinch that ends between
/// steps.
int nearestReaderTextStep(double factor) {
  var best = 0;
  for (var k = 1; k < readerTextSteps.length; k++) {
    if ((readerTextSteps[k] - factor).abs() <
        (readerTextSteps[best] - factor).abs()) {
      best = k;
    }
  }
  return best;
}

/// The system text scale with a reader step on top: the step magnifies what
/// the system would show, text and markers alike, so their proportions stay
/// those of the system's scaling.
final class ReaderTextScaler extends TextScaler {
  const ReaderTextScaler(this.system, this.step);

  final TextScaler system;
  final double step;

  @override
  double scale(double fontSize) => step * system.scale(fontSize);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => step * system.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is ReaderTextScaler && other.system == system && other.step == step;

  @override
  int get hashCode => Object.hash(system, step);
}
