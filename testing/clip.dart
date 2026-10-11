import 'package:flutter/rendering.dart';

/// The part of [box] that its ancestors up to [within] let paint, in global
/// coordinates, by the clips they declare.
Rect shownRect(RenderBox box, RenderObject within) {
  var shown = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  for (RenderObject child = box; child != within; child = child.parent!) {
    final parent = child.parent!;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      shown = shown.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
  }
  return shown;
}

/// The clip that cuts [box] at [height] across its width, in [within]'s
/// coordinates, where a `paints` matcher on [within] records it.
Rect cutClip(RenderBox box, RenderObject within, double height) =>
    MatrixUtils.transformPoint(box.getTransformTo(within), Offset.zero) &
    Size(box.size.width, height);
