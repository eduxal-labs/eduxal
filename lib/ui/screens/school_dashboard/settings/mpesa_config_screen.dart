import 'package:flutter/material.dart';

import '../../../../client.dart';
import '../../../../database/tables/mpesa.dart';
import '../../../../models/school_context.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MpesaConfigScreen — owner-facing M-Pesa Daraja API configuration
//
// Displays fields for configuring M-Pesa mobile payment integration:
// business short code, consumer key, consumer secret, passkey, and
// environment toggle (sandbox/production).
//
// Save creates or updates via CatalogDao.upsertMpesa() which auto-selects
// SyncAction.createMpesa or SyncAction.updateMpesa based on existing state.
//
// Follows AGENT.md §21 UI conventions.
// ─────────────────────────────────────────────────────────────────────────────

class MpesaConfigScreen extends StatefulWidget {
  const MpesaConfigScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  State<MpesaConfigScreen> createState() => _MpesaConfigScreenState();
}

class _MpesaConfigScreenState extends State<MpesaConfigScreen> {
  final _shortcodeCtrl = TextEditingController();
  final _consumerKeyCtrl = TextEditingController();
  final _consumerSecretCtrl = TextEditingController();
  final _passkeyCtrl = TextEditingController();

  MpesaEnv _env = MpesaEnv.sandbox;

  bool _saving = false;
  bool _isDirty = false;
  bool _loading = true;
  bool _isUpdate = false;
  String? _error;

  // Track whether secrets are visible.
  bool _showConsumerKey = false;
  bool _showConsumerSecret = false;
  bool _showPasskey = false;

  String get _schoolId => widget.schoolContext.membership.school.id;

  // Snapshot of original values for dirty tracking.
  String _origShortcode = '';
  String _origConsumerKey = '';
  String _origConsumerSecret = '';
  String _origPasskey = '';
  MpesaEnv _origEnv = MpesaEnv.sandbox;

  @override
  void initState() {
    super.initState();
    _loadExisting();

    _shortcodeCtrl.addListener(_onChanged);
    _consumerKeyCtrl.addListener(_onChanged);
    _consumerSecretCtrl.addListener(_onChanged);
    _passkeyCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _shortcodeCtrl.dispose();
    _consumerKeyCtrl.dispose();
    _consumerSecretCtrl.dispose();
    _passkeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final existing = await catalogDao.getMpesa(_schoolId);
    if (!mounted) return;

    if (existing != null) {
      _shortcodeCtrl.text = existing.shortcode;
      _consumerKeyCtrl.text = existing.consumerKey;
      _consumerSecretCtrl.text = existing.consumerSecret;
      _passkeyCtrl.text = existing.passkey;
      _env = existing.env;
      _isUpdate = true;

      _origShortcode = existing.shortcode;
      _origConsumerKey = existing.consumerKey;
      _origConsumerSecret = existing.consumerSecret;
      _origPasskey = existing.passkey;
      _origEnv = existing.env;
    }

    setState(() => _loading = false);
  }

