import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../cache/file_cache.dart';
import '../../../client.dart';
import '../../../core/grpc_errors.dart';
import '../../../database/database.dart' show UsersCompanion;
import '../../../models/authenticated.dart';
import '../../../models/result.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

/// Profile setup screen — name + optional profile image.
///
/// Two entry paths:
/// - [SetupScreen.newUser]: first-time registration. Name is required,
///   no "Skip" button. Calls `client.authentication.setup(token, name)`.
/// - [SetupScreen.existingUser]: returning user. Name pre-filled, "Skip"
///   available. Edits are local DB writes only.
///
/// WhatsApp/YouTube-inspired: circular avatar with camera badge, warm
/// sentence-case copy, rounded borderless inputs, full-width green CTA.
class SetupScreen extends StatefulWidget {
  /// New user flow — token from [VerifyResultRegistered].
  const SetupScreen({super.key, required this.token, required this.phone})
    : authenticated = null,
      profileUploadUrl = null,
      isNewUser = true;

  /// Existing user flow — authenticated from [VerifyResultAuthenticated].
  const SetupScreen.existingUser({
    super.key,
    required this.authenticated,
    this.profileUploadUrl,
  }) : token = '',
       phone = '',
       isNewUser = false;

  /// Registration token (new user flow only).
  final String token;

  /// Phone number for display (new user flow only).
  final String phone;

  /// Pre-existing authenticated session (existing user flow only).
  final Authenticated? authenticated;

  /// Presigned S3 PUT URL for uploading profile image.
  final String? profileUploadUrl;

  /// Whether this is a new user registration or an existing user update.
  final bool isNewUser;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _picker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  File? _pickedImage;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    // Pre-fill name for existing users.
    if (!widget.isNewUser && widget.authenticated != null) {
      _nameController.text = widget.authenticated!.user.name;
    }

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
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isNameValid => _nameController.text.trim().length >= 2;

  String? get _existingUserId => widget.authenticated?.user.id;

  // ─────────────────────────────────────────────────────────────────────────
  // Image picking
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (_isLoading) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image upload (non-fatal)
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads [file] to the presigned S3 PUT URL and, on success, copies the
  /// picked image to the local cache path so [UserAvatar] can display it
  /// immediately without a network round-trip.
  Future<void> _uploadAndCacheImage(
    String uploadUrl,
    File file,
    String userId,
  ) async {
    try {
      final httpClient = HttpClient();
      try {
        final request = await httpClient.putUrl(Uri.parse(uploadUrl));
        final length = await file.length();
        request.headers.set(HttpHeaders.contentLengthHeader, length.toString());
        request.headers.set(HttpHeaders.contentTypeHeader, 'image/jpeg');
        await request.addStream(file.openRead());
        final response = await request.close();

        if (response.statusCode == 200 || response.statusCode == 204) {
          // Copy the picked local file to the cache path directly — do NOT
          // try to GET from the upload URL (PUT-only signed URLs don't support GET).
          await _cacheLocalImage(file, userId);
        } else {
          debugPrint('Profile upload returned ${response.statusCode}');
        }
      } finally {
        httpClient.close(force: false);
      }
    } catch (e) {
      debugPrint('Profile upload failed: $e');
    }
  }

  /// Copies [file] to the local cache path for [userId] so [UserAvatar]
  /// can serve it without a network call.
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
  // Skip (existing user only)
  // ─────────────────────────────────────────────────────────────────────────

