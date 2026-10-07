import 'package:flutter/animation.dart';

// Not in tokens.json: the three durations and the easing (gradual, no bounce)
// are stated in design/design-system/README.md, section on spacing, radii,
// elevation and motion, and in the motion card of
// design/identity-boards/System.dc.html.
const Duration motionFast = Duration(milliseconds: 120);
const Duration motionNormal = Duration(milliseconds: 200);
const Duration motionSlow = Duration(milliseconds: 320);
const Curve motionCurve = Curves.easeOut;
