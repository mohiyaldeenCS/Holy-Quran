import 'package:flutter/foundation.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

/// Puts text on the clipboard; the composition root gives the clipboard
/// service's.
typedef CopyToClipboard = Future<Result<void>> Function(String text);

/// The copy sheet of the ayah at [address] (SH-01): the form chosen, the
/// preview of each form, which [load] reads from the pack, and [copy], which
/// reads the ayah from the pack again and puts it on the clipboard.
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
    load = Command0(_load)..execute();
    copy = Command0(_copy);
  }

  final QuranAddress address;
  final AyahCopyText _copyText;
  final CopyToClipboard _copyToClipboard;

  /// The forms that can be copied.
  final List<CopyForm> forms;

  late final Command0<void> load;
  late final Command0<void> copy;

  // The Share board draws the full form selected.
  late CopyForm _selected;
  final _previews = <CopyForm, CopyPreview>{};
  var _disposed = false;

  CopyForm get selected => _selected;

  /// What [selected] copies, once [load] has read it.
  CopyPreview? get preview => _previews[_selected];

  void select(CopyForm form) {
    if (!forms.contains(form) || form == _selected) return;
    _selected = form;
    notifyListeners();
  }

  // Every form at once, so that a choice shows its preview without a wait.
  Future<Result<void>> _load() async {
    for (final form in forms) {
      switch (await _copyText.preview(address, form)) {
        case Ok(:final value):
          _previews[form] = value;
        case Failure(:final error):
          _previews.clear();
          return Failure(error);
      }
    }
    if (!_disposed) notifyListeners();
    return const Ok(null);
  }

  Future<Result<void>> _copy() async =>
      switch (await _copyText.compose(address, _selected)) {
        Ok(:final value) => _copyToClipboard(value),
        Failure(:final error) => Failure(error),
      };

  /// A command still running when the sheet closes notifies once more as it
  /// ends, so it is left to the collector rather than disposed.
  @override
  void dispose() {
    _disposed = true;
    for (final command in [load, copy]) {
      if (!command.running) command.dispose();
    }
    super.dispose();
  }
}
