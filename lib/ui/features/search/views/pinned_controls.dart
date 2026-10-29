import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/metrics/search_metrics.dart';

/// The search screen's layout: the board keeps the field, the chips and the
/// summary fixed and scrolls only the results. When those [controls] would
/// take more than [SearchMetrics.pinnedShare] of the height, as they do at a
/// large text size, the controls scroll with the [results] instead, so that
/// the results keep room. The controls are measured after they are laid out,
/// and the one that moves them keeps their state.
class PinnedControls extends StatefulWidget {
  const PinnedControls({
    required this.controls,
    required this.results,
    super.key,
  });

  final Widget controls;

  /// The slivers under the controls.
  final List<Widget> results;

  @override
  State<PinnedControls> createState() => _PinnedControlsState();
}

class _PinnedControlsState extends State<PinnedControls> {
  final _controlsKey = GlobalKey();
  bool _together = false;

  void _measure(double limit) {
    if (!mounted) return;
    final height = _controlsKey.currentContext?.size?.height;
    if (height == null) return;
    final together = height > limit;
    if (together != _together) setState(() => _together = together);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final limit = constraints.maxHeight * SearchMetrics.pinnedShare;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(limit));
      final controls = Padding(
        padding: SearchMetrics.controls,
        child: KeyedSubtree(key: _controlsKey, child: widget.controls),
      );
      if (_together) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: controls),
            ...widget.results,
          ],
        );
      }
      // Capped, so that controls too tall for the pinned share scroll in it
      // for the one frame before they are measured and moved.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: limit),
            child: SingleChildScrollView(child: controls),
          ),
          Expanded(child: CustomScrollView(slivers: widget.results)),
        ],
      );
    },
  );
}
