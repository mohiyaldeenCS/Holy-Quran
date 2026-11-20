import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/test_copy.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';
import 'package:holyquran/ui/features/start/view_models/app_start_view_model.dart';
import 'package:holyquran/ui/features/start/views/start_failed_screen.dart';
import 'package:provider/provider.dart';

void main() {
  // Areas start before runApp and may call plugins at once.
  WidgetsFlutterBinding.ensureInitialized();
  // Read first: a release build given the test copy's defines stops here.
  final unapprovedCopy = testCopy != null;
  runApp(
    AppStart(
      // Listened to at once: a step that fails before the first frame would
      // otherwise be an uncaught error, and the splash would stay.
      start: AppStartViewModel(startDependencies()),
      unapprovedCopy: unapprovedCopy,
    ),
  );
}

/// Shows the identity's splash at once, and the app once [start]'s
/// dependencies are built (M1.1), or the failed start if building them throws.
/// It disposes [start].
class AppStart extends StatefulWidget {
  const AppStart({required this.start, this.unapprovedCopy = false, super.key});

  final AppStartViewModel start;

  /// Whether this build is the unapproved test copy (D-163, D-164).
  final bool unapprovedCopy;

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  late final AppStartViewModel _start = widget.start;
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _start.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _start,
    builder: (context, _) => switch (_start.state) {
      StartPending() => Localizations(
        locale: const Locale('ar'),
        delegates: AppLocalizations.localizationsDelegates,
        child: const Splash(),
      ),
      StartFailed(:final theme) => StartFailedScreen(theme: theme),
      StartReady(:final providers) => MultiProvider(
        providers: providers,
        child: QuranApp(router: _router, unapprovedCopy: widget.unapprovedCopy),
      ),
    },
  );
}
