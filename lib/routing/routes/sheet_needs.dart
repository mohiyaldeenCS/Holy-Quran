import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shows [child] once [available] holds, and otherwise closes the sheet at
/// once. A sheet reads objects the base pack's areas provide, and without a
/// verified base pack they are not provided; reading them would throw.
class SheetNeeds extends StatelessWidget {
  const SheetNeeds({required this.available, required this.child, super.key});

  /// Whether everything [child] reads is provided. It reads with nullable
  /// types, which return null where a plain read would throw.
  final bool Function(BuildContext context) available;

  /// Not built until [available] holds.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      available(context) ? child : const _Close();
}

class _Close extends StatefulWidget {
  const _Close();

  @override
  State<_Close> createState() => _CloseState();
}

class _CloseState extends State<_Close> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only this sheet closes, never a route pushed over it meanwhile.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
