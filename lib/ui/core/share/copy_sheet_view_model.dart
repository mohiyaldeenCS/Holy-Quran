import 'package:flutter/foundation.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

/// Puts text on the clipboard; the composition root gives the clipboard
/// service's.
typedef CopyToClipboard = Future<Result<void>> Function(String text);

/// The copy sheet of the ayah at [address] (SH-01): the form chosen, and
/// [copy], which reads the ayah from the pack and puts it on the clipboard.
final class CopySheetViewModel extends ChangeNotifier {
  CopySheetViewModel({
    required this.address,
    required AyahCopyText copyText,
    required this._copyToClipboard,
  }) : _copyText = copyText,
       forms = copyText.forms {
    _selected = forms.contains(CopyForm.withSurahAndNumber)
        ? CopyForm.withSurahAndNumber
        : forms.first;
    copy = Command0(_copy);
  }

  final QuranAddress address;
  final AyahCopyText _copyText;
  final CopyToClipboard _copyToClipboard;

  /// The forms that can be copied.
  final List<CopyForm> forms;

  late final Command0<void> copy;

  // The Share board draws the full form selected.
  late CopyForm _selected;

  CopyForm get selected => _selected;

  void select(CopyForm form) {
    if (!forms.contains(form) || form == _selected) return;
    _selected = form;
    notifyListeners();
  }

  Future<Result<void>> _copy() async =>
      switch (await _copyText.compose(address, _selected)) {
        Ok(:final value) => _copyToClipboard(value),
        Failure(:final error) => Failure(error),
      };

  /// A copy still running when the sheet closes notifies once more as it
  /// ends, so it is left to the collector rather than disposed.
  @override
  void dispose() {
    if (!copy.running) copy.dispose();
    super.dispose();
  }
}
