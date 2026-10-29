import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/application_provider.dart';
import '../models/application_model.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ApplicationProvider>().loadMyApplications();
      }
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

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

  String _capitalize(String value) {
    if (value.isEmpty) return 'Unknown';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'accepted':
      case 'approved':
        return const Color(0xFF16804A);

      case 'rejected':
      case 'declined':
        return const Color(0xFFCF3D4F);

      case 'shortlisted':
      case 'interview':
      case 'interview_scheduled':
        return const Color(0xFF6554C0);

      case 'withdrawn':
        return const Color(0xFF737373);

      case 'reviewing':
      case 'under_review':
        return const Color(0xFF1976D2);

      case 'pending':
      case 'submitted':
      default:
        return const Color(0xFFB7791F);
    }
  }

  Future<void> _withdraw(ApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: colors.error,
          ),
          title: const Text('Withdraw application?'),
          content: Text(
            'Are you sure you want to withdraw your application '
            'for ${application.jobTitle ?? 'this job'}? '
            'You may not be able to apply again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep application'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<ApplicationProvider>();

    final success = await provider.withdrawApplication(
      application.applicationId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          success
              ? 'Application withdrawn successfully'
              : provider.error ?? 'Could not withdraw application',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApplicationProvider>();
    final applications = provider.applications;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (provider.isLoading && applications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && applications.isEmpty) {
      return _errorState(
        context,
        provider.error!,
        () => provider.loadMyApplications(),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadMyApplications,
      child: applications.isEmpty
          ? _emptyState(context)
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                // Header
                Text(
                  'My Applications',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep track of your job applications and their progress.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 22),

                // Summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: 0.78),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.work_history_rounded,
                          color: colors.onPrimary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total applications',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onPrimary.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${applications.length}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.trending_up_rounded,
                        color: colors.onPrimary,
                        size: 30,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your applications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${applications.length} total',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),

                // Application cards
                ...applications.map(
                  (application) => _applicationCard(context, application),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Pull down to refresh your applications',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _applicationCard(BuildContext context, ApplicationModel application) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final title = application.jobTitle?.trim().isNotEmpty == true
        ? application.jobTitle!.trim()
        : 'Job title unavailable';

    final company = application.company?.trim().isNotEmpty == true
        ? application.company!.trim()
        : 'Company not specified';

    final location = application.location?.trim() ?? '';
    final status = application.status;
    final statusColor = _statusColor(status);

    final normalizedStatus = status.toLowerCase().replaceAll(' ', '_');

    final canWithdraw =
        normalizedStatus != 'withdrawn' &&
        normalizedStatus != 'rejected' &&
        normalizedStatus != 'declined' &&
        normalizedStatus != 'accepted' &&
        normalizedStatus != 'approved';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.business_center_rounded,
                    color: colors.onPrimaryContainer,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          company,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 17),

            // Location and applied date
            if (location.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      location,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            if (application.appliedAt != null)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Applied ${_formatDate(application.appliedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.7),
            ),

            const SizedBox(height: 14),

            // Status and actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _capitalize(status),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (canWithdraw)
                  TextButton.icon(
                    onPressed: () => _withdraw(application),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Withdraw'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(height: constraints.maxHeight * 0.13),
            Center(
              child: Container(
                height: 112,
                width: 112,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.work_outline_rounded,
                  size: 54,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Your journey starts here',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You haven’t applied for any jobs yet. '
              'Explore available opportunities and submit your first application.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Tip: Keep your profile up to date.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }

  Widget _errorState(
    BuildContext context,
    String error,
    Future<void> Function() retry,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: colors.error),
            const SizedBox(height: 18),
            Text(
              'Couldn’t load applications',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => retry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
