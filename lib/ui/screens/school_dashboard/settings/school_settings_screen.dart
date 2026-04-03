import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/animated_save_button.dart';
import '../../../widgets/edu_sheet.dart';
import '../../../../models/school_context.dart';
import 'mpesa_config_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SchoolSettingsScreen — owner-facing school profile & settings editor
//
// Displays all editable school fields (name, motto, phone, email, domain,
// county, established year) plus a logo picker. Writes changes via
// SchoolsDao.updateSchoolDetails() which produces a SyncAction.updateSchool
// log entry automatically.
//
// Follows AGENT.md §21 UI conventions: clean, minimal, light font weights,
// proper border radii, data-table divider style for rows.
// ─────────────────────────────────────────────────────────────────────────────

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({super.key, required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mottoCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _domainCtrl;
  late final TextEditingController _establishedCtrl;

  late KenyaCounty? _selectedCounty;

  File? _logoImage;
  final _picker = ImagePicker();

  bool _saving = false;
  bool _isDirty = false;
  String? _error;

  SchoolsData get _school => widget.schoolContext.membership.school;

  // ── Dirty tracking ────────────────────────────────────────────────────────

  bool _computeDirty() {
    final s = _school;
    if (_nameCtrl.text.trim() != s.name) return true;
    if (_mottoCtrl.text.trim() != (s.motto ?? '')) return true;
    if (_phoneCtrl.text.trim() != (s.phone ?? '')) return true;
    if (_emailCtrl.text.trim() != (s.email ?? '')) return true;
    if (_domainCtrl.text.trim() != (s.domain ?? '')) return true;
    final estText = _establishedCtrl.text.trim();
    final originalEst = s.established?.toString() ?? '';
    if (estText != originalEst) return true;
    final originalCounty = KenyaCounty.values
        .where((c) => c.number == s.county)
        .firstOrNull;
    if (_selectedCounty != originalCounty) return true;
    if (_logoImage != null) return true;
    return false;
  }

  void _onTextChanged() {
    final dirty = _computeDirty();
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final s = _school;
    _nameCtrl = TextEditingController(text: s.name);
    _mottoCtrl = TextEditingController(text: s.motto ?? '');
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
    _domainCtrl = TextEditingController(text: s.domain ?? '');
    _establishedCtrl = TextEditingController(
      text: s.established?.toString() ?? '',
    );
    _selectedCounty = KenyaCounty.values
        .where((c) => c.number == s.county)
        .firstOrNull;

    _nameCtrl.addListener(_onTextChanged);
    _mottoCtrl.addListener(_onTextChanged);
    _phoneCtrl.addListener(_onTextChanged);
    _emailCtrl.addListener(_onTextChanged);
    _domainCtrl.addListener(_onTextChanged);
    _establishedCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mottoCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _domainCtrl.dispose();
    _establishedCtrl.dispose();
    super.dispose();
  }

  // ── Logo picking ──────────────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() {
        _logoImage = File(picked.path);
        _isDirty = true;
      });
    }
  }

  void _clearLogo() {
    setState(() {
      _logoImage = null;
      _isDirty = _computeDirty();
    });
  }

  // ── County picker ─────────────────────────────────────────────────────────

  Future<void> _openCountyPicker() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showEduSheet<KenyaCounty>(
      context: context,
      builder: (_) => _CountyPickerSheet(selected: _selectedCounty, cs: cs),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCounty = selected;
        _isDirty = _computeDirty();
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'School name is required.');
      return;
    }

    if (_selectedCounty == null) {
      setState(() => _error = 'Please select a county.');
      return;
    }

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final nowSeconds = BigInt.from(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final motto = _mottoCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final domain = _domainCtrl.text.trim();
      final estText = _establishedCtrl.text.trim();
      final established = estText.isEmpty ? null : int.tryParse(estText);

      await schoolsDao.updateSchoolDetails(
        _school.id,
        SchoolsCompanion(
          name: Value(name),
          motto: Value(motto.isEmpty ? null : motto),
          phone: Value(phone.isEmpty ? null : phone),
          email: Value(email.isEmpty ? null : email),
          domain: Value(domain.isEmpty ? null : domain),
          county: Value(_selectedCounty!.number),
          established: Value(established),
          updated: Value(nowSeconds),
        ),
        accountId: accountId,
      );

      // Save logo to local cache if a new one was picked.
      if (_logoImage != null) {
        final bytes = await _logoImage!.readAsBytes();
        await FileCache.saveBytes(bytes, FileCache.logoPath(_school.id));
        await schoolsDao.logLogoChange(_school.id, accountId: accountId);
      }

      if (mounted) {
        setState(() {
          _isDirty = false;
          _logoImage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('School details saved.'),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= AppTheme.kTabletBreakpoint;

    Widget content = _buildContent(cs, isDark, isDesktop);

    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildContent(ColorScheme cs, bool isDark, bool isDesktop) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Header row ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your school profile and details',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSaveButton(
              isDirty: _isDirty,
              isSaving: _saving,
              onSave: (_isDirty && !_saving) ? _save : null,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Error banner ──────────────────────────────────────────────
        if (_error != null) ...[
          _ErrorBanner(error: _error!, cs: cs),
          const SizedBox(height: 14),
        ],

        // ── Logo section ──────────────────────────────────────────────
        _LogoSection(
          schoolId: _school.id,
          logoImage: _logoImage,
          onPick: _pickLogo,
          onClear: _clearLogo,
          cs: cs,
          isDark: isDark,
        ),

        const SizedBox(height: 20),

        // ── Section: Identity ─────────────────────────────────────────
        _SectionHeader(title: 'Identity', cs: cs),
        const SizedBox(height: 4),
        _SectionContainer(
          cs: cs,
          isDark: isDark,
          isDesktop: isDesktop,
          children: [
            _FormField(
              label: 'School Name',
              controller: _nameCtrl,
              cs: cs,
              isDark: isDark,
              required_: true,
            ),
            _divider(cs),
            _FormField(
              label: 'Motto',
              controller: _mottoCtrl,
              cs: cs,
              isDark: isDark,
              hint: 'Optional — school motto or tagline',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Section: Contact ──────────────────────────────────────────
        _SectionHeader(title: 'Contact', cs: cs),
        const SizedBox(height: 4),
        _SectionContainer(
          cs: cs,
          isDark: isDark,
          isDesktop: isDesktop,
          children: [
            _FormField(
              label: 'Phone',
              controller: _phoneCtrl,
              cs: cs,
              isDark: isDark,
              hint: 'Optional',
              keyboardType: TextInputType.phone,
            ),
            _divider(cs),
            _FormField(
              label: 'Email',
              controller: _emailCtrl,
              cs: cs,
              isDark: isDark,
              hint: 'Optional',
              keyboardType: TextInputType.emailAddress,
            ),
            _divider(cs),
            _FormField(
              label: 'Domain',
              controller: _domainCtrl,
              cs: cs,
              isDark: isDark,
              hint: 'Optional — e.g. school.ac.ke',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Section: Location & Details ───────────────────────────────
        _SectionHeader(title: 'Location & Details', cs: cs),
        const SizedBox(height: 4),
        _SectionContainer(
          cs: cs,
          isDark: isDark,
          isDesktop: isDesktop,
          children: [
            _CountyPickerRow(
              selected: _selectedCounty,
              onTap: _openCountyPicker,
              cs: cs,
              isDark: isDark,
            ),
            _divider(cs),
            _FormField(
              label: 'Established',
              controller: _establishedCtrl,
              cs: cs,
              isDark: isDark,
              hint: 'Optional — year, e.g. 1985',
              keyboardType: TextInputType.number,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Section: Integrations ─────────────────────────────────────
        _SectionHeader(title: 'Integrations', cs: cs),
        const SizedBox(height: 4),
        _SectionContainer(
          cs: cs,
          isDark: isDark,
          isDesktop: isDesktop,
          children: [
            _NavigationRow(
              icon: Icons.phone_android_rounded,
              label: 'M-Pesa Configuration',
              subtitle: 'Daraja API payment integration',
              cs: cs,
              isDark: isDark,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MpesaConfigScreen(schoolContext: widget.schoolContext),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Section: Subscription ─────────────────────────────────────
        _SectionHeader(title: 'Subscription', cs: cs),
        const SizedBox(height: 4),
        _SubscriptionSection(
          schoolId: widget.schoolContext.membership.school.id,
          cs: cs,
          isDark: isDark,
          isDesktop: isDesktop,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _divider(ColorScheme cs) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private helper widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.cs});

  final String error;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.cs});

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

// ── Section container ───────────────────────────────────────────────────────

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.cs,
    required this.isDark,
    required this.isDesktop,
    required this.children,
  });

  final ColorScheme cs;
  final bool isDark;
  final bool isDesktop;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ── Form field row ──────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.cs,
    required this.isDark,
    this.hint,
    this.keyboardType,
    this.required_ = false,
  });

  final String label;
  final TextEditingController controller;
  final ColorScheme cs;
  final bool isDark;
  final String? hint;
  final TextInputType? keyboardType;
  final bool required_;

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
            ),
          ),
        ],
      ),
    );
  }
}

// ── County picker row ───────────────────────────────────────────────────────

class _CountyPickerRow extends StatelessWidget {
  const _CountyPickerRow({
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  final KenyaCounty? selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'County',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '*',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.error.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected?.label ?? 'Select county',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: selected != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo section ────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.schoolId,
    required this.logoImage,
    required this.onPick,
    required this.onClear,
    required this.cs,
    required this.isDark,
  });

  final String schoolId;
  final File? logoImage;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(onTap: onPick, child: _buildLogoPreview()),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: onPick,
                icon: Icon(
                  Icons.camera_alt_outlined,
                  size: 15,
                  color: cs.primary,
                ),
                label: Text(
                  'Change logo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: cs.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (logoImage != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: cs.error.withValues(alpha: 0.7),
                  ),
                  label: Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: cs.error.withValues(alpha: 0.7),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPreview() {
    // If a new image was picked, show it.
    if (logoImage != null) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kCardRadius + 4),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(logoImage!, fit: BoxFit.cover),
      );
    }

    // Otherwise, try loading from cache.
    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.logoPath(schoolId)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.kCardRadius + 4),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Image.file(file, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 28,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Logo',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// County Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════════

// ── Navigation row — tappable link to a sub-screen ──────────────────────────

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? cs.primaryContainer.withValues(alpha: 0.15)
                    : cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
              ),
              child: Icon(icon, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subscription section — read-only plan & usage display ───────────────────

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({
    required this.schoolId,
    required this.cs,
    required this.isDark,
    required this.isDesktop,
  });

  final String schoolId;
  final ColorScheme cs;
  final bool isDark;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Plan>>(
      stream: plansDao.watchAllPlans(),
      builder: (context, plansSnap) {
        final plans = plansSnap.data ?? [];
        final activePlans = plans
            .where((p) => p.status == PlanStatus.active)
            .toList();

        if (activePlans.isEmpty && !plansSnap.hasData) {
          // Still loading.
          return _buildContainer(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (activePlans.isEmpty) {
          return _buildContainer(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No subscription plans available. Contact your system administrator.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Show each active plan as a read-only card.
        final children = <Widget>[];
        for (var i = 0; i < activePlans.length; i++) {
          if (i > 0) {
            children.add(
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            );
          }
          children.add(_PlanRow(plan: activePlans[i], cs: cs, isDark: isDark));
        }

        return _buildContainer(children: children);
      },
    );
  }

  Widget _buildContainer({required List<Widget> children}) {
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.kRadius),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan, required this.cs, required this.isDark});

  final Plan plan;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Parse features JSON if available.
    final featuresText = plan.features;
    final hasDescription =
        plan.description != null && plan.description!.isNotEmpty;
    final hasFeatures = featuresText != null && featuresText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.tertiaryContainer.withValues(alpha: 0.15)
                      : cs.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 14,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    if (hasDescription)
                      Text(
                        plan.description!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.primaryContainer.withValues(alpha: 0.15)
                      : cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
                ),
                child: Text(
                  'KES ${plan.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          if (hasFeatures) ...[
            const SizedBox(height: 8),
            Text(
              featuresText,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w300,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 4),
              Text(
                'Managed by system administrators',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountyPickerSheet extends StatefulWidget {
  const _CountyPickerSheet({required this.selected, required this.cs});

  final KenyaCounty? selected;
  final ColorScheme cs;

  @override
  State<_CountyPickerSheet> createState() => _CountyPickerSheetState();
}

class _CountyPickerSheetState extends State<_CountyPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<KenyaCounty> _filtered = KenyaCounty.values.toList();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = KenyaCounty.values.toList();
      } else {
        _filtered = KenyaCounty.values
            .where((c) => c.label.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Counties',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Search field ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search counties…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kCardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── List ───────────────────────────────────────────────────
          Flexible(
            child: ListView.builder(
              itemCount: _filtered.length,
              padding: const EdgeInsets.only(bottom: 20),
              itemBuilder: (context, index) {
                final county = _filtered[index];
                final isSelected = county == widget.selected;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(county),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            county.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: isSelected ? cs.primary : cs.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
