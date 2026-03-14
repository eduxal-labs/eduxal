import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'client.dart';

import 'ui/screens/splash/splash_screen.dart';
import 'ui/theme/app_theme.dart';

/// Entry point.
///
/// Initialization order:
/// 1. [WidgetsFlutterBinding.ensureInitialized] — required before any
///    async platform work (path_provider, SQLite).
/// 2. [initializeClient] — opens the Drift database singleton ([db]) and
///    creates the [Client], then restores the active session from the local
///    [Accounts] table (no network call unless the access token needs
///    refreshing).
/// 3. [runApp] — hands off to the UI layer.
///
/// The entire app runs inside [runZonedGuarded] so that unhandled async
/// errors from the `http2` transport layer (e.g. assertion failures during
/// connection teardown when the gRPC server is unreachable) are logged
/// instead of crashing the isolate.
void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeClient();
      runApp(const MyApp());
    },
    (error, stack) {
      // Log but do not crash. The most common source of these is the http2
      // package's ConnectionMessageQueueIn.onTerminated assertion that fires
      // when a gRPC connection attempt fails and the transport tears down.
      dev.log(
        'Uncaught async error (suppressed): $error',
        name: 'Main',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _SyncLifecycleObserver _lifecycleObserver;
  late final StreamSubscription<dynamic> _themeSub;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _SyncLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    // Listen to account changes ONLY to update the theme.
    // We deliberately do NOT rebuild MaterialApp on every emission —
    // doing so resets the navigator stack and sends the user back to
    // SplashScreen every time the active account row changes.
    _themeSub = accountsDao.watchActiveAccount().listen((auth) {
      final resolved = auth?.theme != null
          ? AppTheme.resolveThemeMode(auth!.theme)
          : ThemeMode.system;
      if (resolved != _themeMode) {
        setState(() => _themeMode = resolved);
      }
    });
  }

  @override
  void dispose() {
    _themeSub.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduXal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: const SplashScreen(),
    );
  }
}

/// Observes app lifecycle transitions and revives the sync engine when the
/// app returns from background.
///
/// On mobile platforms the OS suspends Dart isolates when the app is
/// backgrounded. This kills all active timers (including the sync engine's
/// periodic push timer and reconnect backoff timer) and tears down gRPC
/// streams. Without an explicit kick on resume, sync would remain dead until
/// the next cold start.
///
/// [_SyncLifecycleObserver] solves this by calling [SyncEngine.revive] every
/// time the app transitions to [AppLifecycleState.resumed]. That method is a
/// no-op if sync is already healthy, so there is no cost for rapid
/// background/foreground cycles.
class _SyncLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Lifecycle] App resumed — reviving sync engine');
      sync.revive();
    }
  }
}