  void _onChanged() {
    final dirty =
        _shortcodeCtrl.text.trim() != _origShortcode ||
        _consumerKeyCtrl.text.trim() != _origConsumerKey ||
        _consumerSecretCtrl.text.trim() != _origConsumerSecret ||
        _passkeyCtrl.text.trim() != _origPasskey ||
        _env != _origEnv;
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  void _onEnvChanged(MpesaEnv env) {
    setState(() => _env = env);
    _onChanged();
  }

  Future<void> _save() async {
    final shortcode = _shortcodeCtrl.text.trim();
    final consumerKey = _consumerKeyCtrl.text.trim();
    final consumerSecret = _consumerSecretCtrl.text.trim();
    final passkey = _passkeyCtrl.text.trim();

    if (shortcode.isEmpty) {
      setState(() => _error = 'Business short code is required.');
      return;
    }
    if (consumerKey.isEmpty) {
      setState(() => _error = 'Consumer key is required.');
      return;
    }
    if (consumerSecret.isEmpty) {
      setState(() => _error = 'Consumer secret is required.');
      return;
    }
    if (passkey.isEmpty) {
      setState(() => _error = 'Passkey is required.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await catalogDao.upsertMpesa(
        schoolId: _schoolId,
        consumerKey: consumerKey,
        consumerSecret: consumerSecret,
        passkey: passkey,
        shortcode: shortcode,
        env: _env,
        accountId: accountId,
      );

      // Update originals so dirty tracking resets.
      _origShortcode = shortcode;
      _origConsumerKey = consumerKey;
      _origConsumerSecret = consumerSecret;
      _origPasskey = passkey;
      _origEnv = _env;
      final wasUpdate = _isUpdate;
      _isUpdate = true;

      if (mounted) {
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasUpdate
                  ? 'M-Pesa configuration updated.'
                  : 'M-Pesa configuration saved.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isUpdate) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.kModalRadius),
          ),
          title: Text(
            'Remove M-Pesa Config?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          content: Text(
            'This will remove the M-Pesa integration for this school. '
            'Mobile payments will no longer be processed.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Remove',
                style: TextStyle(fontWeight: FontWeight.w500, color: cs.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await catalogDao.deleteMpesa(schoolId: _schoolId, accountId: accountId);

      _shortcodeCtrl.clear();
      _consumerKeyCtrl.clear();
      _consumerSecretCtrl.clear();
      _passkeyCtrl.clear();

      _origShortcode = '';
      _origConsumerKey = '';
      _origConsumerSecret = '';
      _origPasskey = '';
      _origEnv = MpesaEnv.sandbox;

      if (mounted) {
        setState(() {
          _env = MpesaEnv.sandbox;
          _isUpdate = false;
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('M-Pesa configuration removed.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to remove: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= AppTheme.kTabletBreakpoint;

    Widget content = _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
        : _buildContent(cs, isDark, isDesktop);

    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'M-Pesa Configuration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          if (_isUpdate && !_saving)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: cs.error.withValues(alpha: 0.7),
              ),
              tooltip: 'Remove M-Pesa config',
              onPressed: _delete,
            ),
          AnimatedSaveButton(
            isDirty: _isDirty,
            isSaving: _saving,
            onSave: (_isDirty && !_saving) ? _save : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent(ColorScheme cs, bool isDark, bool isDesktop) {
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Error banner ──────────────────────────────────────────────
        if (_error != null) ...[
          _ErrorBanner(error: _error!, cs: cs),
          const SizedBox(height: 14),
        ],

        // ── Environment toggle ────────────────────────────────────────
        _SectionLabel(title: 'Environment', cs: cs),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: _EnvOption(
                  label: 'Sandbox',
                  subtitle: 'Testing',
                  icon: Icons.science_outlined,
                  selected: _env == MpesaEnv.sandbox,
                  onTap: () => _onEnvChanged(MpesaEnv.sandbox),
                  cs: cs,
                  isDark: isDark,
                ),
              ),
              Container(width: 0.5, height: 56, color: borderColor),
              Expanded(
                child: _EnvOption(
                  label: 'Production',
                  subtitle: 'Live',
                  icon: Icons.verified_outlined,
                  selected: _env == MpesaEnv.production,
                  onTap: () => _onEnvChanged(MpesaEnv.production),
                  cs: cs,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Business Details ──────────────────────────────────────────
        _SectionLabel(title: 'Business Details', cs: cs),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfigField(
                label: 'Business Short Code',
                controller: _shortcodeCtrl,
                cs: cs,
                isDark: isDark,
                hint: 'e.g. 174379',
                keyboardType: TextInputType.number,
                required_: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── API Credentials ───────────────────────────────────────────
        _SectionLabel(title: 'API Credentials', cs: cs),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.kRadius),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConfigField(
                label: 'Consumer Key',
                controller: _consumerKeyCtrl,
                cs: cs,
                isDark: isDark,
                hint: 'Daraja consumer key',
                required_: true,
                obscured: !_showConsumerKey,
                onToggleVisibility: () =>
                    setState(() => _showConsumerKey = !_showConsumerKey),
              ),
              _fieldDivider(cs),
              _ConfigField(
                label: 'Consumer Secret',
                controller: _consumerSecretCtrl,
                cs: cs,
                isDark: isDark,
                hint: 'Daraja consumer secret',
                required_: true,
                obscured: !_showConsumerSecret,
                onToggleVisibility: () =>
                    setState(() => _showConsumerSecret = !_showConsumerSecret),
              ),
              _fieldDivider(cs),
              _ConfigField(
                label: 'Passkey',
                controller: _passkeyCtrl,
                cs: cs,
                isDark: isDark,
                hint: 'Lipa Na M-Pesa passkey',
                required_: true,
                obscured: !_showPasskey,
                onToggleVisibility: () =>
                    setState(() => _showPasskey = !_showPasskey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Info note ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.primaryContainer.withValues(alpha: 0.1)
                : cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: cs.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Get your API credentials from the Safaricom Daraja portal '
                  '(developer.safaricom.co.ke). Use sandbox credentials for '
                  'testing before switching to production.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _fieldDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.cs});

  final String error;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: cs.error.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.cs});

  final String title;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          letterSpacing: 1.1,
          height: 1.0,
        ),
      ),
    );
  }
}

class _EnvOption extends StatelessWidget {
  const _EnvOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? (isDark
              ? cs.primaryContainer.withValues(alpha: 0.15)
              : cs.primaryContainer.withValues(alpha: 0.4))
        : Colors.transparent;

    final iconColor = selected
        ? cs.primary
        : cs.onSurfaceVariant.withValues(alpha: 0.4);

    final labelColor = selected
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: 0.6);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        color: bgColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigField extends StatelessWidget {
  const _ConfigField({
    required this.label,
    required this.controller,
    required this.cs,
    required this.isDark,
    this.hint,
    this.keyboardType,
    this.required_ = false,
    this.obscured = false,
    this.onToggleVisibility,
  });

  final String label;
  final TextEditingController controller;
  final ColorScheme cs;
  final bool isDark;
  final String? hint;
  final TextInputType? keyboardType;
  final bool required_;
  final bool obscured;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  letterSpacing: 0.6,
                ),
              ),
              if (required_) ...[
                const SizedBox(width: 3),
                Text(
                  '*',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.error.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscured,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
              height: 1.3,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: isDark
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                borderSide: BorderSide(
                  color: cs.primary.withValues(alpha: 0.5),
                ),
              ),
              suffixIcon: onToggleVisibility != null
                  ? IconButton(
                      icon: Icon(
                        obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      onPressed: onToggleVisibility,
                      splashRadius: 16,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
