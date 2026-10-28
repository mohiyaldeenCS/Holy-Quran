import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/widgets/progress_bar.dart';

/// The storage bar of PRD §7.7 («شريط المساحة»): the space one category of
/// resources uses, as a [ProgressBar] filled by [usedBytes] out of
/// [totalBytes]. A screen reader reads [label] with the share as a
/// percentage. A total of zero draws an empty track.
class StorageBar extends StatelessWidget {
  const StorageBar({
    required this.label,
    required this.usedBytes,
    required this.totalBytes,
    super.key,
  }) : assert(usedBytes >= 0 && totalBytes >= 0);

  final String label;
  final int usedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) => ProgressBar(
    value: totalBytes == 0 ? 0 : usedBytes / totalBytes,
    label: label,
  );
}
