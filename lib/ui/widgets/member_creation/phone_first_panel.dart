import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../database/database.dart';
import '../../../services/members.dart';
import '../../../ui/theme/app_theme.dart';
import '../edu_form_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// The resolved state of the phone-first lookup step.
///
/// The panel progresses through a discrete set of states:
///   idle → looking → [resolved | notFound | error]
sealed class _LookupState {
  const _LookupState();
}

class _Idle extends _LookupState {
  const _Idle();
}

class _Looking extends _LookupState {
  const _Looking();
}

class _Resolved extends _LookupState {
  const _Resolved(this.user);
  final UsersData user;
}

class _NotFound extends _LookupState {
  const _NotFound(this.phone);
  final String phone;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point widget
// ─────────────────────────────────────────────────────────────────────────────

/// A phone-first identity resolution panel used by Teacher, Staff, and
/// Guardian creation flows.
///
/// ### Flow
/// 1. User types a phone number.
/// 2. After a short debounce the panel queries the local `users` table.
/// 3a. If a user is found → the found card slides in with the user's name
///     pre-filled. The name field is read-only (user exists — cannot rename).
/// 3b. If not found → an "Enter name" field fades in below the phone field.
/// 4. The caller's [onConfirmed] callback fires with the resolved phone,
///    optional name, and the pre-filled [UsersData] (null when new).
///
/// ### Layout
/// The panel is a [Column] that expands in-place — it should be embedded
/// inside a bottom-sheet or slide-over dialog by the parent.
///
/// ### Styling
/// Follows the EduXal design system: elevation via shadows, no border lines
/// on card content, `BorderRadius.circular(10)`, w300/w400 typography.
class PhoneFirstPanel extends StatefulWidget {
  const PhoneFirstPanel({
    super.key,
    required this.service,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.alreadyExistsMessage = 'This person is already added.',
    this.checkAlreadyExists,
    this.extraFields,
    required this.onConfirmed,
    this.onCancel,
  });

  /// The [MemberCreationService] to use for phone lookups.
  final MemberCreationService service;

  /// Shown at the top of the panel (e.g. "Add Teacher").
  final String title;

  /// Supporting line under the title.
  final String subtitle;

  /// Label for the primary CTA button (e.g. "Add Teacher", "Add Guardian").
  final String ctaLabel;

  /// Message shown when [MemberCreationError.alreadyExists] is returned.
  final String alreadyExistsMessage;

  /// Called after a user is resolved via phone lookup to check if they
  /// already hold the role being created. Returns `true` if the user is
  /// already a member of that type at the target school.
  final Future<bool> Function(UsersData user)? checkAlreadyExists;

  /// Optional slot for additional form fields rendered between the resolved
  /// user card (or name field) and the CTA button.  Receives the current
  /// [UsersData] if one was resolved (null for new users).
  final Widget Function(UsersData? resolvedUser)? extraFields;

  /// Called when the user taps the CTA.
  ///
  /// [phone] is always set (normalised).
  /// [name] is non-null only when a new user is being created.
  /// [resolvedUser] is non-null when an existing user was found by phone.
  final Future<void> Function({
    required String phone,
    String? name,
    UsersData? resolvedUser,
  })
  onConfirmed;

  final VoidCallback? onCancel;

  @override
  State<PhoneFirstPanel> createState() => _PhoneFirstPanelState();
}

class _PhoneFirstPanelState extends State<PhoneFirstPanel>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  // ── State ──────────────────────────────────────────────────────────────────
  _LookupState _lookupState = const _Idle();
  bool _saving = false;
  bool _isDuplicate = false;
  String? _submitError;
  Timer? _debounce;

  // ── Animation controllers ──────────────────────────────────────────────────
  // Drives the height of the "user-found card" section.
  late final AnimationController _foundCardCtrl;
  late final Animation<double> _foundCardFade;

  // Drives the height of the "name input" section for new users.
  late final AnimationController _nameInputCtrl;
  late final Animation<double> _nameInputFade;

