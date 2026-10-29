import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'create_job_screen.dart';
import 'job_applicants_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final int jobId;

  const JobDetailsScreen({super.key, required this.jobId});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isApplying = false;
  bool _hasApplied = false;

  JobModel? _job;
  Object? _error;
  bool _isLoading = true;

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

  static const _avatarColors = [
    AuthPalette.ink,
    AuthPalette.inkLight,
    Color(0xFF2E6F95),
    Color(0xFF3A7D6B),
    Color(0xFF6B4E9B),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// Loads the job once. (The old FutureBuilder fetched the job again on every
  /// rebuild, e.g. each time you pressed Apply.)
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final job = await context.read<JobProvider>().getJobDetails(widget.jobId);

      if (!mounted) return;
      setState(() => _job = job);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _applyForJob() async {
    if (_isApplying || _hasApplied) return;

    final jobProvider = context.read<JobProvider>();

    setState(() => _isApplying = true);

    try {
      await jobProvider.applyForJob(widget.jobId);

      if (!mounted) return;

      setState(() => _hasApplied = true);

      _showSnack('Application submitted successfully!');
    } catch (e) {
      if (!mounted) return;

      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _deleteJob(JobModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AuthPalette.error,
          size: 32,
        ),
        title: const Text(
          'Delete job?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AuthPalette.ink),
        ),
        content: const Text(
          'Are you sure you want to delete this job? '
          'This action cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AuthPalette.textMuted, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<JobProvider>().deleteJob(job.jobId);

    if (!mounted) return;

    _showSnack(
      success ? 'Job deleted successfully' : 'Failed to delete job',
      error: !success,
    );

    if (success) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _editJob(JobModel job) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateJobScreen(job: job)),
    );

    if (result == true && mounted) {
      await _load();

      // Keep the jobs list in sync with the edit.
      if (mounted) {
        await context.read<JobProvider>().loadJobs();
      }
    }
  }

  void _openApplicants(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            JobApplicantsScreen(jobId: job.jobId, jobTitle: job.title),
      ),
    );
  }

  Future<void> _copyApplicationUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.selectionClick();

    if (mounted) _showSnack('Application URL copied');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _has(String? value) => value != null && value.trim().isNotEmpty;

  Color _companyColor(String company) {
    if (company.isEmpty) return _avatarColors.first;
    final sum = company.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarColors[sum % _avatarColors.length];
  }

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('intern')) return const Color(0xFF2E6F95);
    if (t.contains('part')) return const Color(0xFFB9811D);
    if (t.contains('contract') || t.contains('freelance')) {
      return const Color(0xFF6B4E9B);
    }
    if (t.contains('remote')) return const Color(0xFF1D8A8A);
    if (t.contains('full')) return AuthPalette.good;
    return AuthPalette.textMuted;
  }

  /// Days until the deadline (negative = passed), or null if it can't be read.
  int? _daysLeft(String? deadline) {
    if (!_has(deadline)) return null;

    final parsed = DateTime.tryParse(deadline!.trim());
    if (parsed == null) return null;

    final local = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);

    return day.difference(today).inDays;
  }

  String _formatDeadline(String deadline) {
    final parsed = DateTime.tryParse(deadline.trim());
    if (parsed == null) return deadline;

    final local = parsed.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar({required bool showOwnerMenu}) {
    return AppBar(
      backgroundColor: AuthPalette.mist,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AuthPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: const Text(
        'Job details',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AuthPalette.ink,
        ),
      ),
      actions: [
        if (showOwnerMenu && _job != null)
          PopupMenuButton<String>(
            tooltip: 'Manage job',
            color: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'edit') {
                _editJob(_job!);
              } else if (value == 'delete') {
                _deleteJob(_job!);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AuthPalette.ink),
                    SizedBox(width: 12),
                    Text(
                      'Edit job',
                      style: TextStyle(
                        color: AuthPalette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AuthPalette.error,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete job',
                      style: TextStyle(
                        color: AuthPalette.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final job = _job;

    // Permissions (same rules as before).
    final userId = currentUser?.userId;
    final role = currentUser?.role?.toLowerCase();

    final isAdmin = role == 'admin';
    final isJobOwner = job != null && userId != null && userId == job.postedBy;

    final canManageJob = isAdmin || isJobOwner;
    final canApply =
        job != null &&
        !canManageJob &&
        userId != null &&
        (role == 'student' || role == 'alumni');

    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: _buildAppBar(showOwnerMenu: isJobOwner),
      body: _buildBody(job, canManageJob: canManageJob, canApply: canApply),
      bottomNavigationBar: job == null || (!canManageJob && !canApply)
          ? null
          : _buildBottomBar(job, canManageJob: canManageJob),
    );
  }

  Widget _buildBody(
    JobModel? job, {
    required bool canManageJob,
    required bool canApply,
  }) {
    if (job == null) {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: AuthPalette.ink),
        );
      }

      if (_error != null) {
        return _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load job',
          message: _error.toString().replaceFirst('Exception: ', ''),
          actionLabel: 'Retry',
          onAction: _load,
        );
      }

      return const _StateMessage(
        icon: Icons.work_off_outlined,
        title: 'Job not found',
        message: 'This job may have been removed.',
      );
    }

    return RefreshIndicator(
      color: AuthPalette.ink,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHero(job),
          _SectionCard(
            title: 'About the role',
            child: Text(
              job.description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF1F2D3F),
              ),
            ),
          ),
          if (_has(job.applicationUrl))
            _SectionCard(
              title: 'How to apply',
              child: _buildApplicationLink(job.applicationUrl!.trim()),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(JobModel job) {
    final location = job.location?.trim();
    final hasLocation = location != null && location.isNotEmpty;
    final type = job.formattedJobType;
    final typeColor = _typeColor(type);
    final daysLeft = _daysLeft(job.deadline);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AuthPalette.ink.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _companyColor(job.company),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  job.company.isNotEmpty ? job.company[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AuthPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.place_outlined,
                label: hasLocation ? location : 'Location not specified',
                background: AuthPalette.mist,
                foreground: hasLocation
                    ? AuthPalette.ink
                    : AuthPalette.textMuted,
              ),
              if (type.trim().isNotEmpty)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: type,
                  background: typeColor.withOpacity(0.12),
                  foreground: typeColor,
                  bold: true,
                ),
            ],
          ),
          if (_has(job.deadline)) ...[
            const SizedBox(height: 16),
            _buildDeadline(job.deadline!.trim(), daysLeft),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE9EDF3)),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AuthPalette.inkLight,
                child: Text(
                  (job.posterName ?? 'Alumni')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posted by',
                      style: TextStyle(
                        fontSize: 12,
                        color: AuthPalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      job.posterName ?? 'Alumni',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Deadline banner: turns amber when close and red once it has passed.
  Widget _buildDeadline(String deadline, int? daysLeft) {
    Color color = AuthPalette.inkLight;
    String? status;

    if (daysLeft != null) {
      if (daysLeft < 0) {
        color = AuthPalette.error;
        status = 'Closed';
      } else if (daysLeft == 0) {
        color = const Color(0xFFB9811D);
        status = 'Closes today';
      } else if (daysLeft <= 7) {
        color = const Color(0xFFB9811D);
        status = daysLeft == 1 ? '1 day left' : '$daysLeft days left';
      } else {
        status = '$daysLeft days left';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply before',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.85),
                  ),
                ),
                Text(
                  _formatDeadline(deadline),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationLink(String url) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AuthPalette.mist,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: AuthPalette.inkLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AuthPalette.ink,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _copyApplicationUrl(url),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              foregroundColor: AuthPalette.inkLight,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky action: Apply for students/alumni, View applicants for owners.
  Widget _buildBottomBar(JobModel job, {required bool canManageJob}) {
    final daysLeft = _daysLeft(job.deadline);
    final isClosed = daysLeft != null && daysLeft < 0;

    Widget button;

    if (canManageJob) {
      button = FilledButton.icon(
        onPressed: () => _openApplicants(job),
        icon: const Icon(Icons.people_alt_rounded, size: 20),
        label: const Text('View applicants'),
        style: FilledButton.styleFrom(
          backgroundColor: AuthPalette.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
    } else {
      final disabled = _isApplying || _hasApplied || isClosed;

      button = FilledButton.icon(
        onPressed: disabled ? null : _applyForJob,
        icon: _isApplying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AuthPalette.ink,
                ),
              )
            : Icon(
                _hasApplied
                    ? Icons.check_circle_rounded
                    : isClosed
                    ? Icons.lock_outline_rounded
                    : Icons.send_rounded,
                size: 20,
              ),
        label: Text(
          _hasApplied
              ? 'Application submitted'
              : _isApplying
              ? 'Submitting...'
              : isClosed
              ? 'Applications closed'
              : 'Apply for this job',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AuthPalette.brass,
          foregroundColor: AuthPalette.ink,
          // Different disabled looks: submitted = green, closed = grey.
          disabledBackgroundColor: _hasApplied
              ? AuthPalette.good
              : _isApplying
              ? AuthPalette.brass.withOpacity(0.55)
              : AuthPalette.mist,
          disabledForegroundColor: _hasApplied
              ? Colors.white
              : _isApplying
              ? AuthPalette.ink
              : AuthPalette.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      );
    }

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
          child: SizedBox(width: double.infinity, height: 54, child: button),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks
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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AuthPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
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
