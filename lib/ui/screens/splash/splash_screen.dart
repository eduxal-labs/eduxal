import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../client.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

/// First frame the user sees on cold start.
///
/// WhatsApp-inspired: the brand's primary colour fills the entire screen with
/// a centred white icon and wordmark. Feels confident, warm, and intentional.
///
/// Reads auth state from the local DB (fast — no network call) and routes:
/// - `null` → [LoginScreen] (no active session)
/// - [Authenticated] → [HomeScreen]
///
/// Displays for a minimum of 600 ms so it never flashes on fast devices.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    // Entrance animation: icon scales up gently, text fades in after.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _resolveAuthAndNavigate();
  }

  Future<void> _resolveAuthAndNavigate() async {
    // Run the minimum display timer and auth check in parallel.
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 600)),
      client.active(),
    ]);

    if (!mounted) return;

    final authenticated = results[1];
    final destination = authenticated == null
        ? const LoginScreen()
        : const HomeScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make the status bar icons white while the splash is showing.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.brandIndigo,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon — scales in gently.
                Transform.scale(
                  scale: _iconScale.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Wordmark — fades in with a slight delay.
                Opacity(
                  opacity: _textFade.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'EduXal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'School management',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