  @override
  void initState() {
    super.initState();

    _foundCardCtrl = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _foundCardFade = CurvedAnimation(
      parent: _foundCardCtrl,
      curve: Curves.easeOutCubic,
    );

    _nameInputCtrl = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );
    _nameInputFade = CurvedAnimation(
      parent: _nameInputCtrl,
      curve: Curves.easeOutCubic,
    );

    // Rebuild when the user types a name so _isReadyToSubmit re-evaluates
    // and the CTA button enables/disables accordingly.
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.removeListener(_onNameChanged);
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _phoneFocus.dispose();
    _nameFocus.dispose();
    _foundCardCtrl.dispose();
    _nameInputCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    // Trigger a rebuild so _isReadyToSubmit picks up the latest text.
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phone input → debounced lookup
  // ─────────────────────────────────────────────────────────────────────────

  void _onPhoneChanged(String value) {
    // Clear any previous resolved state and collapse expansion areas.
    if (_lookupState is! _Idle && _lookupState is! _Looking) {
      _foundCardCtrl.reverse();
      _nameInputCtrl.reverse();
      setState(() {
        _lookupState = const _Idle();
        _isDuplicate = false;
        _submitError = null;
      });
    }

    _debounce?.cancel();
    final trimmed = value.trim();

    // Only search when we have a plausibly valid phone length (≥9 digits).
    final digitCount = trimmed.replaceAll(RegExp(r'[^\d]'), '').length;
    if (digitCount < 9) return;

    _debounce = Timer(const Duration(milliseconds: 480), () {
      if (mounted) _runLookup(trimmed);
    });
  }

