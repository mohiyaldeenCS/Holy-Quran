// GENERATED CODE. DO NOT EDIT BY HAND.
// Generated from design/design-system/components/src/index.jsx, design/design-system/components/index.d.ts, tools/gen/project_icons/*.svg
// by `dart run tools/gen/bin/generate.dart` (see tools/gen/README.md).

import 'package:flutter/painting.dart';

/// The identity icons in the order of ICONS, then the project icons.
enum IconName {
  home,
  mushaf,
  listen,
  study,
  search,
  bookmark,
  download,
  night,
  settings,
  repeat,
  indexIcon,
  khatma,
  next,
  previous,
  more,
  alert,
  check,
  close,
  play,
  pause,
  mic,
  eye,
  sort,
  minus,
  plus,
  context,
  copy,
  delete,
  info,
  nextSurah,
  note,
  previousSurah,
  share,
  stop,
}

/// Filled icons are painted with a fill; all others with the
/// identity stroke.
bool isIconFilled(IconName name) => switch (name) {
  IconName.play || IconName.pause => true,
  _ => false,
};

/// The outline of [name] on the 24 by 24 icon grid.
Path buildIconPath(IconName name) => switch (name) {
  IconName.home =>
    Path()
      ..moveTo(4, 11.5)
      ..lineTo(12, 5)
      ..lineTo(20, 11.5)
      ..lineTo(20, 19)
      ..cubicTo(20, 19.5523, 19.5523, 20, 19, 20)
      ..lineTo(15, 20)
      ..lineTo(15, 15)
      ..lineTo(9, 15)
      ..lineTo(9, 20)
      ..lineTo(5, 20)
      ..cubicTo(4.4477, 20, 4, 19.5523, 4, 19)
      ..close(),
  IconName.mushaf =>
    Path()
      ..moveTo(12, 6.5)
      ..cubicTo(10, 5, 7, 4.6, 4.5, 5)
      ..lineTo(4.5, 18)
      ..cubicTo(7, 17.6, 10, 18, 12, 19.5)
      ..cubicTo(14, 18, 17, 17.6, 19.5, 18)
      ..lineTo(19.5, 5)
      ..cubicTo(17, 4.6, 14, 5, 12, 6.5)
      ..close()
      ..moveTo(12, 6.5)
      ..lineTo(12, 19.5),
  IconName.listen =>
    Path()
      ..moveTo(4, 14)
      ..lineTo(4, 12)
      ..cubicTo(4, 7.5817, 7.5817, 4, 12, 4)
      ..cubicTo(16.4183, 4, 20, 7.5817, 20, 12)
      ..lineTo(20, 14)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4, 14, 4, 6),
          Radius.circular(1.5),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(16, 14, 4, 6),
          Radius.circular(1.5),
        ),
      ),
  IconName.study =>
    Path()
      ..moveTo(12, 4)
      ..lineTo(20, 8)
      ..lineTo(12, 12)
      ..lineTo(4, 8)
      ..close()
      ..moveTo(4, 12)
      ..lineTo(12, 16)
      ..lineTo(20, 12)
      ..moveTo(4, 16)
      ..lineTo(12, 20)
      ..lineTo(20, 16),
  IconName.search =>
    Path()
      ..addOval(Rect.fromCircle(center: Offset(11, 11), radius: 6))
      ..moveTo(20, 20)
      ..lineTo(15.8, 15.8),
  IconName.bookmark =>
    Path()
      ..moveTo(7, 4)
      ..lineTo(17, 4)
      ..lineTo(17, 20)
      ..lineTo(12, 16.5)
      ..lineTo(7, 20)
      ..close(),
  IconName.download =>
    Path()
      ..moveTo(12, 4)
      ..lineTo(12, 15)
      ..moveTo(7.5, 11)
      ..lineTo(12, 15.5)
      ..lineTo(16.5, 11)
      ..moveTo(5, 19.5)
      ..lineTo(19, 19.5),
  IconName.night =>
    Path()
      ..moveTo(19.5, 14.5)
      ..cubicTo(16.6674, 15.3722, 13.5847, 14.6069, 11.4889, 12.5111)
      ..cubicTo(9.3931, 10.4153, 8.6278, 7.3326, 9.5, 4.5)
      ..cubicTo(5.8604, 5.6207, 3.5153, 9.1516, 3.8939, 12.941)
      ..cubicTo(4.2724, 16.7303, 7.2697, 19.7276, 11.059, 20.1061)
      ..cubicTo(14.8484, 20.4847, 18.3793, 18.1396, 19.5, 14.5)
      ..close(),
  IconName.settings =>
    Path()
      ..moveTo(5, 7)
      ..lineTo(14, 7)
      ..moveTo(18, 7)
      ..lineTo(19, 7)
      ..moveTo(5, 17)
      ..lineTo(6, 17)
      ..moveTo(10, 17)
      ..lineTo(19, 17)
      ..addOval(Rect.fromCircle(center: Offset(16, 7), radius: 2))
      ..addOval(Rect.fromCircle(center: Offset(8, 17), radius: 2)),
  IconName.repeat =>
    Path()
      ..moveTo(5, 11)
      ..lineTo(5, 9)
      ..cubicTo(5, 7.3431, 6.3431, 6, 8, 6)
      ..lineTo(18, 6)
      ..lineTo(15, 3)
      ..moveTo(19, 13)
      ..lineTo(19, 15)
      ..cubicTo(19, 16.6569, 17.6569, 18, 16, 18)
      ..lineTo(6, 18)
      ..lineTo(9, 21),
  IconName.indexIcon =>
    Path()
      ..moveTo(8, 6)
      ..lineTo(20, 6)
      ..moveTo(8, 12)
      ..lineTo(20, 12)
      ..moveTo(8, 18)
      ..lineTo(20, 18)
      ..moveTo(4, 6)
      ..lineTo(4.01, 6)
      ..moveTo(4, 12)
      ..lineTo(4.01, 12)
      ..moveTo(4, 18)
      ..lineTo(4.01, 18),
  IconName.khatma =>
    Path()
      ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 8))
      ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 3.5)),
  IconName.next =>
    Path()
      ..moveTo(15, 6)
      ..lineTo(9, 12)
      ..lineTo(15, 18),
  IconName.previous =>
    Path()
      ..moveTo(9, 6)
      ..lineTo(15, 12)
      ..lineTo(9, 18),
  IconName.more =>
    Path()
      ..addOval(Rect.fromCircle(center: Offset(5, 12), radius: 1.2))
      ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 1.2))
      ..addOval(Rect.fromCircle(center: Offset(19, 12), radius: 1.2)),
  IconName.alert =>
    Path()
      ..moveTo(12, 4)
      ..lineTo(21, 19.5)
      ..lineTo(3, 19.5)
      ..close()
      ..moveTo(12, 10)
      ..lineTo(12, 14)
      ..moveTo(12, 17)
      ..lineTo(12.01, 17),
  IconName.check =>
    Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7.5),
  IconName.close =>
    Path()
      ..moveTo(7, 7)
      ..lineTo(17, 17)
      ..moveTo(17, 7)
      ..lineTo(7, 17),
  IconName.play =>
    Path()
      ..moveTo(8, 5.5)
      ..lineTo(8, 18.5)
      ..lineTo(19, 12)
      ..close(),
  IconName.pause =>
    Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6.5, 5, 3.8, 14),
          Radius.circular(1),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(13.7, 5, 3.8, 14),
          Radius.circular(1),
        ),
      ),
  IconName.mic =>
    Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9, 3.5, 6, 11),
          Radius.circular(3),
        ),
      )
      ..moveTo(5.5, 11.5)
      ..cubicTo(5.5, 15.0899, 8.4101, 18, 12, 18)
      ..cubicTo(15.5899, 18, 18.5, 15.0899, 18.5, 11.5)
      ..moveTo(12, 18)
      ..lineTo(12, 21),
  IconName.eye =>
    Path()
      ..moveTo(2.5, 12)
      ..cubicTo(2.5, 12, 6, 5.5, 12, 5.5)
      ..cubicTo(18, 5.5, 21.5, 12, 21.5, 12)
      ..cubicTo(21.5, 12, 18, 18.5, 12, 18.5)
      ..cubicTo(6, 18.5, 2.5, 12, 2.5, 12)
      ..close()
      ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 3)),
  IconName.sort =>
    Path()
      ..moveTo(7, 5)
      ..lineTo(7, 19)
      ..moveTo(4, 8)
      ..lineTo(7, 5)
      ..lineTo(10, 8)
      ..moveTo(17, 19)
      ..lineTo(17, 5)
      ..moveTo(14, 16)
      ..lineTo(17, 19)
      ..lineTo(20, 16),
  IconName.minus =>
    Path()
      ..moveTo(6, 12)
      ..lineTo(18, 12),
  IconName.plus =>
    Path()
      ..moveTo(12, 6)
      ..lineTo(12, 18)
      ..moveTo(6, 12)
      ..lineTo(18, 12),
  IconName.context =>
    Path()
      ..moveTo(5, 6)
      ..lineTo(19, 6)
      ..moveTo(5, 10)
      ..lineTo(19, 10)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4, 13.5, 16, 5),
          Radius.circular(1.5),
        ),
      ),
  IconName.copy =>
    Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9, 9, 11, 11),
          Radius.circular(1.5),
        ),
      )
      ..moveTo(6, 15)
      ..lineTo(5.5, 15)
      ..cubicTo(4.6716, 15, 4, 14.3284, 4, 13.5)
      ..lineTo(4, 5.5)
      ..cubicTo(4, 4.6716, 4.6716, 4, 5.5, 4)
      ..lineTo(13.5, 4)
      ..cubicTo(14.3284, 4, 15, 4.6716, 15, 5.5)
      ..lineTo(15, 6),
  IconName.delete =>
    Path()
      ..moveTo(4.5, 7)
      ..lineTo(19.5, 7)
      ..moveTo(9.5, 7)
      ..lineTo(9.5, 5.5)
      ..cubicTo(9.5, 4.6716, 10.1716, 4, 11, 4)
      ..lineTo(13, 4)
      ..cubicTo(13.8284, 4, 14.5, 4.6716, 14.5, 5.5)
      ..lineTo(14.5, 7)
      ..moveTo(6.5, 7)
      ..lineTo(6.5, 18.5)
      ..cubicTo(6.5, 19.3284, 7.1716, 20, 8, 20)
      ..lineTo(16, 20)
      ..cubicTo(16.8284, 20, 17.5, 19.3284, 17.5, 18.5)
      ..lineTo(17.5, 7)
      ..moveTo(10, 11)
      ..lineTo(10, 16)
      ..moveTo(14, 11)
      ..lineTo(14, 16),
  IconName.info =>
    Path()
      ..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 8))
      ..moveTo(12, 11)
      ..lineTo(12, 16)
      ..moveTo(12, 8)
      ..lineTo(12.01, 8),
  IconName.nextSurah =>
    Path()
      ..moveTo(16.5, 6)
      ..lineTo(10.5, 12)
      ..lineTo(16.5, 18)
      ..moveTo(7.5, 6)
      ..lineTo(7.5, 18),
  IconName.note =>
    Path()
      ..moveTo(9.5, 4)
      ..lineTo(17.5, 4)
      ..cubicTo(18.3284, 4, 19, 4.6716, 19, 5.5)
      ..lineTo(19, 18.5)
      ..cubicTo(19, 19.3284, 18.3284, 20, 17.5, 20)
      ..lineTo(6.5, 20)
      ..cubicTo(5.6716, 20, 5, 19.3284, 5, 18.5)
      ..lineTo(5, 8.5)
      ..close()
      ..moveTo(9.5, 4)
      ..lineTo(9.5, 7)
      ..cubicTo(9.5, 7.8284, 8.8284, 8.5, 8, 8.5)
      ..lineTo(5, 8.5)
      ..moveTo(8.5, 12.5)
      ..lineTo(15.5, 12.5)
      ..moveTo(11, 16)
      ..lineTo(15.5, 16),
  IconName.previousSurah =>
    Path()
      ..moveTo(7.5, 6)
      ..lineTo(13.5, 12)
      ..lineTo(7.5, 18)
      ..moveTo(16.5, 6)
      ..lineTo(16.5, 18),
  IconName.share =>
    Path()
      ..moveTo(12, 14)
      ..lineTo(12, 4)
      ..moveTo(7.5, 8.5)
      ..lineTo(12, 4)
      ..lineTo(16.5, 8.5)
      ..moveTo(8, 11.5)
      ..lineTo(6.5, 11.5)
      ..cubicTo(5.6716, 11.5, 5, 12.1716, 5, 13)
      ..lineTo(5, 18)
      ..cubicTo(5, 18.8284, 5.6716, 19.5, 6.5, 19.5)
      ..lineTo(17.5, 19.5)
      ..cubicTo(18.3284, 19.5, 19, 18.8284, 19, 18)
      ..lineTo(19, 13)
      ..cubicTo(19, 12.1716, 18.3284, 11.5, 17.5, 11.5)
      ..lineTo(16, 11.5),
  IconName.stop =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, 12, 12),
        Radius.circular(1.5),
      ),
    ),
};

/// The open book of the mark on its 120 by 120 grid.
Path buildMarkBookPath() => Path()
  ..moveTo(58, 52)
  ..cubicTo(52, 47.5, 44, 47, 38.5, 49.5)
  ..lineTo(38.5, 72)
  ..cubicTo(44, 69.8, 52, 70.3, 58, 74.5)
  ..close()
  ..moveTo(62, 52)
  ..cubicTo(68, 47.5, 76, 47, 81.5, 49.5)
  ..lineTo(81.5, 72)
  ..cubicTo(76, 69.8, 68, 70.3, 62, 74.5)
  ..close();
