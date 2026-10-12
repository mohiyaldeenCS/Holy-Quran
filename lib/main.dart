import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  // Areas start before runApp and may call plugins at once.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStart(dependencies: buildDependencies()));
}

/// Shows the identity's splash at once, and the app once [dependencies] are
/// built (M1.1).
class AppStart extends StatefulWidget {
  const AppStart({required this.dependencies, super.key});

  final Future<List<SingleChildWidget>> dependencies;

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  List<SingleChildWidget>? _providers;
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    widget.dependencies.then(
      (providers) {
        if (mounted) setState(() => _providers = providers);
      },
      // The splash stays: there is no wording for a failed start yet.
      onError: (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'start'),
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    if (providers == null) {
      return Localizations(
        locale: const Locale('ar'),
        delegates: AppLocalizations.localizationsDelegates,
        child: const Splash(),
      );
    }
    final app = QuranApp(router: _router);
    // MultiProvider refuses an empty list.
    return providers.isEmpty
        ? app
        : MultiProvider(providers: providers, child: app);
  }
}