  Future<void> _runLookup(String phone) async {
    if (!mounted) return;
    setState(() => _lookupState = const _Looking());

    final result = await widget.service.lookupPhone(phone);

    if (!mounted) return;

    switch (result) {
      case UserFound(:final user):
        // Check if already exists in target role.
        bool isDuplicate = false;
        if (widget.checkAlreadyExists != null) {
          isDuplicate = await widget.checkAlreadyExists!(user);
        }
        // Collapse name input if it was open, open found card.
        _nameInputCtrl.reverse();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (isDuplicate) {
          setState(() {
            _lookupState = _Resolved(user);
            _isDuplicate = true;
            _submitError = widget.alreadyExistsMessage;
          });
        } else {
          setState(() {
            _lookupState = _Resolved(user);
            _isDuplicate = false;
            _submitError = null;
          });
        }
        _foundCardCtrl.forward();

      case UserNotFound():
        // Collapse found card if it was open, open name input.
        _foundCardCtrl.reverse();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        setState(() => _lookupState = _NotFound(phone));
        _nameInputCtrl.forward();
        // Give a beat before moving focus.
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (mounted) _nameFocus.requestFocus();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CTA submission
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitError = null);

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    String? name;
    UsersData? resolvedUser;

    switch (_lookupState) {
      case _Resolved(:final user):
        // User already exists — no form fields need validating.
        resolvedUser = user;
      case _NotFound():
        // Name field is visible — validate it (requires first + last name).
        if (!(_formKey.currentState?.validate() ?? false)) return;
        name = _nameCtrl.text.trim();
        if (name.isEmpty) {
          setState(() => _submitError = 'Please enter the person\'s name.');
          return;
        }
      default:
        // Still idle/looking/error — don't submit yet.
        return;
    }

    setState(() => _saving = true);

    try {
      await widget.onConfirmed(
        phone: phone,
        name: name,
        resolvedUser: resolvedUser,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _submitError = e.toString();
        });
      }
      return;
    }

    if (mounted) setState(() => _saving = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _PanelHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            cs: cs,
            isDark: isDark,
            onCancel: widget.onCancel,
          ),

          // ── Phone field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _PhoneField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              isLooking: _lookupState is _Looking,
              cs: cs,
              onChanged: _onPhoneChanged,
            ),
          ),

          // ── Animated: found-user card ───────────────────────────────────
          SizeTransition(
            sizeFactor: _foundCardFade,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _foundCardFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _lookupState is _Resolved
                    ? _FoundUserCard(
                        user: (_lookupState as _Resolved).user,
                        cs: cs,
                        isDark: isDark,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Animated: name input for new users ─────────────────────────
          SizeTransition(
            sizeFactor: _nameInputFade,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _nameInputFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _NameField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
            ),
          ),

          // ── Extra caller-supplied fields ────────────────────────────────
          if (widget.extraFields != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _isReadyForExtra
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: widget.extraFields!(
                        _lookupState is _Resolved
                            ? (_lookupState as _Resolved).user
                            : null,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

          // ── Error banner ────────────────────────────────────────────────
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _ErrorBanner(
                message: _submitError!,
                cs: cs,
                isDark: isDark,
              ),
            ),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel — plain text button
                GestureDetector(
                  onTap: _saving ? null : widget.onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _saving
                            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                            : cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Confirm — green tick icon button
                _ConfirmIconButton(
                  enabled: _isReadyToSubmit && !_saving,
                  saving: _saving,
                  onTap: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isReadyForExtra =>
      _lookupState is _Resolved || _lookupState is _NotFound;

  bool get _isReadyToSubmit {
    if (_isDuplicate) return false;
    switch (_lookupState) {
      case _Resolved():
        return true;
      case _NotFound():
        return _nameCtrl.text.trim().isNotEmpty;
      default:
        return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.isDark,
    this.onCancel,
  });

  final String title;
  final String subtitle;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            _CloseButton(cs: cs, isDark: isDark, onTap: onCancel!),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.close,
            size: 18,
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phone field with inline spinner
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.isLooking,
    required this.cs,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLooking;
  final ColorScheme cs;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return EduFormField(
      controller: controller,
      focusNode: focusNode,
      label: 'Phone Number',
      hint: '+254 700 000 000',
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
      ],
      suffix: isLooking
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cs.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          : null,
      onChanged: onChanged,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Phone number required';
        return null;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Found-user card
// ─────────────────────────────────────────────────────────────────────────────

class _FoundUserCard extends StatelessWidget {
  const _FoundUserCard({
    required this.user,
    required this.cs,
    required this.isDark,
  });

  final UsersData user;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.brandIndigoDark : AppTheme.brandIndigo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.20 : 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                _initials(user.name),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.phone,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: accent.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Name field (shown for new users)
// ─────────────────────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.cs,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Custom label row with the "new user" badge
        Row(
          children: [
            Text(
              'FULL NAME',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'New user — will receive invite',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: isDark ? 0.9 : 0.75),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Reuse EduFormField but suppress its built-in label (empty string trick
        // is avoided — instead we pass label as empty and hide via the field
        // directly by building the TextFormField portion ourselves).
        // Since EduFormField always renders the label, we use a thin wrapper:
        _NameInputField(
          controller: controller,
          focusNode: focusNode,
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Button — animated save state
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmIconButton extends StatelessWidget {
  const _ConfirmIconButton({
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const green = AppTheme.brandGreen;
    final effectiveColor = enabled && !saving
        ? green
        : green.withValues(alpha: 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: (enabled && !saving)
            ? [
                BoxShadow(
                  color: green.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(
            Colors.white.withValues(alpha: 0.08),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: saving
                  ? SizedBox(
                      key: const ValueKey('spin'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    )
                  : const Icon(
                      key: ValueKey('check'),
                      Icons.check,
                      size: 17,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.cs,
    required this.isDark,
  });

  final String message;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 15,
              color: cs.error.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.error.withValues(alpha: isDark ? 0.85 : 0.75),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Name input field — EduFormField-styled TextFormField without the label row
// (the label row is rendered separately in _NameField with the badge chip)
// ─────────────────────────────────────────────────────────────────────────────

class _NameInputField extends StatelessWidget {
  const _NameInputField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.cs,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E2A3A) : cs.surfaceContainerLowest,
        hintText: 'e.g. Jane Mwangi',
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: isDark
              ? BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          borderSide: BorderSide(color: cs.error, width: 1),
        ),
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Name is required';
        if (v.trim().split(RegExp(r'\s+')).length < 2) {
          return 'Please enter a full name (first + last)';
        }
        return null;
      },
    );
  }
}
