import 'package:flutter/widgets.dart';

/// [child] as one node for a screen reader, which hears [label] and [value]
/// and nothing of the child; with [onTap] the node is a button. The child's
/// own semantics are dropped, so [label] names what it is for.
Widget labelled({
  required String label,
  required Widget child,
  String? value,
  VoidCallback? onTap,
}) => Semantics(
  container: true,
  button: onTap != null,
  label: label,
  value: value,
  onTap: onTap,
  excludeSemantics: true,
  child: child,
);
