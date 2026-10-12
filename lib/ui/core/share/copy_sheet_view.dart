import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';

/// The copy sheet for the view model [create] makes. It closes once the
/// ayah is on the clipboard.
class CopySheetView extends StatefulWidget {
  const CopySheetView({required this.create, super.key});

  final CopySheetViewModel Function() create;

  @override
  State<CopySheetView> createState() => _CopySheetViewState();
}

class _CopySheetViewState extends State<CopySheetView> {
  late final CopySheetViewModel _viewModel = widget.create()
    ..copy.addListener(_onCopy);

  void _onCopy() {
    if (_viewModel.copy.completed) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_viewModel, _viewModel.copy]),
    builder: (context, _) => CopySheet(
      forms: _viewModel.forms,
      selected: _viewModel.selected,
      onSelected: _viewModel.select,
      onCopy: _viewModel.copy.running ? null : _viewModel.copy.execute,
    ),
  );
}
