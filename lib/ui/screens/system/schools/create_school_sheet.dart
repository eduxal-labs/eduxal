import 'dart:async';
import 'dart:io';

import 'package:bson/bson.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import '../../../widgets/inline_date_picker_dialog.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../cache/file_cache.dart';
import '../../../../client.dart';
import '../../../../database/database.dart';
import '../../../../database/tables/curriculum_subjects.dart';
import '../../../../database/tables/enums.dart';
import '../../../../models/system_permissions.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/edu_sheet.dart';
import 'school_detail_screen.dart';

/// Two-step bottom sheet (mobile) / dialog content (desktop) for creating a
/// new school.
///
/// **Step 1 — School details:** name (required), motto, phone, email, county
/// (required), domain, established (date picker, converted to days-since-epoch).
///
/// **Step 2 — Owner:** phone lookup. If found, shows a preview card. If not
/// found, prompts for the new user's name (and optional email) to create an
/// invited user first.
///
/// On submit, calls [SchoolsDao.createSchool] (and optionally
/// [UsersDao.inviteUser] for a new owner). Each DAO method runs its own
/// internal transaction and calls `sync.schedulePush()` on completion.
class CreateSchoolSheet extends StatefulWidget {
  const CreateSchoolSheet({super.key, required this.permissions});

  final SystemPermissions permissions;

  @override
  State<CreateSchoolSheet> createState() => _CreateSchoolSheetState();
}

class _CreateSchoolSheetState extends State<CreateSchoolSheet> {
  // ── Step management ────────────────────────────────────────────────────────

  int _step = 0; // 0 = school details, 1 = owner

  // ── Step 1 controllers ─────────────────────────────────────────────────────

  final _nameCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();

  KenyaCounty? _selectedCounty;
  File? _logoImage;
  final _picker = ImagePicker();

  // Days since epoch for established date; null = not set.
  int? _establishedDays;
  String? _establishedLabel;

  // ── Step 1 errors ──────────────────────────────────────────────────────────

  String? _nameError;
  String? _countyError;

  // ── Step 2 state ───────────────────────────────────────────────────────────

  final _ownerPhoneCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();

  UsersData? _foundOwner; // non-null when lookup found a matching user
  bool _ownerNotFound = false; // true after a lookup returned null

  bool _lookingUp = false;
  Timer? _lookupDebounce;

  String? _ownerPhoneError;
  String? _ownerNameError;

  // ── Submit state ───────────────────────────────────────────────────────────

