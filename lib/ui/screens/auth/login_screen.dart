import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../client.dart';
import '../../../core/extensions.dart';
import '../../../core/grpc_errors.dart';
import '../../../models/result.dart';
import '../../theme/app_theme.dart';
import 'otp_screen.dart';

/// Phone number entry screen — the first step of the auth flow.
///
/// WhatsApp-inspired layout:
/// - Top illustration/icon area with brand colour
/// - Warm, readable sentence-case copy — no uppercase letter-spaced headings
/// - Rounded, borderless filled input (WhatsApp style)
/// - Full-width green CTA button, generous height
/// - On desktop: centred max-width card
/// - On mobile: full-bleed, content vertically centred
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submission
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLoading) return;

    final normalised = _phoneController.text.toKenyanPhone();

    if (normalised == null) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await client.authentication.login(normalised);

    if (!mounted) return;

    setState(() => _isLoading = false);

    switch (result) {
      case Ok(value: final verification):
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                OtpScreen(verificationId: verification.id, phone: normalised),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      case Err(error: final error):
        setState(() {
          _errorMessage = error.toFriendlyMessage();
        });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > AppTheme.kMobileBreakpoint;

    final body = FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: _buildContent(theme, cs),
      ),
    );

    // Desktop: centred card with constrained width.
    if (isDesktop) {
      return Scaffold(
        backgroundColor: cs.surfaceContainer,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: cs.brightness == Brightness.light ? 1 : 0,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 48,
                ),
                child: body,
              ),
            ),
          ),
        ),
      );
    }

    // Mobile: full-bleed, vertically centred.
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: body,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent(ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Illustration area ────────────────────────────────────────────
        _buildIllustration(cs),

        const SizedBox(height: 40),

        // ── Welcome copy ────────────────────────────────────────────────
        _buildWelcomeCopy(theme, cs),

        const SizedBox(height: 32),

        // ── Phone input ─────────────────────────────────────────────────
        _buildPhoneField(theme, cs),

        const SizedBox(height: 20),

        // ── Submit button ───────────────────────────────────────────────
        _buildSubmitButton(theme),

        // ── Error area ──────────────────────────────────────────────────
        _buildErrorArea(theme, cs),

        const SizedBox(height: 16),

        // ── Footer hint ─────────────────────────────────────────────────
        _buildFooterHint(theme, cs),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Illustration — a friendly branded circle with an icon
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildIllustration(ColorScheme cs) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.brandGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.chat_rounded, size: 40, color: AppTheme.brandGreen),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Welcome copy — warm, sentence-case, no letter-spacing
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWelcomeCopy(ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter your phone number',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll send you a verification code to confirm your number.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phone field — rounded, borderless fill, WhatsApp-style prefix
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPhoneField(ThemeData theme, ColorScheme cs) {
    return TextFormField(
      controller: _phoneController,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _submit(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
      ],
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇰🇪', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '+254',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 22, color: cs.outlineVariant),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: '712 345 678',
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit button — full-width green CTA, generous height
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Next'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error area — soft tinted container
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildErrorArea(ThemeData theme, ColorScheme cs) {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () => setState(() => _errorMessage = null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Footer hint — terms-style note at the bottom
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFooterHint(ThemeData theme, ColorScheme cs) {
    return Text(
      'Carrier charges may apply.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: 12,
      ),
    );
  }
}
