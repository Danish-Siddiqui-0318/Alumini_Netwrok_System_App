import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/auth_palette.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPicture = false;

  final ApiClient _apiClient = ApiClient();

  static const _divider = Color(0xFFE9EDF3);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().loadMyProfile();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AuthPalette.error : AuthPalette.ink,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                color: error ? Colors.white : AuthPalette.brass,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Future<void> _changeProfilePicture() async {
    if (_isUploadingPicture) return;

    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null || !mounted) return;

      setState(() => _isUploadingPicture = true);

      final response = await _apiClient.multipartPost(
        '/profiles/me/profile-picture',
        file: File(image.path),
        fieldName: 'image',
      );

      if (!mounted) return;

      await context.read<ProfileProvider>().loadMyProfile();

      if (!mounted) return;

      _showSnack(
        response['message']?.toString() ??
            'Profile picture updated successfully!',
      );
    } catch (error) {
      if (!mounted) return;

      _showSnack(
        'Could not update picture: '
        '${error.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPicture = false);
      }
    }
  }

  Future<void> _openEdit(ProfileModel profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );

    if (mounted) {
      await context.read<ProfileProvider>().loadMyProfile();
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (mounted) _showSnack('$label copied.');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _has(String? value) => value != null && value.trim().isNotEmpty;

  ImageProvider? _imageProvider(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    return NetworkImage(url);
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '';
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  /// "Software Engineer at Google", or whichever part exists.
  String _headline(ProfileModel profile) {
    final title = profile.jobTitle?.trim() ?? '';
    final company = profile.currentCompany?.trim() ?? '';

    if (title.isNotEmpty && company.isNotEmpty) return '$title at $company';
    return title.isNotEmpty ? title : company;
  }

  /// How many of the profile details are filled in.
  ({int filled, int total}) _completeness(ProfileModel profile) {
    final values = <String?>[
      profile.profilePicture,
      profile.bio,
      profile.phone,
      profile.department,
      profile.degree,
      profile.graduationYear?.toString(),
      profile.currentCompany,
      profile.jobTitle,
      profile.location,
      profile.skills,
      profile.linkedinUrl,
      profile.githubUrl,
    ];

    return (filled: values.where(_has).length, total: values.length);
  }

  List<String> _skillList(String? skills) {
    if (!_has(skills)) return const [];

    return skills!
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuthPalette.mist,
      child: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.profile == null) {
            return const Center(
              child: CircularProgressIndicator(color: AuthPalette.ink),
            );
          }

          if (provider.errorMessage != null && provider.profile == null) {
            return _StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Something went wrong',
              message: provider.errorMessage!,
              actionLabel: 'Retry',
              onAction: provider.loadMyProfile,
            );
          }

          final profile = provider.profile;

          if (profile == null) {
            return const _StateMessage(
              icon: Icons.person_off_outlined,
              title: 'No profile found',
              message: 'We could not find your profile yet.',
            );
          }

          return RefreshIndicator(
            color: AuthPalette.ink,
            onRefresh: provider.loadMyProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildHero(profile),
                ..._buildCompletenessCard(profile),
                ..._buildSections(profile),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Hero -------------------------------------------------------------------

  Widget _buildHero(ProfileModel profile) {
    final headline = _headline(profile);
    final role = profile.role == null ? '' : _formatRole(profile.role!);

    final facts = <(String, String)>[
      if (profile.graduationYear != null)
        ('Class of', profile.graduationYear.toString()),
      if (_has(profile.department)) ('Department', profile.department!.trim()),
      if (_has(profile.location)) ('Location', profile.location!.trim()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AuthPalette.ink.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            // Cover banner with the avatar overlapping its bottom edge.
            Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 112,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AuthPalette.ink, AuthPalette.inkLight],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -30,
                          top: -40,
                          child: _Bubble(
                            size: 140,
                            color: AuthPalette.brass.withOpacity(0.18),
                          ),
                        ),
                        Positioned(
                          left: -24,
                          bottom: -50,
                          child: _Bubble(
                            size: 110,
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: _buildAvatar(profile),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Text(
                    profile.name.isEmpty ? 'Your Profile' : profile.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (headline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AuthPalette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (role.isNotEmpty || profile.isVerified) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (role.isNotEmpty)
                          _Pill(
                            icon: role.toLowerCase() == 'alumni'
                                ? Icons.workspace_premium_rounded
                                : Icons.menu_book_rounded,
                            label: role,
                            background: AuthPalette.mist,
                            foreground: AuthPalette.ink,
                          ),
                        if (profile.isVerified)
                          _Pill(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            background: AuthPalette.brass.withOpacity(0.22),
                            foreground: const Color(0xFF7A5510),
                          ),
                      ],
                    ),
                  ],
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _FactsRow(facts: facts),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => _openEdit(profile),
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      label: const Text('Edit profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AuthPalette.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ProfileModel profile) {
    final image = _imageProvider(profile.profilePicture);
    final initial = profile.name.isNotEmpty
        ? profile.name[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _isUploadingPicture ? null : _changeProfilePicture,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AuthPalette.brass,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: AuthPalette.inkLight,
                backgroundImage: image,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (image == null)
                      Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (_isUploadingPicture)
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AuthPalette.ink.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AuthPalette.brass,
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 16,
                  color: AuthPalette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Completeness -----------------------------------------------------------

  List<Widget> _buildCompletenessCard(ProfileModel profile) {
    final progress = _completeness(profile);
    if (progress.filled >= progress.total) return const [];

    final fraction = progress.filled / progress.total;

    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AuthPalette.brass.withOpacity(0.6),
            width: 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFB9811D),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Complete your profile',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                    ),
                  ),
                ),
                Text(
                  '${(fraction * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AuthPalette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: AuthPalette.mist,
                valueColor: const AlwaysStoppedAnimation(AuthPalette.brass),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${progress.filled} of ${progress.total} details added. '
                    'A full profile helps alumni find you.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AuthPalette.textMuted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openEdit(profile),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthPalette.inkLight,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Add details'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // --- Sections ---------------------------------------------------------------

  List<Widget> _buildSections(ProfileModel profile) {
    final skills = _skillList(profile.skills);

    final education = <Widget>[
      if (_has(profile.degree))
        _InfoRow(
          icon: Icons.school_outlined,
          label: 'Degree',
          value: profile.degree!.trim(),
        ),
      if (_has(profile.department))
        _InfoRow(
          icon: Icons.account_balance_outlined,
          label: 'Department',
          value: profile.department!.trim(),
        ),
      if (profile.graduationYear != null)
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Graduation year',
          value: profile.graduationYear.toString(),
        ),
    ];

    final work = <Widget>[
      if (_has(profile.jobTitle))
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Job title',
          value: profile.jobTitle!.trim(),
        ),
      if (_has(profile.currentCompany))
        _InfoRow(
          icon: Icons.business_outlined,
          label: 'Current company',
          value: profile.currentCompany!.trim(),
        ),
    ];

    final contact = <Widget>[
      if (_has(profile.phone))
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile.phone!.trim(),
          onCopy: () => _copy(profile.phone!.trim(), 'Phone number'),
        ),
      if (_has(profile.location))
        _InfoRow(
          icon: Icons.place_outlined,
          label: 'Location',
          value: profile.location!.trim(),
        ),
    ];

    final links = <Widget>[
      if (_has(profile.linkedinUrl))
        _InfoRow(
          icon: Icons.link_rounded,
          label: 'LinkedIn',
          value: profile.linkedinUrl!.trim(),
          onCopy: () => _copy(profile.linkedinUrl!.trim(), 'LinkedIn link'),
        ),
      if (_has(profile.githubUrl))
        _InfoRow(
          icon: Icons.code_rounded,
          label: 'GitHub',
          value: profile.githubUrl!.trim(),
          onCopy: () => _copy(profile.githubUrl!.trim(), 'GitHub link'),
        ),
    ];

    return [
      if (_has(profile.bio))
        _SectionCard(
          title: 'About',
          child: Text(
            profile.bio!.trim(),
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: Color(0xFF1F2D3F),
            ),
          ),
        ),
      if (education.isNotEmpty)
        _SectionCard(title: 'Education', child: _rows(education)),
      if (work.isNotEmpty) _SectionCard(title: 'Work', child: _rows(work)),
      if (skills.isNotEmpty)
        _SectionCard(
          title: 'Skills',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AuthPalette.mist,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    skill,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (contact.isNotEmpty)
        _SectionCard(title: 'Contact', child: _rows(contact)),
      if (links.isNotEmpty) _SectionCard(title: 'Links', child: _rows(links)),
    ];
  }

  /// Rows separated by thin dividers.
  Widget _rows(List<Widget> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            const Divider(height: 1, thickness: 1, indent: 52, color: _divider),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Small building blocks
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AuthPalette.ink.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;

  /// When set, the row can be tapped to copy its value.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AuthPalette.mist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AuthPalette.inkLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AuthPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AuthPalette.ink,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: AuthPalette.textMuted,
              ),
            ),
        ],
      ),
    );

    if (onCopy == null) return content;

    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AuthPalette.mist,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Text(
                      facts[i].$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      facts[i].$1,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AuthPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != facts.length - 1)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFD5DCE6),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AuthPalette.inkLight),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthPalette.textMuted, height: 1.4),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthPalette.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
