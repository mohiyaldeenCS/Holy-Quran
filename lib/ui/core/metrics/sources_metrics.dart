import 'package:flutter/painting.dart';

/// The sources and licences screen is not drawn. Its rows follow
/// `.qk-resource` of the resource manager (bundle.css); its header and column
/// are the settings screen's (`settings_metrics.dart`).
abstract final class SourcesMetrics {
  // .qk-resource: `padding: 14px 0`; its `border-bottom: 1px solid var(--line)`
  // is the default width of a BorderSide.
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(vertical: 14);

  // .qk-resource-main: `gap: 6px`.
  static const double rowGap = 6;
}