  bool _submitting = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mottoCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _domainCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _lookupDebounce?.cancel();
    super.dispose();
  }

  // ── Logo picking ───────────────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _logoImage = File(picked.path));
    }
  }

  void _clearLogo() => setState(() => _logoImage = null);

  // ── Step 1 validation ──────────────────────────────────────────────────────

  bool _validateStep1() {
    final name = _nameCtrl.text.trim();

    String? nameErr;
    String? countyErr;

    if (name.isEmpty) nameErr = 'School name is required.';
    if (_selectedCounty == null) countyErr = 'Please select a county.';

    setState(() {
      _nameError = nameErr;
      _countyError = countyErr;
    });

    return nameErr == null && countyErr == null;
  }

  void _goToStep2() {
    if (_validateStep1()) setState(() => _step = 1);
  }

  // ── Owner phone lookup ─────────────────────────────────────────────────────

  void _onOwnerPhoneChanged(String value) {
    setState(() {
      _foundOwner = null;
      _ownerNotFound = false;
      _ownerPhoneError = null;
    });

    _lookupDebounce?.cancel();
    if (value.trim().isEmpty) return;

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () {
      _lookupOwner(value.trim());
    });
  }

  Future<void> _lookupOwner(String phone) async {
    if (!mounted) return;
    setState(() => _lookingUp = true);
    try {
      final user = await usersDao.getUserByPhone(phone);
      if (!mounted) return;
      setState(() {
        _foundOwner = user;
        _ownerNotFound = user == null;
      });
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  // ── Step 2 validation ──────────────────────────────────────────────────────

  bool _validateStep2() {
    final phone = _ownerPhoneCtrl.text.trim();

    String? phoneErr;
    String? nameErr;

    if (phone.isEmpty) {
      phoneErr = 'Owner phone is required.';
    } else if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
      phoneErr = 'Enter a valid phone number.';
    }

    if (_ownerNotFound) {
      final name = _ownerNameCtrl.text.trim();
      if (name.length < 2) nameErr = 'Name must be at least 2 characters.';
    }

    setState(() {
      _ownerPhoneError = phoneErr;
      _ownerNameError = nameErr;
    });

    return phoneErr == null && nameErr == null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validateStep2()) return;

    final accountId = cache.currentUser?.user.id;
    if (accountId == null) return;

    // Re-check for the owner user right before submitting.
    final phone = _ownerPhoneCtrl.text.trim();
    final latestUser = await usersDao.getUserByPhone(phone);
    if (!mounted) return;

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final nowSeconds = BigInt.from(now.millisecondsSinceEpoch ~/ 1000);

      final schoolId = ObjectId().oid;
      final countyVal = _selectedCounty!.number;
      final mottoVal = _mottoCtrl.text.trim();
      final phoneVal = _phoneCtrl.text.trim();
      final emailVal = _emailCtrl.text.trim();
      final domainVal = _domainCtrl.text.trim();

      final schoolCompanion = SchoolsCompanion(
        id: Value(schoolId),
        name: Value(_nameCtrl.text.trim()),
        motto: Value(mottoVal.isEmpty ? null : mottoVal),
        phone: Value(phoneVal.isEmpty ? null : phoneVal),
        email: Value(emailVal.isEmpty ? null : emailVal),
        county: Value(countyVal),
        domain: Value(domainVal.isEmpty ? null : domainVal),
        established: Value(_establishedDays),
        status: const Value(SchoolStatus.trial),
        created: Value(nowSeconds),
        updated: Value(nowSeconds),
      );

      UsersData ownerUser;

      if (latestUser != null) {
        // Existing user found — use directly.
        ownerUser = latestUser;

        await schoolsDao.createSchool(
          school: schoolCompanion,
          ownerUser: ownerUser,
          accountId: accountId,
        );
      } else {
        // New user — create an invited user first, then the school.
        final ownerUserId = ObjectId().oid;
        final ownerName = _ownerNameCtrl.text.trim();
        final ownerEmail = _ownerEmailCtrl.text.trim();

        await usersDao.inviteUser(
          UsersCompanion(
            id: Value(ownerUserId),
            phone: Value(phone),
            name: Value(ownerName),
            email: Value(ownerEmail.isEmpty ? null : ownerEmail),
            level: const Value(UserLevel.normal),
            status: const Value(UserStatus.invited),
            created: Value(nowSeconds),
            updated: Value(nowSeconds),
          ),
          accountId: accountId,
        );

        // Fetch the freshly created user row to pass to createSchool.
        ownerUser = (await usersDao.getUser(ownerUserId))!;

        await schoolsDao.createSchool(
          school: schoolCompanion,
          ownerUser: ownerUser,
          accountId: accountId,
        );
      }

      // Save logo to local cache if one was picked.
      if (_logoImage != null) {
        final bytes = await _logoImage!.readAsBytes();
        await FileCache.saveBytes(bytes, FileCache.logoPath(schoolId));
        await schoolsDao.logLogoChange(schoolId, accountId: accountId);
      }

      if (!mounted) return;

      final schoolName = _nameCtrl.text.trim();

      // Fetch the created school row.
      final created = await schoolsDao.getSchool(schoolId);
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("School '$schoolName' created."),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to the new school's detail page.
      if (created != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SchoolDetailScreen(
              school: created,
              permissions: widget.permissions,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create school: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickEstablishedDate() async {
    final now = DateTime.now();
    final picked = await showInlineDatePicker(
      context: context,
      initialDate: _establishedDays != null
          ? DateTime.fromMillisecondsSinceEpoch(
              _establishedDays! * 86400 * 1000,
              isUtc: true,
            )
          : now,
      firstDate: DateTime(1800),
      lastDate: now,
      title: 'Established date',
    );
    if (picked == null || !mounted) return;

    // Convert to days since Unix epoch (UTC).
    final days = picked.toUtc().millisecondsSinceEpoch ~/ (86400 * 1000);
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    setState(() {
      _establishedDays = days;
      _establishedLabel =
          '${picked.day} ${months[picked.month - 1]} ${picked.year}';
    });
  }

  // ── County picker ───────────────────────────────────────────────────────────

  Future<void> _openCountyPicker() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showEduSheet<KenyaCounty>(
      context: context,
      builder: (_) => _CountyPickerSheet(selected: _selectedCounty, cs: cs),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCounty = selected;
        _countyError = null;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          _SheetHandle(cs: cs),

          // Title + step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Text(
                  _step == 0 ? 'Create school' : 'Assign owner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Text(
                  'Step ${_step + 1} of 2',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 20, thickness: 1, color: cs.outlineVariant),

          // Form content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _step == 0
                  ? _Step1Form(
                      nameCtrl: _nameCtrl,
                      mottoCtrl: _mottoCtrl,
                      phoneCtrl: _phoneCtrl,
                      emailCtrl: _emailCtrl,
                      selectedCounty: _selectedCounty,
                      onOpenCountyPicker: _openCountyPicker,
                      domainCtrl: _domainCtrl,
                      logoImage: _logoImage,
                      onPickLogo: _pickLogo,
                      onClearLogo: _clearLogo,
                      establishedLabel: _establishedLabel,
                      onPickDate: _pickEstablishedDate,
                      nameError: _nameError,
                      countyError: _countyError,
                      cs: cs,
                    )
                  : _Step2Form(
                      ownerPhoneCtrl: _ownerPhoneCtrl,
                      ownerNameCtrl: _ownerNameCtrl,
                      ownerEmailCtrl: _ownerEmailCtrl,
                      foundOwner: _foundOwner,
                      ownerNotFound: _ownerNotFound,
                      lookingUp: _lookingUp,
                      onPhoneChanged: _onOwnerPhoneChanged,
                      phoneError: _ownerPhoneError,
                      nameError: _ownerNameError,
                      cs: cs,
                    ),
            ),
          ),

          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: _step == 0
                ? _ActionButton(
                    label: 'Next',
                    loading: false,
                    onTap: _goToStep2,
                    cs: cs,
                  )
                : Row(
                    children: [
                      // Back button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _step = 0),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppTheme.kRadius,
                              ),
                              border: Border.all(
                                color: cs.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _ActionButton(
                          label: 'Create',
                          loading: _submitting,
                          onTap: _submit,
                          cs: cs,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 form — school details
// ─────────────────────────────────────────────────────────────────────────────

class _Step1Form extends StatelessWidget {
  const _Step1Form({
    required this.nameCtrl,
    required this.mottoCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.selectedCounty,
    required this.onOpenCountyPicker,
    required this.domainCtrl,
    required this.logoImage,
    required this.onPickLogo,
    required this.onClearLogo,
    required this.establishedLabel,
    required this.onPickDate,
    required this.nameError,
    required this.countyError,
    required this.cs,
  });

  final TextEditingController nameCtrl;
  final TextEditingController mottoCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final KenyaCounty? selectedCounty;
  final VoidCallback onOpenCountyPicker;
  final TextEditingController domainCtrl;
  final File? logoImage;
  final VoidCallback onPickLogo;
  final VoidCallback onClearLogo;
  final String? establishedLabel;
  final VoidCallback onPickDate;
  final String? nameError;
  final String? countyError;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Logo picker ───────────────────────────────────────────
        const SizedBox(height: 8),
        Center(
          child: _LogoPicker(
            image: logoImage,
            onPick: onPickLogo,
            onClear: onClearLogo,
            cs: cs,
          ),
        ),
        const SizedBox(height: 20),

        // ── Name ─────────────────────────────────────────────────
        _FormField(
          label: 'Name *',
          controller: nameCtrl,
          hint: 'School name',
          error: nameError,
          cs: cs,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Motto',
          controller: mottoCtrl,
          hint: 'Optional',
          cs: cs,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Phone',
          controller: phoneCtrl,
          hint: 'Optional',
          cs: cs,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FormField(
          label: 'Email',
          controller: emailCtrl,
          hint: 'Optional',
          cs: cs,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),

        // ── County picker ─────────────────────────────────────────
        _CountyPicker(
          selected: selectedCounty,
          error: countyError,
          onTap: onOpenCountyPicker,
          cs: cs,
        ),
        const SizedBox(height: 12),

        _FormField(
          label: 'Domain',
          controller: domainCtrl,
          hint: 'Optional — e.g. school.ac.ke',
          cs: cs,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),

        // ── Established date picker ───────────────────────────────
        _FormLabel(label: 'Established', cs: cs),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPickDate,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(color: cs.outlineVariant, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    establishedLabel ?? 'Select date (optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: establishedLabel != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 form — owner
// ─────────────────────────────────────────────────────────────────────────────

class _Step2Form extends StatelessWidget {
  const _Step2Form({
    required this.ownerPhoneCtrl,
    required this.ownerNameCtrl,
    required this.ownerEmailCtrl,
    required this.foundOwner,
    required this.ownerNotFound,
    required this.lookingUp,
    required this.onPhoneChanged,
    required this.phoneError,
    required this.nameError,
    required this.cs,
  });

  final TextEditingController ownerPhoneCtrl;
  final TextEditingController ownerNameCtrl;
  final TextEditingController ownerEmailCtrl;
  final UsersData? foundOwner;
  final bool ownerNotFound;
  final bool lookingUp;
  final void Function(String) onPhoneChanged;
  final String? phoneError;
  final String? nameError;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Instruction text ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Enter the owner\'s phone number to look them up. If no account is '
            'found, you can register a new user.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ),

        // ── Phone field ───────────────────────────────────────────
        _FormField(
          label: 'Owner phone *',
          controller: ownerPhoneCtrl,
          hint: 'e.g. +254712345678',
          error: phoneError,
          cs: cs,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: onPhoneChanged,
        ),
        const SizedBox(height: 12),

        // ── Lookup state ──────────────────────────────────────────
        if (lookingUp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Looking up…',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          )
        else if (foundOwner != null) ...[
          // ── Found user card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(color: cs.outlineVariant, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      _initials(foundOwner!.name),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foundOwner!.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                        ),
                      ),
                      if (foundOwner!.email != null)
                        Text(
                          foundOwner!.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: AppTheme.brandGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (ownerNotFound) ...[
          // ── Not found — create new user fields ──────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.tertiary.withValues(alpha: 0.2)),
            ),
            child: Text(
              'No account found. Fill in the details below to invite a new user.',
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
          _FormField(
            label: 'Name *',
            controller: ownerNameCtrl,
            hint: 'Full name',
            error: nameError,
            cs: cs,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'Email',
            controller: ownerEmailCtrl,
            hint: 'Optional',
            cs: cs,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 12),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo picker widget
// ─────────────────────────────────────────────────────────────────────────────

/// A square 64×64 container with dashed border. Shows the selected image if
/// one is picked, or a camera icon + "Add logo" label otherwise.
/// A small ×-badge in the top-right corner allows clearing a picked image.
class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.image,
    required this.onPick,
    required this.onClear,
    required this.cs,
  });

  final File? image;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 1,
                  // dashed border approximated with a solid thin border;
                  // true dashed borders require a custom painter which is
                  // heavier — the thin solid border reads as minimal/clean.
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: image != null && image!.existsSync()
                  ? Image.file(image!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 22,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add logo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // Clear button — only shown when an image is picked.
          if (image != null)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// County picker inline widget (tappable field-shaped row)
// ─────────────────────────────────────────────────────────────────────────────

class _CountyPicker extends StatelessWidget {
  const _CountyPicker({
    required this.selected,
    required this.onTap,
    required this.cs,
    this.error,
  });

  final KenyaCounty? selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label: 'County *', cs: cs),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              border: Border.all(
                color: error != null ? cs.error : cs.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? 'Select county',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: selected != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error!, style: TextStyle(fontSize: 12, color: cs.error)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// County picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CountyPickerSheet extends StatefulWidget {
  const _CountyPickerSheet({required this.selected, required this.cs});

  final KenyaCounty? selected;
  final ColorScheme cs;

  @override
  State<_CountyPickerSheet> createState() => _CountyPickerSheetState();
}

class _CountyPickerSheetState extends State<_CountyPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<KenyaCounty> _filtered = KenyaCounty.values;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? KenyaCounty.values
          : KenyaCounty.values
                .where((c) => c.label.toLowerCase().contains(q))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          _SheetHandle(cs: cs),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Text(
                  'Counties',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 16, thickness: 1, color: cs.outlineVariant),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
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
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),

          // County list
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final county = _filtered[index];
                final isSelected = county == widget.selected;
                return _CountyRow(
                  county: county,
                  isSelected: isSelected,
                  cs: cs,
                  onTap: () => Navigator.of(context).pop(county),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountyRow extends StatelessWidget {
  const _CountyRow({
    required this.county,
    required this.isSelected,
    required this.cs,
    required this.onTap,
  });

  final KenyaCounty county;
  final bool isSelected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // County number badge
              SizedBox(
                width: 28,
                child: Text(
                  county.number.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                Icon(Icons.check_rounded, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.cs,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ColorScheme cs;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label: label, cs: cs),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            errorText: error,
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(
                color: cs.brightness == Brightness.dark
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.primary, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kRadius),
              borderSide: BorderSide(color: cs.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: loading ? cs.primary.withValues(alpha: 0.5) : cs.primary,
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.onPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
