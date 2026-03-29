import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../cache/file_cache.dart';
import '../../../client.dart';
import '../../../core/seeder.dart';
import '../../../database/database.dart';
import '../../../database/tables/enums.dart';
import '../../../models/authenticated.dart';
import '../../../core/grpc_errors.dart';
import '../../../models/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edu_confirm_dialog.dart';
import '../../widgets/edu_form_field.dart';
import '../../widgets/edu_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

/// Full-screen profile and settings page.
///
/// Replaces the old bottom-sheet account menu on the home screen. Contains:
/// - Profile header with large avatar + camera badge (image pick)
/// - Name / email editing via bottom sheets
/// - Phone display-only with a snackbar explanation
/// - Theme toggle (system / light / dark)
/// - "Switch account" button → opens bottom sheet with non-active accounts + add
/// - Logout button
///
/// Primary data source is a [StreamBuilder] on
/// [AccountsDao.watchActiveAccount] so every edit is reflected immediately.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();

  /// Locally picked image that hasn't been synced to the server yet.
  /// Shown immediately in the avatar while the page is open; also written
  /// to the file cache so [UserAvatar] picks it up on other screens.
  File? _pickedImage;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
        );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image picking
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // Image viewer — full-screen lightbox
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _viewImage(String userId) async {
    // Resolve the image to display: locally picked takes priority.
    ImageProvider? provider;
    if (_pickedImage != null) {
      provider = FileImage(_pickedImage!);
    } else {
      final cached = await FileCache.get(FileCache.profilePath(userId));
      if (cached != null) provider = FileImage(cached);
    }

    // No image to show — nothing to open.
    if (provider == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  // Tap anywhere to dismiss.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Centred image — fills width, maintains aspect ratio.
                  Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image(
                        image: provider!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  // Close button top-right.
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(String userId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      final file = File(picked.path);
      setState(() => _pickedImage = file);
      await _cacheLocalImage(file, userId);
      // Log the intent to sync (currently a no-op — P8).
      await accountsDao.logProfileImageChange(userId);
    }
  }

  Future<void> _cacheLocalImage(File file, String userId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final relativePath = FileCache.profilePath(userId);
      final target = File('${appDir.path}/$relativePath');
      final dir = target.parent;
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      await file.copy(target.path);
    } catch (e) {
      debugPrint('Failed to cache profile image locally: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Name editing
  // ─────────────────────────────────────────────────────────────────────────

  void _editName(String userId, String currentName) {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showEduSheet(
      context: context,
      title: 'Edit name',
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = cs.brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kModalRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.viewInsetsOf(ctx).bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EduFormField(
                          controller: controller,
                          label: 'Display name',
                          hint: 'Your name',
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kRadius,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final newName = controller.text.trim();
                              await accountsDao.updateName(userId, newName);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Email editing
  // ─────────────────────────────────────────────────────────────────────────

  void _editEmail(String userId, String? currentEmail) {
    final controller = TextEditingController(text: currentEmail ?? '');
    final formKey = GlobalKey<FormState>();

    showEduSheet(
      context: context,
      title: 'Edit email',
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = cs.brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kModalRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.viewInsetsOf(ctx).bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EduFormField(
                          controller: controller,
                          label: 'Email address',
                          hint: 'you@example.com',
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            if (!trimmed.contains('@') ||
                                !trimmed.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kRadius,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final raw = controller.text.trim();
                              final email = raw.isEmpty ? null : raw;
                              await accountsDao.updateEmail(userId, email);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Change phone — two-step bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _changePhone(String userId) {
    showEduSheet(
      context: context,
      builder: (ctx) => _ChangePhoneSheet(userId: userId),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Switch account bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showSwitchAccountSheet(Authenticated activeUser) async {
    final allAccounts = await client.accounts();
    // Filter out the active account — only show others.
    final others = allAccounts.values
        .where((a) => a.user.id != activeUser.user.id)
        .toList();

    if (!mounted) return;

    showEduSheet(
      context: context,
      title: 'Switch account',
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final isDark = cs.brightness == Brightness.dark;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: AppTheme.modalBg(isDark, cs),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.kModalRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Other accounts ──────────────────────────────
                      if (others.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Text(
                            'No other accounts on this device.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...others.map((account) {
                          return InkWell(
                            onTap: () async {
                              Navigator.pop(ctx);
                              final result = await client.switchAccount(
                                account.user.id,
                              );
                              if (!mounted) return;
                              if (result == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Session expired. Please log in again.',
                                    ),
                                  ),
                                );
                                _navigateToLogin(replaceAll: true);
                              } else {
                                // Switched — go to home.
                                _navigateToHome();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    userId: account.user.id,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.user.name,
                                          style: theme.textTheme.bodyMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatPhone(account.user.phone),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      // ── Divider ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Divider(
                          indent: 20,
                          endIndent: 20,
                          height: 1,
                          color: cs.outlineVariant,
                        ),
                      ),

                      // ── Add account ─────────────────────────────────
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateToLogin();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 18,
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Add account',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.brandGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout (with confirmation)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Log out',
      message: 'Are you sure you want to log out of this account?',
      confirmLabel: 'Log out',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    await client.logOut();
    if (!mounted) return;
    _navigateToLogin(replaceAll: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete account (with confirmation)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteAccount(String userId) async {
    final confirmed = await showEduConfirmDialog(
      context: context,
      title: 'Delete account',
      message:
          'This will permanently delete your account and all associated data. This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    await accountsDao.deleteUserAccount(userId);
    if (!mounted) return;
    cache.clear();
    _navigateToLogin(replaceAll: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  void _navigateToLogin({bool replaceAll = false}) {
    final route = PageRouteBuilder(
      pageBuilder: (_, _, _) => const LoginScreen(),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    );
    if (replaceAll) {
      Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (r) => false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phone display formatting
  // ─────────────────────────────────────────────────────────────────────────

  String _formatPhone(String phone) {
    // Kenyan 10-digit: 07xx xxx xxx
    if (phone.length == 10) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > AppTheme.kTabletBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SlideTransition(
        position: _slideUp,
        child: FadeTransition(
          opacity: _fadeIn,
          child: StreamBuilder<Authenticated?>(
            stream: accountsDao.watchActiveAccount(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return const Center(child: CircularProgressIndicator());
              }

              Widget content = _buildContent(theme, cs, user, isDesktop);

              if (isDesktop) {
                content = Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: content,
                  ),
                );
              }

              return content;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    ColorScheme cs,
    Authenticated user,
    bool isDesktop,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),

        // ── Profile header ──────────────────────────────────────────────
        _buildProfileHeader(theme, cs, user),

        const SizedBox(height: 32),

        // ── Profile section ─────────────────────────────────────────────
        _buildSectionHeader(theme, cs, 'Profile'),
        const SizedBox(height: 4),
        _buildProfileSection(theme, cs, user, isDesktop),

        const SizedBox(height: 24),

        // ── Preferences section ─────────────────────────────────────────
        _buildSectionHeader(theme, cs, 'Preferences'),
        const SizedBox(height: 4),
        _buildPreferencesSection(theme, cs, user, isDesktop),

        const SizedBox(height: 28),

        // ── Actions ─────────────────────────────────────────────────────
        _buildActionsSection(theme, cs, user, isDesktop),

        const SizedBox(height: 32),

        // ── Version footer ──────────────────────────────────────────────
        // Long-press triggers the hidden demo data seeder.
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: GestureDetector(
              onLongPress: () => _triggerSeeder(user),
              child: Text(
                'eduxal v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hidden seeder trigger (developer / demo use)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _triggerSeeder(Authenticated user) async {
    // 0 = clear & reseed both schools, 1 = add another school
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text(
            'Demo data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          content: const Text(
            'Clear all existing data and load two demo schools, '
            'or add one more school to the existing data.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text(
                'Add school',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: Text(
                'Clear & reseed',
                style: TextStyle(fontWeight: FontWeight.w500, color: cs.error),
              ),
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (choice == 0) {
        print('[Seeder] Starting clearAndSeed for user=${user.user.id}');
        await Seeder.clearAndSeed(db, user.user.id);
        print('[Seeder] clearAndSeed completed successfully');
      } else {
        print('[Seeder] Starting seedAdditional for user=${user.user.id}');
        await Seeder.seedAdditional(db, user.user.id);
        print('[Seeder] seedAdditional completed successfully');
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            choice == 0
                ? 'Demo data loaded (2 schools)'
                : 'Additional school loaded',
            style: const TextStyle(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stack) {
      print('[Seeder] ERROR: $e');
      print('[Seeder] STACK TRACE:\n$stack');

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Seeder error: $e',
            style: const TextStyle(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile header — avatar + name + phone
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(
    ThemeData theme,
    ColorScheme cs,
    Authenticated user,
  ) {
    return Column(
      children: [
        // Avatar taps open the lightbox; camera badge taps open the picker.
        Stack(
          children: [
            GestureDetector(
              onTap: () => _viewImage(user.user.id),
              child: _buildLargeAvatar(cs, user.user.id),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _pickImage(user.user.id),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.user.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: cs.onSurface,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _formatPhone(user.user.phone),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLargeAvatar(ColorScheme cs, String userId) {
    if (_pickedImage != null) {
      return CircleAvatar(
        radius: 56,
        backgroundImage: FileImage(_pickedImage!),
        backgroundColor: cs.surfaceContainer,
      );
    }

    return FutureBuilder<File?>(
      future: FileCache.get(FileCache.profilePath(userId)),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final hasImage = file != null && file.existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: 56,
            backgroundImage: FileImage(file),
            backgroundColor: cs.surfaceContainer,
          );
        }

        return CircleAvatar(
          radius: 56,
          backgroundColor: cs.surfaceContainer,
          child: Icon(Icons.person, size: 48, color: cs.onSurfaceVariant),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(ThemeData theme, ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Profile section — name, email, phone rows
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProfileSection(
    ThemeData theme,
    ColorScheme cs,
    Authenticated user,
    bool isDesktop,
  ) {
    final children = [
      _buildRow(
        theme: theme,
        cs: cs,
        icon: Icons.person_outline_rounded,
        label: 'Name',
        value: user.user.name,
        onTap: () => _editName(user.user.id, user.user.name),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
      _divider(cs),
      _buildRow(
        theme: theme,
        cs: cs,
        icon: Icons.email_outlined,
        label: 'Email',
        value: user.user.email ?? 'Not set',
        valueOpacity: user.user.email == null ? 0.5 : 1.0,
        onTap: () => _editEmail(user.user.id, user.user.email),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
      _divider(cs),
      _buildRow(
        theme: theme,
        cs: cs,
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: _formatPhone(user.user.phone),
        onTap: () => _changePhone(user.user.id),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    ];

    return _sectionContainer(cs, isDesktop, children);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Preferences section — theme toggle
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPreferencesSection(
    ThemeData theme,
    ColorScheme cs,
    Authenticated user,
    bool isDesktop,
  ) {
    return _sectionContainer(cs, isDesktop, [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.brightness_6_outlined,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Theme',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            _ThemeToggle(userId: user.user.id),
          ],
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions section — switch account + log out as simple rows
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActionsSection(
    ThemeData theme,
    ColorScheme cs,
    Authenticated user,
    bool isDesktop,
  ) {
    return _sectionContainer(cs, isDesktop, [
      // ── Switch account ──────────────────────────────────────────────
      InkWell(
        onTap: () => _showSwitchAccountSheet(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Switch account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
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
      ),
      _divider(cs),
      // ── Log out ─────────────────────────────────────────────────────
      InkWell(
        onTap: _confirmLogout,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      _divider(cs),
      // ── Delete account ──────────────────────────────────────────────
      InkWell(
        onTap: () => _confirmDeleteAccount(user.user.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: cs.error.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Delete account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: cs.error.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared row builder
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRow({
    required ThemeData theme,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
    double valueOpacity = 1.0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface.withValues(alpha: valueOpacity),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section container — card on desktop, flat on mobile
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionContainer(
    ColorScheme cs,
    bool isDesktop,
    List<Widget> children,
  ) {
    final isDark = cs.brightness == Brightness.dark;
    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.5)
        : cs.outlineVariant;

    if (isDesktop) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
    }

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

  Widget _divider(ColorScheme cs) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 50,
      color: cs.outlineVariant,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Theme toggle — inline 3-option selector (moved from home screen bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════════

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: accountsDao.watchActiveAccount(),
      builder: (context, snapshot) {
        final currentTheme = snapshot.data?.theme ?? AppThemeMode.system;
        final themeData = Theme.of(context);
        final cs = themeData.colorScheme;
        final isDark = cs.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: isDark
                ? Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                cs,
                icon: Icons.brightness_auto_rounded,
                mode: AppThemeMode.system,
                currentTheme: currentTheme,
                tooltip: 'System',
              ),
              _buildOption(
                cs,
                icon: Icons.light_mode_rounded,
                mode: AppThemeMode.light,
                currentTheme: currentTheme,
                tooltip: 'Light',
              ),
              _buildOption(
                cs,
                icon: Icons.dark_mode_rounded,
                mode: AppThemeMode.dark,
                currentTheme: currentTheme,
                tooltip: 'Dark',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
    ColorScheme cs, {
    required IconData icon,
    required AppThemeMode mode,
    required AppThemeMode currentTheme,
    required String tooltip,
  }) {
    final isSelected = currentTheme == mode;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () async {
          await accountsDao.updateTheme(userId, mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected && cs.brightness == Brightness.dark
                ? Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? cs.onSurface
                : cs.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Change phone — two-step bottom sheet
// ═══════════════════════════════════════════════════════════════════════════════

/// Two-step bottom sheet for changing the user's phone number.
///
/// Step 1 — Enter new phone number → calls [Authentication.changePhone].
/// Step 2 — Enter the 6-digit OTP sent to the new number →
///           calls [Authentication.confirmChangePhone] → persists via
///           [client.saveAccount].
class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet({required this.userId});

  final String userId;

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  // ── Step tracking ──────────────────────────────────────────────────────────
  bool _onOtpStep = false;

  // ── Step 1 state ───────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

  // ── Step 2 state ───────────────────────────────────────────────────────────
  final _otpController = TextEditingController();
  final _otpFormKey = GlobalKey<FormState>();

  /// The verification ID returned by changePhone — required for confirmChangePhone.
  String? _verificationId;

  /// The new phone number the user entered — shown in the OTP step subtitle.
  String _pendingPhone = '';

  // ── Loading / error ────────────────────────────────────────────────────────
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setError(String? msg) => setState(() => _error = msg);
  void _setLoading(bool v) => setState(() => _loading = v);

  // ── Step 1: request OTP ────────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    _setError(null);
    _setLoading(true);

    final phone = _phoneController.text.trim();
    final result = await client.authentication.changePhone(phone);

    if (!mounted) return;
    _setLoading(false);

    switch (result) {
      case Ok(:final value):
        setState(() {
          _verificationId = value.id;
          _pendingPhone = phone;
          _onOtpStep = true;
          _error = null;
        });
      case Err(:final error):
        _setError(error.toFriendlyMessage());
    }
  }

  // ── Step 2: confirm OTP ────────────────────────────────────────────────────

  Future<void> _confirmOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    _setError(null);
    _setLoading(true);

    final code = _otpController.text.trim();
    final result = await client.authentication.confirmChangePhone(
      _verificationId!,
      code,
    );

    if (!mounted) return;
    _setLoading(false);

    switch (result) {
      case Ok(:final value):
        // Persist the updated account (new phone + fresh tokens).
        await client.saveAccount(value);
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number updated successfully.')),
        );
      case Err(:final error):
        _setError(error.toFriendlyMessage());
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg(isDark, cs),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.kModalRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _onOtpStep
                    ? _buildOtpStep(theme, cs)
                    : _buildPhoneStep(theme, cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ────────────────────────────────────────────────────────────

  Widget _buildError(ThemeData theme, ColorScheme cs) {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.kRadius),
          border: Border.all(color: cs.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: cs.error,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: phone entry ────────────────────────────────────────────────────

  Widget _buildPhoneStep(ThemeData theme, ColorScheme cs) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Change phone number',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your new phone number. We\'ll send a verification code to confirm it.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildError(theme, cs),
          TextFormField(
            controller: _phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'New phone number',
              hintText: '+254 7xx xxx xxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
              ),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.length < 7) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.brandGreen.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kRadius),
                ),
              ),
              onPressed: _loading ? null : _requestOtp,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send code'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: OTP entry ──────────────────────────────────────────────────────

  Widget _buildOtpStep(ThemeData theme, ColorScheme cs) {
    return Form(
      key: _otpFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _loading
                    ? null
                    : () => setState(() {
                        _onOtpStep = false;
                        _error = null;
                        _otpController.clear();
                      }),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Verify new number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the 6-digit code sent to $_pendingPhone.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildError(theme, cs),
          TextFormField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Verification code',
              hintText: '------',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.kRadius),
              ),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.length != 6) {
                return 'Enter the 6-digit code';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.brandGreen.withValues(
                  alpha: 0.35,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.kRadius),
                ),
              ),
              onPressed: _loading ? null : _confirmOtp,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
          ),
          const SizedBox(height: 8),
          // Resend link
          Center(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _onOtpStep = false;
                        _error = null;
                        _otpController.clear();
                      });
                    },
              child: Text(
                'Resend or change number',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
