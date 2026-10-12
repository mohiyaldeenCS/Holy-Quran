import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

import 's1/measure/process_age.dart';
import 's1/s1_screen.dart';
import 's3/s3_screen.dart';
import 's3/spike_audio_handler.dart';
import 's4/s4_screen.dart';
import 's4/widget_bridge.dart';
import 's5/s5_screen.dart';

// The profile spike APK (D-069):
// flutter build apk --profile -t spike/main.dart --dart-define=...

/// The launcher starts without S3 if the media service is not up by then.
const _audioInitLimit = Duration(seconds: 10);

Future<void> main() async {
  final ages = <String, Duration?>{'mainStart': processAge()};
  WidgetsFlutterBinding.ensureInitialized();
  WidgetBuilder? s3Screen;
  String? s3Unavailable;
  try {
    final audio = await initSpikeAudio().timeout(_audioInitLimit);
    s3Screen = (_) => S3Screen(audio: audio);
  } on Object catch (e) {
    s3Unavailable = 'S3 unavailable: ${e.runtimeType}';
  }
  ages['audioReady'] = processAge();
  ColdStartArm? arm;
  try {
    arm = await readColdStartArm(await s1Storage());
  } on Object {
    // An unreadable marker opens the launcher; S1 can arm again.
  }
  ages['markerRead'] = processAge();
  runApp(
    SpikeRoot(
      s3Screen: s3Screen,
      s3Unavailable: s3Unavailable,
      coldStart: arm == null ? null : ColdStartLaunch(arm: arm, ages: ages),
    ),
  );
}

/// The launcher, or the app once "App" is chosen: the app then replaces the
/// launcher as the root, exactly as `lib/main.dart` runs it.
class SpikeRoot extends StatefulWidget {
  const SpikeRoot({
    required this.s3Screen,
    this.s3Unavailable,
    this.coldStart,
    this.s1Environment = S1Environment.device,
    this.s4Environment = S4Environment.device,
    super.key,
  });

  /// Null when the media service did not start; the S3 entry then shows
  /// [s3Unavailable] and does not open.
  final WidgetBuilder? s3Screen;
  final String? s3Unavailable;

  /// Set when a cold start is armed; the launcher then opens straight on
  /// the S1 cold-start measurement.
  final ColdStartLaunch? coldStart;
  final S1Environment s1Environment;

  /// Its bridge also carries the home-screen widget's taps, which open S4.
  final S4Environment s4Environment;

  @override
  State<SpikeRoot> createState() => _SpikeRootState();
}

class _SpikeRootState extends State<SpikeRoot> {
  final _navigator = GlobalKey<NavigatorState>();
  GoRouter? _router;
  StreamSubscription<QuranAddress?>? _taps;
  AppLifecycleListener? _lifecycle;
  WidgetBridge? _bridge;
  bool _detached = false;

  @override
  void initState() {
    super.initState();
    // An armed S1 cold start is measured as part 1 measured it, with no
    // widget plugin calls beside it.
    if (widget.coldStart == null) unawaited(_listenToWidget());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    unawaited(_taps?.cancel());
    super.dispose();
  }

  /// A tap on the home-screen widget opens S4 on its ayah (WG-02): taps
  /// while the app runs from the stream, and the tap that started the app
  /// or, when the activity was closed and the engine lived on (the audio
  /// service keeps it), the tap that started the new activity from the
  /// bridge. Flutter's own deep linking is off (AndroidManifest.xml), so the
  /// link never reaches the navigator as a route.
  Future<void> _listenToWidget() async {
    try {
      final bridge = await widget.s4Environment.bridge();
      if (!mounted) return;
      _bridge = bridge;
      _taps = bridge.taps.listen(
        (address) => _openLink(address, WidgetLaunch.warm),
        onError: (Object e) => debugPrint('S4 widget taps: ${e.runtimeType}'),
      );
      _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
      _openLink(await bridge.launchAddress(), WidgetLaunch.cold);
    } on Object catch (e) {
      // Without the plugin the launcher still opens; S4 shows the error.
      debugPrint('S4 widget link not started: ${e.runtimeType}');
    }
  }

  Future<void> _onLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) _detached = true;
    if (state != AppLifecycleState.resumed || !_detached) return;
    _detached = false;
    try {
      _openLink(await _bridge?.launchAddress(), WidgetLaunch.reattached);
    } on Object catch (e) {
      debugPrint('S4 widget link not read: ${e.runtimeType}');
    }
  }

  /// Ignores a link that names no ayah, and every link once the app has
  /// replaced the launcher.
  void _openLink(QuranAddress? address, WidgetLaunch launch) {
    if (address == null || !mounted || _router != null) return;
    final navigator = _navigator.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openLink(address, launch),
      );
      return;
    }
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => S4Screen(
            environment: widget.s4Environment,
            openedBy: (address: address, launch: launch),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_router case final router?) return QuranApp(router: router);
    final coldStart = widget.coldStart;
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Spikes',
      theme: buildAppTheme(ReadingTheme.paper),
      debugShowCheckedModeBanner: false,
      initialRoute: coldStart == null ? '/' : '/cold-start',
      onGenerateRoute: (settings) => switch (settings.name) {
        '/' => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SpikeLauncher(
            onOpenApp: () => setState(() => _router = createRouter()),
            s3Screen: widget.s3Screen,
            s3Unavailable: widget.s3Unavailable,
            s1Environment: widget.s1Environment,
            s4Environment: widget.s4Environment,
          ),
        ),
        '/cold-start' when coldStart != null => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => S1ColdStartScreen(
            launch: coldStart,
            environment: widget.s1Environment,
          ),
        ),
        _ => null,
      },
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.ltr, child: child!),
    );
  }
}

class SpikeLauncher extends StatelessWidget {
  const SpikeLauncher({
    required this.onOpenApp,
    required this.s3Screen,
    required this.s1Environment,
    required this.s4Environment,
    this.s3Unavailable,
    super.key,
  });

  final VoidCallback onOpenApp;
  final WidgetBuilder? s3Screen;
  final String? s3Unavailable;
  final S1Environment s1Environment;
  final S4Environment s4Environment;

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Spikes')),
    body: ListView(
      children: [
        ListTile(
          title: const Text('App'),
          subtitle: const Text(
            'Replaces this launcher until the app is closed',
          ),
          onTap: onOpenApp,
        ),
        ListTile(
          title: const Text('Component gallery'),
          // The app's /gallery route exists in debug builds only.
          onTap: () => _push(
            context,
            (context) => Localizations.override(
              context: context,
              locale: const Locale('ar'),
              delegates: AppLocalizations.localizationsDelegates,
              child: const GalleryScreen(),
            ),
          ),
        ),
        ListTile(
          title: const Text('S1 surah rendering'),
          onTap: () =>
              _push(context, (_) => S1Screen(environment: s1Environment)),
        ),
        // The device session's order: S1, S7, S4, S3, S5. S7's entry goes
        // here, between S1 and S4.
        ListTile(
          title: const Text('S4 home-screen widget'),
          onTap: () =>
              _push(context, (_) => S4Screen(environment: s4Environment)),
        ),
        ListTile(
          title: const Text('S3 background audio'),
          subtitle: s3Screen == null
              ? Text(s3Unavailable ?? 'S3 unavailable')
              : null,
          enabled: s3Screen != null,
          onTap: switch (s3Screen) {
            final screen? => () => _push(context, screen),
            null => null,
          },
        ),
        ListTile(
          title: const Text('S5 downloads'),
          onTap: () => _push(context, (_) => const S5Screen()),
        ),
      ],
    ),
  );
}
