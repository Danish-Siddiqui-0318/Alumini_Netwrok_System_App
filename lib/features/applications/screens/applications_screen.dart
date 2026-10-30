import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/application_model.dart';
import '../providers/application_provider.dart';

/// Broad stage an application is in, used for filters and the summary bar.
enum _Stage { pending, review, accepted, closed }

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  /// null means "All".
  _Stage? _filter;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ApplicationProvider>().loadMyApplications();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalize(String status) => status.toLowerCase().replaceAll(' ', '_');

  _Stage _stageOf(String status) {
    switch (_normalize(status)) {
      case 'accepted':
      case 'approved':
        return _Stage.accepted;

      case 'rejected':
      case 'declined':
      case 'withdrawn':
        return _Stage.closed;

      case 'reviewing':
      case 'under_review':
      case 'shortlisted':
      case 'interview':
      case 'interview_scheduled':
        return _Stage.review;

      default:
        return _Stage.pending;
    }
  }

  String _stageLabel(_Stage stage) {
    switch (stage) {
      case _Stage.pending:
        return 'Pending';
      case _Stage.review:
        return 'In review';
      case _Stage.accepted:
        return 'Accepted';
      case _Stage.closed:
        return 'Closed';
    }
  }

  Color _stageColor(_Stage stage) {
    switch (stage) {
      case _Stage.pending:
        return const Color(0xFFB9811D);
      case _Stage.review:
        return const Color(0xFF2E6F95);
      case _Stage.accepted:
        return AuthPalette.good;
      case _Stage.closed:
        return const Color(0xFF8A94A6);
    }
  }

  /// Color of one specific status (more detailed than the stage color).
  Color _statusColor(String status) {
    switch (_normalize(status)) {
      case 'accepted':
      case 'approved':
        return AuthPalette.good;

      case 'rejected':
      case 'declined':
        return AuthPalette.error;

      case 'shortlisted':
      case 'interview':
      case 'interview_scheduled':
        return const Color(0xFF6B4E9B);

      case 'withdrawn':
        return AuthPalette.textMuted;

      case 'reviewing':
      case 'under_review':
        return const Color(0xFF2E6F95);

      case 'pending':
      case 'submitted':
      default:
        return const Color(0xFFB9811D);
    }
  }

  IconData _statusIcon(String status) {
    switch (_normalize(status)) {
      case 'accepted':
      case 'approved':
        return Icons.check_circle_rounded;

      case 'rejected':
      case 'declined':
        return Icons.cancel_rounded;

      case 'shortlisted':
      case 'interview':
      case 'interview_scheduled':
        return Icons.star_rounded;

      case 'withdrawn':
        return Icons.undo_rounded;

      case 'reviewing':
      case 'under_review':
        return Icons.visibility_rounded;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  /// Completed steps on the tracker (Submitted, In review, Decision).
  int _reachedSteps(String status) {
    switch (_stageOf(status)) {
      case _Stage.pending:
        return 1;
      case _Stage.review:
        return 2;
      case _Stage.accepted:
      case _Stage.closed:
        return 3;
    }
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

  /// "today", "yesterday", "3 days ago", otherwise the full date.
  String _appliedLabel(dynamic value) {
    final date = value == null ? null : DateTime.tryParse(value.toString());
    if (date == null) return 'Applied ${_formatDate(value)}';

    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = today.difference(day).inDays;

    if (days <= 0) return 'Applied today';
    if (days == 1) return 'Applied yesterday';
    if (days < 7) return 'Applied $days days ago';
    return 'Applied ${_formatDate(value)}';
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

  Color _companyColor(String company) {
    if (company.isEmpty) return _avatarColors.first;
    final sum = company.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarColors[sum % _avatarColors.length];
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

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  Future<void> _withdraw(ApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: AuthPalette.error,
          ),
          title: const Text(
            'Withdraw application?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
            ),
          ),
          content: Text(
            'Are you sure you want to withdraw your application '
            'for ${application.jobTitle ?? 'this job'}? '
            'You may not be able to apply again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AuthPalette.textMuted, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
              child: const Text('Keep application'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AuthPalette.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
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

    _showSnack(
      success
          ? 'Application withdrawn successfully'
          : provider.error ?? 'Could not withdraw application',
      error: !success,
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApplicationProvider>();
    final applications = provider.applications;

    return ColoredBox(
      color: AuthPalette.mist,
      child: _buildContent(provider, applications),
    );
  }

  Widget _buildContent(
    ApplicationProvider provider,
    List<ApplicationModel> applications,
  ) {
    if (provider.isLoading && applications.isEmpty) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: const [
          _Header(),
          SizedBox(height: 18),
          _ApplicationSkeleton(),
          _ApplicationSkeleton(),
          _ApplicationSkeleton(),
        ],
      );
    }

    if (provider.error != null && applications.isEmpty) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load applications',
        message: provider.error!,
        actionLabel: 'Try again',
        onAction: () => provider.loadMyApplications(),
      );
    }

    if (applications.isEmpty) {
      return RefreshIndicator(
        color: AuthPalette.ink,
        onRefresh: provider.loadMyApplications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 60),
            const _StateMessage(
              icon: Icons.work_outline_rounded,
              title: 'Your journey starts here',
              message:
                  'You haven’t applied for any jobs yet. Explore available '
                  'opportunities and submit your first application.',
              footer: 'Tip: keep your profile up to date.',
              centered: false,
            ),
          ],
        ),
      );
    }

    // Count per stage.
    final counts = {for (final s in _Stage.values) s: 0};
    for (final a in applications) {
      counts[_stageOf(a.status)] = counts[_stageOf(a.status)]! + 1;
    }

    // If the selected stage became empty (e.g. after withdrawing), show all.
    final activeFilter = (_filter != null && counts[_filter] == 0)
        ? null
        : _filter;

    final visible = activeFilter == null
        ? applications
        : applications
              .where((a) => _stageOf(a.status) == activeFilter)
              .toList();

    return RefreshIndicator(
      color: AuthPalette.ink,
      onRefresh: provider.loadMyApplications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const _Header(),
          const SizedBox(height: 18),
          _buildSummary(applications.length, counts),
          const SizedBox(height: 18),
          _buildFilters(applications.length, counts, activeFilter),
          const SizedBox(height: 16),
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AuthPalette.ink,
                  backgroundColor: Color(0xFFE3E9F1),
                ),
              ),
            ),
          ...visible.map(_buildCard),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Pull down to refresh your applications',
              style: TextStyle(fontSize: 12.5, color: AuthPalette.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // --- Summary ----------------------------------------------------------------

  Widget _buildSummary(int total, Map<_Stage, int> counts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthPalette.ink, AuthPalette.inkLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AuthPalette.ink.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AuthPalette.brass,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.work_history_rounded,
                  color: AuthPalette.ink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total applications',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (counts[_Stage.accepted]! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AuthPalette.good,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${counts[_Stage.accepted]} accepted',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Distribution bar: one colored segment per stage.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                for (final stage in _Stage.values)
                  if (counts[stage]! > 0)
                    Expanded(
                      flex: counts[stage]!,
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.only(right: 2),
                        color: _stageColor(stage),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final stage in _Stage.values)
                if (counts[stage]! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _stageColor(stage),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${counts[stage]} ${_stageLabel(stage).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    int total,
    Map<_Stage, int> counts,
    _Stage? activeFilter,
  ) {
    // Only stages that actually exist are shown.
    final stages = _Stage.values.where((s) => counts[s]! > 0).toList();
    if (stages.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            count: total,
            color: AuthPalette.ink,
            selected: activeFilter == null,
            onTap: () => setState(() => _filter = null),
          ),
          for (final stage in stages) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: _stageLabel(stage),
              count: counts[stage]!,
              color: _stageColor(stage),
              selected: activeFilter == stage,
              onTap: () => setState(() => _filter = stage),
            ),
          ],
        ],
      ),
    );
  }

  // --- Card -------------------------------------------------------------------

  Widget _buildCard(ApplicationModel application) {
    final title = application.jobTitle?.trim().isNotEmpty == true
        ? application.jobTitle!.trim()
        : 'Job title unavailable';

    final company = application.company?.trim().isNotEmpty == true
        ? application.company!.trim()
        : 'Company not specified';

    final location = application.location?.trim() ?? '';
    final status = application.status;
    final normalized = _normalize(status);
    final statusColor = _statusColor(status);
    final isWithdrawn = normalized == 'withdrawn';

    final canWithdraw =
        normalized != 'withdrawn' &&
        normalized != 'rejected' &&
        normalized != 'declined' &&
        normalized != 'accepted' &&
        normalized != 'approved';

    final reached = _reachedSteps(status);
    final isDecision = reached == 3;
    final lastLabel = !isDecision
        ? 'Decision'
        : (_stageOf(status) == _Stage.accepted
              ? 'Accepted'
              : _capitalize(normalized));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _companyColor(company),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  company.isNotEmpty ? company[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AuthPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: _capitalize(status),
                icon: _statusIcon(status),
                color: statusColor,
              ),
              if (location.isNotEmpty)
                _MetaChip(icon: Icons.place_outlined, label: location),
              if (application.appliedAt != null)
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: _appliedLabel(application.appliedAt),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE9EDF3)),
          const SizedBox(height: 14),
          if (isWithdrawn)
            const Row(
              children: [
                Icon(
                  Icons.undo_rounded,
                  size: 18,
                  color: AuthPalette.textMuted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You withdrew this application.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: AuthPalette.textMuted,
                    ),
                  ),
                ),
              ],
            )
          else
            _ProgressTrack(
              reached: reached,
              color: statusColor,
              lastLabel: lastLabel,
              lastIcon: isDecision
                  ? (_stageOf(status) == _Stage.accepted
                        ? Icons.check_rounded
                        : Icons.close_rounded)
                  : null,
            ),
          if (canWithdraw) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _withdraw(application),
                style: TextButton.styleFrom(
                  foregroundColor: AuthPalette.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: const Text('Withdraw'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My applications',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AuthPalette.ink,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Track your job applications and their progress.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AuthPalette.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Submitted -> In review -> Decision, filled up to the current stage.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.reached,
    required this.color,
    required this.lastLabel,
    this.lastIcon,
  });

  final int reached; // 1..3
  final Color color;
  final String lastLabel;
  final IconData? lastIcon;

  static const _grey = Color(0xFFD5DCE6);

  @override
  Widget build(BuildContext context) {
    final labels = ['Submitted', 'In review', lastLabel];

    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i < reached ? color : _grey),
                      ),
                    ),
                    _node(i),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 2
                            ? Colors.transparent
                            : (i + 1 < reached ? color : _grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: i < reached ? FontWeight.w800 : FontWeight.w500,
                    color: i < reached
                        ? AuthPalette.ink
                        : AuthPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _node(int index) {
    final done = index < reached;
    final isLast = index == 2;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: done ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: done ? color : _grey, width: 2),
      ),
      child: done
          ? Icon(
              isLast && lastIcon != null ? lastIcon : Icons.check_rounded,
              size: 13,
              color: Colors.white,
            )
          : null,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AuthPalette.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AuthPalette.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AuthPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : const Color(0xFFD5DCE6)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AuthPalette.ink,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.25)
                        : color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder card shown during the first load.
class _ApplicationSkeleton extends StatefulWidget {
  const _ApplicationSkeleton();

  @override
  State<_ApplicationSkeleton> createState() => _ApplicationSkeletonState();
}

class _ApplicationSkeletonState extends State<_ApplicationSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  static const _bar = Color(0xFFE6EBF1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _line({double? width, double height = 12}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _bar,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(width: 160, height: 15),
                    const SizedBox(height: 8),
                    _line(width: 100),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _line(width: 80, height: 26),
                const SizedBox(width: 8),
                _line(width: 100, height: 26),
              ],
            ),
            const SizedBox(height: 18),
            _line(height: 22),
          ],
        ),
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
    this.footer,
    this.centered = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final String? footer;

  /// false when it already sits inside a scroll view.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 46, color: AuthPalette.inkLight),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AuthPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AuthPalette.textMuted, height: 1.55),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              backgroundColor: AuthPalette.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              footer!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AuthPalette.ink,
              ),
            ),
          ),
        ],
      ],
    );

    if (!centered) return content;

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}