  void _skip() {
    _navigateToHome();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isLoading) return;

    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorMessage = 'Name must be at least 2 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.isNewUser) {
      await _handleNewUser(name);
    } else {
      await _handleExistingUser(name);
    }
  }

  Future<void> _handleNewUser(String name) async {
    final result = await client.authentication.setup(widget.token, name);

    if (!mounted) return;

    switch (result) {
      case Ok(value: final setupResult):
        await client.saveAccount(setupResult.authenticated);

        // Upload image if picked and URL available (non-fatal).
        if (_pickedImage != null && setupResult.profileUploadUrl != null) {
          // Fire-and-forget — don't block navigation on upload.
          _uploadAndCacheImage(
            setupResult.profileUploadUrl!,
            _pickedImage!,
            setupResult.authenticated.user.id,
          );
        } else if (_pickedImage != null) {
          // No upload URL but user picked an image — cache it locally so
          // the avatar shows immediately. Upload will happen via sync later.
          _cacheLocalImage(_pickedImage!, setupResult.authenticated.user.id);
        }

        if (!mounted) return;
        _navigateToHome();

      case Err(error: final error):
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = error.toFriendlyMessage();
        });
    }
  }

  Future<void> _handleExistingUser(String name) async {
    try {
      final auth = widget.authenticated;
      if (auth != null) {
        final userId = auth.user.id;
        final currentName = auth.user.name;

        // Update name in local DB if it has changed — build a UsersCompanion
        // directly with the NEW name value.
        if (name != currentName) {
          final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);
          final companion = UsersCompanion(
            id: Value(userId),
            phone: Value(auth.user.phone),
            name: Value(name),
            email: Value(auth.user.email),
            level: Value(auth.user.level),
            status: Value(auth.user.status),
            created: Value(auth.user.created),
            updated: Value(now),
          );
          await accountsDao.updateUser(companion);
        }

        // Upload image if picked and URL available (non-fatal).
        if (_pickedImage != null && widget.profileUploadUrl != null) {
          // Fire-and-forget — don't block navigation on upload.
          _uploadAndCacheImage(widget.profileUploadUrl!, _pickedImage!, userId);
        } else if (_pickedImage != null) {
          // No upload URL available but user picked an image — cache it
          // locally so it shows up in the avatar immediately.
          _cacheLocalImage(_pickedImage!, userId);
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save. Please try again.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (route) => false,
    );
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

    // Desktop: centred card.
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

    // Mobile: full-bleed with optional skip in appbar.
    return Scaffold(
      appBar: widget.isNewUser
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                TextButton(
                  onPressed: _isLoading ? null : _skip,
                  child: const Text('Skip'),
                ),
              ],
            ),
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

  Widget _buildContent(ThemeData theme, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAvatarSection(theme, cs),
        const SizedBox(height: 28),
        _buildHeader(theme, cs),
        const SizedBox(height: 32),
        _buildNameField(theme, cs),
        const SizedBox(height: 24),
        _buildSubmitButton(),
        if (!widget.isNewUser) ...[
          const SizedBox(height: 12),
          _buildDesktopSkip(cs),
        ],
        _buildErrorArea(theme, cs),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Avatar section — circular, WhatsApp-style with camera badge
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAvatarSection(ThemeData theme, ColorScheme cs) {
    const double avatarRadius = 56.0;

    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _pickImage,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: avatarRadius * 2 + 8,
          height: avatarRadius * 2 + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main circular avatar.
              _buildAvatarCircle(cs, avatarRadius),

              // Camera badge — bottom-right, overlapping.
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.brightness == Brightness.light
                          ? Colors.white
                          : Theme.of(context).scaffoldBackgroundColor,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCircle(ColorScheme cs, double radius) {
    // If user picked a new image, show that.
    if (_pickedImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(_pickedImage!),
        backgroundColor: cs.surfaceContainerHighest,
      );
    }

    // For existing users, try to load cached profile image.
    if (_existingUserId != null) {
      return FutureBuilder<File?>(
        future: FileCache.get(FileCache.profilePath(_existingUserId!)),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: FileImage(file),
              backgroundColor: cs.surfaceContainerHighest,
            );
          }
          return _buildPlaceholderCircle(cs, radius);
        },
      );
    }

    return _buildPlaceholderCircle(cs, radius);
  }

  Widget _buildPlaceholderCircle(ColorScheme cs, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: radius * 0.8,
        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header — warm sentence-case, no decorative lines
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    final title = widget.isNewUser ? 'Profile info' : 'Edit profile';
    final subtitle = widget.isNewUser
        ? 'Please provide your name. This will be visible to your school.'
        : 'You can update your name and profile photo.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
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
  // Name field — rounded, borderless fill
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNameField(ThemeData theme, ColorScheme cs) {
    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _submit(),
      onChanged: (_) => setState(() {}),
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: 'Type your name here',
        prefixIcon: Icon(
          Icons.person_outline_rounded,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit button — full-width green CTA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final label = widget.isNewUser ? 'Next' : 'Save';

    return ElevatedButton(
      onPressed: (_isLoading || !_isNameValid) ? null : _submit,
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop skip
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopSkip(ColorScheme cs) {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : _skip,
        child: const Text('Skip for now'),
      ),
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
}
