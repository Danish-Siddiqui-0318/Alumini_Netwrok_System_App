import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  bool get _editing => widget.job != null;

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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      helpText: 'SELECT APPLICATION DEADLINE',
      cancelText: 'CANCEL',
      confirmText: 'SELECT DATE',
    );

    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              _editing
                  ? 'Job updated successfully'
                  : 'Job published successfully',
            ),
          ),
        );

        Navigator.pop(context);
      } else {
        setState(() => _saving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(provider.error ?? 'Could not save job'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _editing ? 'Edit job' : 'Create a job',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _editing
                          ? Icons.edit_note_rounded
                          : Icons.work_outline_rounded,
                      color: colors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editing
                              ? 'Update your opportunity'
                              : 'Find your next great hire',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Share the details candidates need to know.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _sectionTitle(
              context,
              'Job information',
              'Tell candidates about the role.',
              Icons.work_outline_rounded,
            ),

            const SizedBox(height: 18),

            _field(
              controller: _title,
              label: 'Job title',
              hint: 'e.g. Flutter Developer',
              icon: Icons.badge_outlined,
              required: true,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            _field(
              controller: _company,
              label: 'Company name',
              hint: 'e.g. Acme Technologies',
              icon: Icons.business_outlined,
              required: true,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            _field(
              controller: _description,
              label: 'Job description',
              hint:
                  'Describe responsibilities, requirements, skills, and benefits...',
              icon: Icons.subject_rounded,
              required: true,
              maxLines: 6,
            ),

            const SizedBox(height: 28),

            _sectionTitle(
              context,
              'Employment details',
              'Help candidates understand the position.',
              Icons.tune_rounded,
            ),

            const SizedBox(height: 18),

            _field(
              controller: _location,
              label: 'Location',
              hint: 'e.g. Karachi or Remote',
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 18),

            Text(
              'Employment type',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = 10.0;
                final itemWidth = (constraints.maxWidth - spacing) / 2;

                return Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: [
                    _jobTypeOption(
                      width: itemWidth,
                      value: 'full_time',
                      label: 'Full-time',
                      icon: Icons.work_rounded,
                    ),
                    _jobTypeOption(
                      width: itemWidth,
                      value: 'part_time',
                      label: 'Part-time',
                      icon: Icons.schedule_rounded,
                    ),
                    _jobTypeOption(
                      width: itemWidth,
                      value: 'internship',
                      label: 'Internship',
                      icon: Icons.school_outlined,
                    ),
                    _jobTypeOption(
                      width: itemWidth,
                      value: 'contract',
                      label: 'Contract',
                      icon: Icons.assignment_outlined,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            _sectionTitle(
              context,
              'Application details',
              'Make it easy for candidates to apply.',
              Icons.send_outlined,
            ),

            const SizedBox(height: 18),

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
                    !(uri.scheme == 'https' || uri.scheme == 'http') ||
                    uri.host.isEmpty ||
                    !uri.host.contains('.')) {
                  return 'Enter a valid URL starting with http:// or https://';
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            Text(
              'Application deadline',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: colors.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deadline == null
                                ? 'Choose a deadline'
                                : _formatDate(_deadline!),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deadline == null
                                ? 'Optional · No deadline set'
                                : 'Last date for applications',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            if (_deadline != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _deadline = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Remove deadline'),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Bottom action area
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                'Fields marked with * are required',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.onSecondaryContainer, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    final colors = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 4,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colors.surfaceContainerLow,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.error, width: 1.7),
        ),
      ),
      validator:
          validator ??
          (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }

            return null;
          },
    );
  }

  Widget _jobTypeOption({
    required double width,
    required String value,
    required String label,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = _jobType == value;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => setState(() => _jobType = value),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
