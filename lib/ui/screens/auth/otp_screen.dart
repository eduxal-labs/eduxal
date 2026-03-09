import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../client.dart';
import '../../../core/constants.dart';
import '../../../core/grpc_errors.dart';
import '../../../models/result.dart';
import '../../../models/verify_result.dart';
import '../../theme/app_theme.dart';
import 'setup_screen.dart';

/// OTP verification screen — 6 individual digit boxes with auto-advance,
/// paste support, countdown timers, and resend logic.
///
/// WhatsApp/YouTube-inspired: warm sentence-case copy, rounded digit boxes,
/// full-width green CTA, comfortable spacing. No uppercase letter-spaced
/// headings, no decorative lines.
class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _digitCount = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isLoading = false;
  String? _errorMessage;

  late String _verificationId;
  late DateTime _expiryTime;
  late DateTime _cooldownTime;
  Timer? _tickTimer;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;

    _controllers = List.generate(_digitCount, (_) => TextEditingController());
    _focusNodes = List.generate(_digitCount, (_) => FocusNode());

    _resetTimers();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _resetTimers() {
    final now = DateTime.now();
    _expiryTime = now.add(kVerificationExpiry);
    _cooldownTime = now.add(kResendCooldown);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _entranceController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String get _currentCode => _controllers.map((c) => c.text).join();

  bool get _isCodeComplete => _currentCode.length == _digitCount;

  /// Masks the phone for display: "0712•••678"
  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 7) return p;
    final start = p.substring(0, 4);
    final end = p.substring(p.length - 3);
    return '$start •••$end';
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Digit box input handling
  // ─────────────────────────────────────────────────────────────────────────

  void _onDigitChanged(int index, String value) {
    if (_isLoading) return;

    // Handle paste — if the value is more than 1 character, treat as paste.
    if (value.length > 1) {
      _handlePaste(value);
      return;
    }

    // Single digit entered → advance to next box.
    if (value.length == 1 && index < _digitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _onDigitKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Backspace on empty box → move focus to previous box.
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handlePaste(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (var i = 0; i < _digitCount; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }

    final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
    if (nextEmpty != -1) {
      _focusNodes[nextEmpty].requestFocus();
    } else {
      _focusNodes[_digitCount - 1].requestFocus();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verify
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLoading) return;

    final code = _currentCode;
    if (code.length < _digitCount) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await client.authentication.verify(_verificationId, code);

    if (!mounted) return;

    switch (result) {
      case Ok(value: final verifyResult):
        // The server has consumed the OTP at this point — any failure after
        // here must NOT leave the user stranded on the OTP screen, because
        // re-submitting the same code will always return "invalid code".
        try {
          switch (verifyResult) {
            case VerifyResultAuthenticated(
              :final authenticated,
              :final profileUploadUrl,
            ):
              try {
                await client.saveAccount(authenticated);
              } catch (e, st) {
                // Log but do NOT rethrow. The OTP is already consumed so we
                // must proceed to the next screen regardless. The worst case
                // is that the user lands on setup without a persisted session
                // — they will be prompted to log in again on next cold start.
                debugPrint('saveAccount failed after verify: $e\n$st');
              }
              if (!mounted) return;
              setState(() => _isLoading = false);
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => SetupScreen.existingUser(
                    authenticated: authenticated,
                    profileUploadUrl: profileUploadUrl,
                  ),
                  transitionsBuilder: (_, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              );
            case VerifyResultRegistered(:final token):
              setState(() => _isLoading = false);
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) =>
                      SetupScreen(token: token, phone: widget.phone),
                  transitionsBuilder: (_, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              );
          }
        } catch (e, st) {
          // Safety net: catch anything unexpected in the success path so the
          // user is never silently stuck on the OTP screen after the server
          // has already consumed the code.
          debugPrint('Unexpected error after successful verify: $e\n$st');
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Something went wrong. Please try logging in again.';
          });
        }
      case Err(error: final error):
        setState(() {
          _isLoading = false;
          _errorMessage = error.toFriendlyMessage();
        });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Resend
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await client.authentication.login(widget.phone);

    if (!mounted) return;

    setState(() => _isLoading = false);

    switch (result) {
      case Ok(value: final verification):
        _clearAll();
        setState(() {
          _verificationId = verification.id;
          _resetTimers();
        });
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
        _buildHeader(theme, cs),
        const SizedBox(height: 40),
        _buildDigitBoxes(theme, cs),
        const SizedBox(height: 28),
        _buildSubmitButton(),
        const SizedBox(height: 20),
        _buildTimerArea(theme, cs),
        _buildErrorArea(theme, cs),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header — warm, sentence-case, no decorative lines
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Illustration circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 36,
            color: AppTheme.brandGreen,
          ),
        ),
        const SizedBox(height: 28),

        Text(
          'Verify your number',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),

        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Enter the 6-digit code we sent to\n'),
              TextSpan(
                text: _maskedPhone,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Digit boxes — rounded, filled, comfortable size
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDigitBoxes(ThemeData theme, ColorScheme cs) {
    final fillColor = cs.surfaceContainer;
    final fillColorDisabled = cs.surfaceContainerHighest;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_digitCount, (i) {
        // Visual grouping: a wider gap between digits 3 and 4.
        final leftMargin = i == 3 ? 16.0 : (i == 0 ? 0.0 : 8.0);

        return Padding(
          padding: EdgeInsets.only(left: leftMargin),
          child: SizedBox(
            width: 46,
            height: 54,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) => _onDigitKeyEvent(i, event),
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _SingleOrPasteFormatter(),
                ],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  filled: true,
                  fillColor: _isLoading ? fillColorDisabled : fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide(
                      color: AppTheme.brandGreen,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.kRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => _onDigitChanged(i, value),
                onTap: () {
                  _controllers[i].selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controllers[i].text.length,
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: (_isLoading || !_isCodeComplete) ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Verify'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timer area — resend cooldown + expiry countdown
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTimerArea(ThemeData theme, ColorScheme cs) {
    final now = DateTime.now();
    final isExpired = now.isAfter(_expiryTime);
    final canResend = now.isAfter(_cooldownTime);

    if (isExpired) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Text(
              'Code expired',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _isLoading ? null : _resend,
              child: const Text('Request new code'),
            ),
          ],
        ),
      );
    }

    final expiryRemaining = _expiryTime.difference(now);
    final expiryMin = expiryRemaining.inMinutes.toString().padLeft(2, '0');
    final expirySec = (expiryRemaining.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );

    return Column(
      children: [
        if (canResend)
          TextButton(
            onPressed: _isLoading ? null : _resend,
            child: const Text('Resend code'),
          )
        else
          Text(
            'Resend code in ${_cooldownTime.difference(now).inSeconds}s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Code expires in $expiryMin:$expirySec',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error area
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Input formatter: allows single digit or full paste through
// ─────────────────────────────────────────────────────────────────────────────

class _SingleOrPasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    if (newValue.text.length == 1) return newValue;

    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return oldValue;

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
