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
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeClient();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: accountsDao.watchActiveAccount(),
      builder: (context, snapshot) {
        final themeMode = snapshot.data?.theme != null
            ? AppTheme.resolveThemeMode(snapshot.data!.theme)
            : ThemeMode.system;

        return MaterialApp(
          title: 'EduXal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
