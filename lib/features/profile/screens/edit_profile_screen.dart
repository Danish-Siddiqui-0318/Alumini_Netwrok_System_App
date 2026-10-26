import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _department;
  late final TextEditingController _degree;
  late final TextEditingController _graduationYear;
  late final TextEditingController _company;
  late final TextEditingController _jobTitle;
  late final TextEditingController _location;
  late final TextEditingController _skills;
  late final TextEditingController _linkedin;
  late final TextEditingController _github;

  /// Original text of every field, used to detect unsaved changes.
  late final Map<TextEditingController, String> _initialValues;

  static final _urlPattern = RegExp(
    r'^(https?:\/\/)?([\w-]+\.)+[a-z]{2,}(\/\S*)?$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    final p = widget.profile;

    _bio = TextEditingController(text: p.bio ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _department = TextEditingController(text: p.department ?? '');
    _degree = TextEditingController(text: p.degree ?? '');
    _graduationYear = TextEditingController(
      text: p.graduationYear?.toString() ?? '',
    );
    _company = TextEditingController(text: p.currentCompany ?? '');
    _jobTitle = TextEditingController(text: p.jobTitle ?? '');
    _location = TextEditingController(text: p.location ?? '');
    _skills = TextEditingController(text: p.skills ?? '');
    _linkedin = TextEditingController(text: p.linkedinUrl ?? '');
    _github = TextEditingController(text: p.githubUrl ?? '');

    _initialValues = {
      for (final c in [
        _bio,
        _phone,
        _department,
        _degree,
        _graduationYear,
        _company,
        _jobTitle,
        _location,
        _skills,
        _linkedin,
        _github,
      ])
        c: c.text.trim(),
    };
  }

  @override
  void dispose() {
    _bio.dispose();
    _phone.dispose();
    _department.dispose();
    _degree.dispose();
    _graduationYear.dispose();
    _company.dispose();
    _jobTitle.dispose();
    _location.dispose();
    _skills.dispose();
    _linkedin.dispose();
    _github.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  bool get _isDirty {
    return _initialValues.entries.any(
          (entry) => entry.key.text.trim() != entry.value,
    );
  }

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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fix the highlighted fields.', error: true);
      return;
    }

    final yearText = _graduationYear.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);

    if (yearText.isNotEmpty && year == null) {
      _showSnack('Enter a valid graduation year.', error: true);
      return;
    }

    final old = widget.profile;

    final updated = ProfileModel(
      userId: old.userId,
      name: old.name,
      role: old.role,
      isVerified: old.isVerified,
      profilePicture: old.profilePicture,
      bio: _bio.text.trim(),
      phone: _phone.text.trim(),
      department: _department.text.trim(),
      degree: _degree.text.trim(),
      graduationYear: year,
      currentCompany: _company.text.trim(),
      jobTitle: _jobTitle.text.trim(),
      location: _location.text.trim(),
      skills: _skills.text.trim(),
      linkedinUrl: _linkedin.text.trim(),
      githubUrl: _github.text.trim(),
    );

    final provider = context.read<ProfileProvider>();
    final success = await provider.saveProfile(updated);

    if (!mounted) return;

    if (success) {
      _showSnack('Profile saved successfully.');
      Navigator.pop(context);
    } else {
      _showSnack(
        provider.errorMessage ?? 'Failed to save profile.',
        error: true,
      );
    }
  }

  /// Asks before leaving with unsaved changes.
  Future<void> _handleBack() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.edit_off_rounded,
          color: AuthPalette.error,
          size: 32,
        ),
        title: const Text(
          'Discard changes?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AuthPalette.ink,
          ),
        ),
        content: const Text(
          'You have unsaved changes. If you leave now, they will be lost.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AuthPalette.textMuted, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AuthPalette.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  List<String> _parseSkills(String text) {
    return text
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _removeSkill(int index) {
    final skills = _parseSkills(_skills.text)..removeAt(index);
    _skills.text = skills.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Validators
  // ---------------------------------------------------------------------------

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;

    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateYear(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;

    final year = int.tryParse(v);
    final maxYear = DateTime.now().year + 8;

    if (year == null || year < 1950 || year > maxYear) {
      return 'Enter a year between 1950 and $maxYear';
    }
    return null;
  }

  String? _validateUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;

    return _urlPattern.hasMatch(v) ? null : 'Enter a valid link';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  InputDecoration _decoration(
      String label, {
        IconData? icon,
        String? hint,
        bool alignTop = false,
      }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: AuthPalette.textMuted.withOpacity(0.7)),
      alignLabelWithHint: alignTop,
      labelStyle: const TextStyle(color: AuthPalette.textMuted),
      floatingLabelStyle: const TextStyle(
        color: AuthPalette.ink,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AuthPalette.inkLight, size: 22),
      counterText: '',
      filled: true,
      fillColor: AuthPalette.mist,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: border(Colors.transparent),
      disabledBorder: border(Colors.transparent),
      focusedBorder: border(AuthPalette.ink, 1.6),
      errorBorder: border(AuthPalette.error),
      focusedErrorBorder: border(AuthPalette.error, 1.6),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    IconData? icon,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        inputFormatters: formatters,
        validator: validator,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: _decoration(
          label,
          // Icons look odd next to multi-line fields, so skip them there.
          icon: maxLines > 1 ? null : icon,
          hint: hint,
          alignTop: maxLines > 1,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AuthPalette.mist,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AuthPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: _handleBack,
      ),
      title: const Text(
        'Edit profile',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AuthPalette.ink,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back button and system back both go through _handleBack.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AuthPalette.mist,
        appBar: _buildAppBar(),
        body: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            final enabled = !provider.isSaving;

            return Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _SectionCard(
                          icon: Icons.person_outline_rounded,
                          title: 'About you',
                          children: [
                            _field(
                              label: 'Bio',
                              controller: _bio,
                              enabled: enabled,
                              hint: 'Tell the community a little about you',
                              maxLines: 4,
                              capitalization: TextCapitalization.sentences,
                            ),
                          ],
                        ),
                        _SectionCard(
                          icon: Icons.school_outlined,
                          title: 'Education',
                          children: [
                            _field(
                              label: 'Degree',
                              controller: _degree,
                              enabled: enabled,
                              icon: Icons.workspace_premium_outlined,
                              hint: 'e.g. BSc Computer Science',
                              capitalization: TextCapitalization.words,
                            ),
                            _field(
                              label: 'Department',
                              controller: _department,
                              enabled: enabled,
                              icon: Icons.account_balance_outlined,
                              capitalization: TextCapitalization.words,
                            ),
                            _field(
                              label: 'Graduation year',
                              controller: _graduationYear,
                              enabled: enabled,
                              icon: Icons.event_outlined,
                              hint: 'e.g. 2024',
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _validateYear,
                            ),
                          ],
                        ),
                        _SectionCard(
                          icon: Icons.work_outline_rounded,
                          title: 'Work',
                          children: [
                            _field(
                              label: 'Job title',
                              controller: _jobTitle,
                              enabled: enabled,
                              icon: Icons.badge_outlined,
                              capitalization: TextCapitalization.words,
                            ),
                            _field(
                              label: 'Current company',
                              controller: _company,
                              enabled: enabled,
                              icon: Icons.business_outlined,
                              capitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                        _SectionCard(
                          icon: Icons.contact_phone_outlined,
                          title: 'Contact',
                          children: [
                            _field(
                              label: 'Phone',
                              controller: _phone,
                              enabled: enabled,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              formatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s()]'),
                                ),
                              ],
                              validator: _validatePhone,
                            ),
                            _field(
                              label: 'Location',
                              controller: _location,
                              enabled: enabled,
                              icon: Icons.place_outlined,
                              hint: 'City, Country',
                              capitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                        _SectionCard(
                          icon: Icons.bolt_outlined,
                          title: 'Skills',
                          children: [
                            _field(
                              label: 'Skills',
                              controller: _skills,
                              enabled: enabled,
                              hint: 'Flutter, Python, Public speaking',
                              maxLines: 3,
                              capitalization: TextCapitalization.words,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Separate skills with commas.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AuthPalette.textMuted,
                                ),
                              ),
                            ),
                            // Live preview; tap the x to remove a skill.
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _skills,
                              builder: (context, value, child) {
                                final skills = _parseSkills(value.text);
                                if (skills.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      for (var i = 0; i < skills.length; i++)
                                        InputChip(
                                          label: Text(skills[i]),
                                          onDeleted: enabled
                                              ? () => _removeSkill(i)
                                              : null,
                                          deleteIconColor:
                                          AuthPalette.textMuted,
                                          backgroundColor: AuthPalette.mist,
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(20),
                                          ),
                                          labelStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AuthPalette.ink,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        _SectionCard(
                          icon: Icons.link_rounded,
                          title: 'Links',
                          children: [
                            _field(
                              label: 'LinkedIn URL',
                              controller: _linkedin,
                              enabled: enabled,
                              icon: Icons.link_rounded,
                              hint: 'linkedin.com/in/username',
                              keyboardType: TextInputType.url,
                              validator: _validateUrl,
                            ),
                            _field(
                              label: 'GitHub URL',
                              controller: _github,
                              enabled: enabled,
                              icon: Icons.code_rounded,
                              hint: 'github.com/username',
                              keyboardType: TextInputType.url,
                              validator: _validateUrl,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSaveBar(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Always visible, so the user never has to scroll to find "Save".
  Widget _buildSaveBar(ProfileProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AuthPalette.ink.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: provider.isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.brass,
                foregroundColor: AuthPalette.ink,
                disabledBackgroundColor: AuthPalette.brass.withOpacity(0.55),
                disabledForegroundColor: AuthPalette.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: provider.isSaving
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AuthPalette.ink,
                ),
              )
                  : const Text('Save changes'),
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with an icon + title header, holding a group of fields.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AuthPalette.brass,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: AuthPalette.ink),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AuthPalette.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}