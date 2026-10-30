import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';

class CreateJobScreen extends StatefulWidget {
  final JobModel? job;

  const CreateJobScreen({super.key, this.job});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _company = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _url = TextEditingController();

  String _jobType = 'full_time';
  DateTime? _deadline;
  bool _saving = false;

  // Starting values, used to detect unsaved changes.
  late final String _initialJobType;
  late final DateTime? _initialDeadline;

  bool get _editing => widget.job != null;

  static const _months = [
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

  static const _jobTypes = <({String value, String label, IconData icon})>[
    (value: 'full_time', label: 'Full-time', icon: Icons.work_rounded),
    (value: 'part_time', label: 'Part-time', icon: Icons.schedule_rounded),
    (value: 'internship', label: 'Internship', icon: Icons.school_outlined),
    (value: 'contract', label: 'Contract', icon: Icons.assignment_outlined),
  ];

  @override
  void initState() {
    super.initState();

    final job = widget.job;

    if (job != null) {
      _title.text = job.title;
      _company.text = job.company;
      _description.text = job.description;
      _location.text = job.location ?? '';
      _url.text = job.applicationUrl ?? '';
      _jobType = job.jobType;

      if (job.deadline != null) {
        _deadline = DateTime.tryParse(job.deadline!);
      }
    }

    _initialJobType = _jobType;
    _initialDeadline = _deadline;
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _description.dispose();
    _location.dispose();
    _url.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// Values the form started with (empty when creating a new job).
  Map<TextEditingController, String> get _initialTexts {
    final job = widget.job;

    return {
      _title: job?.title ?? '',
      _company: job?.company ?? '',
      _description: job?.description ?? '',
      _location: job?.location ?? '',
      _url: job?.applicationUrl ?? '',
    };
  }

  bool get _isDirty {
    final textChanged = _initialTexts.entries.any(
      (e) => e.key.text.trim() != e.value.trim(),
    );

    return textChanged ||
        _jobType != _initialJobType ||
        _deadline != _initialDeadline;
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // An old deadline (when editing) is before firstDate; showDatePicker would
    // throw if it were used as initialDate, so fall back to today.
    final initial = (_deadline != null && !_deadline!.isBefore(today))
        ? _deadline!
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(now.year + 10),
      helpText: 'SELECT APPLICATION DEADLINE',
      cancelText: 'CANCEL',
      confirmText: 'SELECT DATE',
    );

    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  void _setDeadlineInDays(int days) {
    final now = DateTime.now();
    setState(() {
      _deadline = DateTime(now.year, now.month, now.day + days);
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// "Today", "Tomorrow", "In 14 days" or "Already passed".
  String _relativeDeadline(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;

    if (days < 0) return 'Already passed';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fix the highlighted fields.', error: true);
      return;
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'company': _company.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
      'job_type': _jobType,
      'application_url': _url.text.trim().isEmpty ? null : _url.text.trim(),
      'deadline': _deadline == null
          ? null
          : '${_deadline!.year.toString().padLeft(4, '0')}-'
                '${_deadline!.month.toString().padLeft(2, '0')}-'
                '${_deadline!.day.toString().padLeft(2, '0')}',
    };

    try {
      final provider = context.read<JobProvider>();

      final success = _editing
          ? await provider.updateJob(widget.job!.jobId, data)
          : await provider.createJob(data);

      if (!mounted) return;

      if (success) {
        _showSnack(
          _editing ? 'Job updated successfully' : 'Job published successfully',
        );

        Navigator.pop(context);
      } else {
        setState(() => _saving = false);

        _showSnack(provider.error ?? 'Could not save job', error: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      _showSnack('Something went wrong. Please try again.', error: true);
    }
  }

  /// Asks before leaving with unsaved changes.
  Future<void> _handleBack() async {
    if (_saving) return;

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
          style: TextStyle(fontWeight: FontWeight.w800, color: AuthPalette.ink),
        ),
        content: Text(
          _editing
              ? 'You have unsaved changes. If you leave now, they will be '
                    'lost.'
              : 'Your job has not been published yet. If you leave now, '
                    'what you wrote will be lost.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AuthPalette.textMuted, height: 1.4),
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

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
        appBar: AppBar(
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
          title: Text(
            _editing ? 'Edit job' : 'Post a job',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AuthPalette.ink,
            ),
          ),
        ),
        body: Column(
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
                    _buildPreview(),
                    const SizedBox(height: 16),
                    _SectionCard(
                      icon: Icons.work_outline_rounded,
                      title: 'Job information',
                      subtitle: 'Tell candidates about the role.',
                      children: [
                        _field(
                          controller: _title,
                          label: 'Job title',
                          hint: 'e.g. Flutter Developer',
                          icon: Icons.badge_outlined,
                          required: true,
                          capitalization: TextCapitalization.words,
                        ),
                        _field(
                          controller: _company,
                          label: 'Company name',
                          hint: 'e.g. Acme Technologies',
                          icon: Icons.business_outlined,
                          required: true,
                          capitalization: TextCapitalization.words,
                        ),
                        _field(
                          controller: _description,
                          label: 'Job description',
                          hint:
                              'Responsibilities, requirements, skills and '
                              'benefits...',
                          required: true,
                          maxLines: 7,
                          capitalization: TextCapitalization.sentences,
                          showCounter: true,
                        ),
                      ],
                    ),
                    _SectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Employment details',
                      subtitle: 'Help candidates understand the position.',
                      children: [
                        _field(
                          controller: _location,
                          label: 'Location',
                          hint: 'e.g. Karachi or Remote',
                          icon: Icons.place_outlined,
                          capitalization: TextCapitalization.words,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Employment type',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AuthPalette.ink,
                            ),
                          ),
                        ),
                        _buildTypePicker(),
                        const SizedBox(height: 14),
                      ],
                    ),
                    _SectionCard(
                      icon: Icons.send_outlined,
                      title: 'Application details',
                      subtitle: 'Make it easy for candidates to apply.',
                      children: [
                        _field(
                          controller: _url,
                          label: 'Application URL',
                          hint: 'https://example.com/apply',
                          icon: Icons.link_rounded,
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            final url = value?.trim() ?? '';

                            if (url.isEmpty) return null;

                            final uri = Uri.tryParse(url);

                            if (uri == null ||
                                !uri.hasAuthority ||
                                !(uri.scheme == 'https' ||
                                    uri.scheme == 'http') ||
                                uri.host.isEmpty ||
                                !uri.host.contains('.')) {
                              return 'Enter a valid URL starting with '
                                  'http:// or https://';
                            }

                            return null;
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Application deadline',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AuthPalette.ink,
                            ),
                          ),
                        ),
                        _buildDeadline(),
                        const SizedBox(height: 14),
                      ],
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Fields marked with * are required',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AuthPalette.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  // --- Live preview -----------------------------------------------------------

  /// Shows how the job will look in the jobs list, updating as you type.
  Widget _buildPreview() {
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _company, _location]),
      builder: (context, child) {
        final title = _title.text.trim();
        final company = _company.text.trim();
        final location = _location.text.trim();
        final type = _jobTypes.firstWhere((t) => t.value == _jobType);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuthPalette.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: AuthPalette.brass.withOpacity(0.95),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE PREVIEW',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AuthPalette.brass.withOpacity(0.95),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AuthPalette.inkLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        company.isNotEmpty ? company[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'Job title' : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: title.isEmpty
                                  ? AuthPalette.textMuted
                                  : AuthPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company.isEmpty ? 'Company name' : company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AuthPalette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _PreviewChip(
                                icon: Icons.place_outlined,
                                label: location.isEmpty
                                    ? 'Location not specified'
                                    : location,
                              ),
                              _PreviewChip(
                                icon: Icons.schedule_rounded,
                                label: type.label,
                                highlight: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Job type ---------------------------------------------------------------

  Widget _buildTypePicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final type in _jobTypes)
              SizedBox(
                width: itemWidth,
                child: _TypeTile(
                  label: type.label,
                  icon: type.icon,
                  selected: _jobType == type.value,
                  onTap: _saving
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _jobType = type.value);
                        },
                ),
              ),
          ],
        );
      },
    );
  }

  // --- Deadline ---------------------------------------------------------------

  Widget _buildDeadline() {
    final deadline = _deadline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AuthPalette.mist,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _saving ? null : _pickDeadline,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: deadline == null
                          ? Colors.white
                          : AuthPalette.brass,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: deadline == null
                          ? AuthPalette.inkLight
                          : AuthPalette.ink,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deadline == null
                              ? 'Choose a deadline'
                              : _formatDate(deadline),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AuthPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deadline == null
                              ? 'Optional · no deadline set'
                              : _relativeDeadline(deadline),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color:
                                deadline != null &&
                                    _relativeDeadline(deadline) ==
                                        'Already passed'
                                ? AuthPalette.error
                                : AuthPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuthPalette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Quick picks; "Remove" appears once a date is set.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickChip(
              label: '1 week',
              onTap: _saving ? null : () => _setDeadlineInDays(7),
            ),
            _QuickChip(
              label: '2 weeks',
              onTap: _saving ? null : () => _setDeadlineInDays(14),
            ),
            _QuickChip(
              label: '1 month',
              onTap: _saving ? null : () => _setDeadlineInDays(30),
            ),
            if (deadline != null)
              _QuickChip(
                label: 'Remove',
                icon: Icons.close_rounded,
                danger: true,
                onTap: _saving ? null : () => setState(() => _deadline = null),
              ),
          ],
        ),
      ],
    );
  }

  // --- Fields -----------------------------------------------------------------

  InputDecoration _decoration({
    required String label,
    required String hint,
    IconData? icon,
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
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool required = false,
    int maxLines = 1,
    bool showCounter = false,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            enabled: !_saving,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : 4,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            textInputAction: maxLines == 1
                ? TextInputAction.next
                : TextInputAction.newline,
            decoration: _decoration(
              label: required ? '$label *' : label,
              hint: hint,
              // No icon next to multi-line fields.
              icon: maxLines > 1 ? null : icon,
              alignTop: maxLines > 1,
            ),
            validator:
                validator ??
                (value) {
                  if (required && (value == null || value.trim().isEmpty)) {
                    return '$label is required';
                  }

                  return null;
                },
          ),
          if (showCounter)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final count = value.text.trim().length;

                return Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$count characters',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AuthPalette.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Always visible, so the user never has to scroll to find "Publish".
  Widget _buildSaveBar() {
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
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AuthPalette.ink,
                      ),
                    )
                  : Icon(
                      _editing
                          ? Icons.check_circle_outline_rounded
                          : Icons.publish_rounded,
                    ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : _editing
                    ? 'Save changes'
                    : 'Publish job',
              ),
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
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
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
                Expanded(
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
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AuthPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AuthPalette.ink : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AuthPalette.ink : const Color(0xFFD5DCE6),
            width: 1.4,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: selected ? AuthPalette.brass : AuthPalette.inkLight,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AuthPalette.ink,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: selected
                        ? AuthPalette.brass
                        : const Color(0xFFD5DCE6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AuthPalette.error : AuthPalette.ink;

    return Material(
      color: danger ? AuthPalette.error.withOpacity(0.08) : AuthPalette.mist,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AuthPalette.good : AuthPalette.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AuthPalette.good.withOpacity(0.12)
            : AuthPalette.mist,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
