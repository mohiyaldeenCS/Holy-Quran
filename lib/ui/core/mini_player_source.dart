import 'package:flutter/widgets.dart';

/// What the [TabShell] shows above its tab bar while something plays: the
/// shell is core and cannot import the listen feature, so the routing hands
/// it a source (ARCHITECTURE: features import core, never the reverse).
///
/// [build] returns the mini player, or null while there is nothing to show.
/// Listeners are told whenever the answer may have changed.
abstract interface class MiniPlayerSource implements Listenable {
  Widget? build(BuildContext context);

  void dispose();
}

/// Creates the source over the providers above [context], or null when the
/// app has none to offer (no verified base pack).
typedef MiniPlayerSourceFactory =
    MiniPlayerSource? Function(BuildContext context);
