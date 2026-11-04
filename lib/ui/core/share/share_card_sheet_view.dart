import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/share/share_card_renderer.dart';
import 'package:holyquran/ui/core/share/share_card_sheet.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

/// The share sheet for the view model [create] makes. It fits the ayah on
/// the card of each design as it is chosen (SH-03), and paints the card it
/// shows when the user shares it.
///
/// The Share board draws no choice of size, so the size follows the fit
/// rule: 4:5, the board's size for posts, shrinking to 22, then 9:16.
class ShareCardSheetView extends StatefulWidget {
  const ShareCardSheetView({
    required this.create,
    required this.onCopy,
    super.key,
  });

  final ShareCardSheetViewModel Function() create;

  /// Opens the copy sheet, for an ayah too long for any card.
  final VoidCallback onCopy;

  @override
  State<ShareCardSheetView> createState() => _ShareCardSheetViewState();
}

class _ShareCardSheetViewState extends State<ShareCardSheetView> {
  late final ShareCardSheetViewModel _viewModel = widget.create()
    ..addListener(_fit)
    ..load.addListener(_onLoad);
  late final Listenable _changes = Listenable.merge([
    _viewModel,
    _viewModel.share,
  ]);
  final _fits = <ShareCardDesign, ShareCardFit>{};

  // There is no wording for a failed read yet, so the sheet closes rather
  // than stay empty. One already closing is no longer current, and is left
  // to close.
  void _onLoad() {
    if (_viewModel.load.error && (ModalRoute.isCurrentOf(context) ?? false)) {
      Navigator.of(context).maybePop();
    }
  }

  /// Fits the chosen design once the ayah is read; outside build, as fitting
  /// lays the card out in a tree of its own.
  void _fit() {
    final card = _card(shareCardFontSize);
    if (card == null || _fits.containsKey(card.design)) return;
    final fits = ShareCardRenderer(context).fitTest(card);
    setState(() {
      _fits[card.design] = fitShareCard(_startRatio, fits);
    });
  }

  ShareCard? _card(double fontSize, [ShareCardRatio ratio = _startRatio]) {
    final ayah = _viewModel.ayah;
    final surahName = _viewModel.surahName;
    if (ayah == null || surahName == null) return null;
    return ShareCard(
      ayah: ayah,
      surahName: surahName,
      ayahNumber: _viewModel.address.ayah,
      ayahFontSize: fontSize,
      design: _viewModel.design,
      ratio: ratio,
    );
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_fit)
      ..load.removeListener(_onLoad)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      final fit = _fits[_viewModel.design];
      if (fit == null) return const SizedBox.shrink();
      final card = switch (fit) {
        ShareCardFits(:final ratio, :final fontSize) => _card(fontSize, ratio),
        ShareCardTooLong() => null,
      };
      final share = _viewModel.share;
      return ShareCardSheet(
        design: _viewModel.design,
        onDesignSelected: _viewModel.selectDesign,
        card: card,
        onShare: card == null || share.running
            ? null
            : () => share.execute(() => ShareCardRenderer(context).png(card)),
        onCopy: widget.onCopy,
      );
    },
  );
}

// The size the fit starts from: the drawn card (Share.dc.html) and the
// board's «عمودي ٤:٥ للمنشورات».
const _startRatio = ShareCardRatio.portrait;
