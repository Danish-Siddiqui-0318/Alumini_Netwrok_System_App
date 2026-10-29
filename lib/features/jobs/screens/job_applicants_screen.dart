import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/auth_palette.dart';

class JobApplicantsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;
  String? _error;
  int? _updatingApplicationId;

  /// The status being applied right now (for the spinner on that segment).
  String? _updatingStatus;

  /// null means "All".
  String? _filter;

  static const _statuses = ['pending', 'reviewed', 'accepted', 'rejected'];

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
    _loadApplicants();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  Future<void> _loadApplicants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.get(
        '/api/jobs/${widget.jobId}/applications',
      );

      final List<dynamic> data = response['applications'] ?? [];

      if (!mounted) return;

      setState(() {
        _applicants = data
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> applicant,
    String status,
  ) async {
    final applicationId = int.tryParse(applicant['application_id'].toString());

    if (applicationId == null) return;

    setState(() {
      _updatingApplicationId = applicationId;
      _updatingStatus = status;
    });

    try {
      await _apiClient.put(
        '/api/applications/$applicationId/status',
        body: {'status': status},
      );

      if (!mounted) return;

      setState(() {
        applicant['status'] = status;
      });

      _showSnack('Application marked as $status');
    } catch (e) {
      if (!mounted) return;

      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingApplicationId = null;
          _updatingStatus = null;
        });
      }
    }
  }

  /// Accepting or rejecting is a decision, so ask first.
  Future<void> _onStatusSelected(
    Map<String, dynamic> applicant,
    String newStatus,
  ) async {
    if (newStatus == 'accepted' || newStatus == 'rejected') {
      final name = applicant['applicant_name']?.toString() ?? 'this applicant';
      final accepting = newStatus == 'accepted';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            accepting ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accepting ? AuthPalette.good : AuthPalette.error,
            size: 34,
          ),
          title: Text(
            accepting ? 'Accept application?' : 'Reject application?',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
            ),
          ),
          content: Text(
            'Mark $name as $newStatus for "${widget.jobTitle}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AuthPalette.textMuted, height: 1.4),
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
                backgroundColor: accepting
                    ? AuthPalette.good
                    : AuthPalette.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: Text(accepting ? 'Accept' : 'Reject'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    await _updateStatus(applicant, newStatus);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (mounted) _showSnack('$label copied');
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
  // Helpers
  // ---------------------------------------------------------------------------

  /// Unknown or missing statuses count as "pending" (same as the old dropdown).
  String _statusOf(Map<String, dynamic> applicant) {
    final raw = applicant['status']?.toString().toLowerCase() ?? 'pending';
    return _statuses.contains(raw) ? raw : 'pending';
  }

  String _label(String status) =>
      '${status[0].toUpperCase()}${status.substring(1)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'reviewed':
        return const Color(0xFF2E6F95);
      case 'accepted':
        return AuthPalette.good;
      case 'rejected':
        return AuthPalette.error;
      default:
        return const Color(0xFFB9811D);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'reviewed':
        return Icons.visibility_rounded;
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarColors.first;
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarColors[sum % _avatarColors.length];
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AuthPalette.mist,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AuthPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      toolbarHeight: 64,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Applicants',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AuthPalette.ink,
            ),
          ),
          Text(
            widget.jobTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AuthPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _applicants.isEmpty) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _ApplicantSkeleton(),
          _ApplicantSkeleton(),
          _ApplicantSkeleton(),
        ],
      );
    }

    if (_error != null && _applicants.isEmpty) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadApplicants,
      );
    }

    if (_applicants.isEmpty) {
      return RefreshIndicator(
        color: AuthPalette.ink,
        onRefresh: _loadApplicants,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 90),
            _StateMessage(
              icon: Icons.people_outline_rounded,
              title: 'No applicants yet',
              message: 'No one has applied for "${widget.jobTitle}" yet.',
              centered: false,
            ),
          ],
        ),
      );
    }

    final filtered = _filter == null
        ? _applicants
        : _applicants.where((a) => _statusOf(a) == _filter).toList();

    return RefreshIndicator(
      color: AuthPalette.ink,
      onRefresh: _loadApplicants,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        // First item is the filter header.
        itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildFilters();

          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 40),
              child: _StateMessage(
                icon: Icons.filter_alt_off_rounded,
                title: 'No ${_label(_filter!).toLowerCase()} applicants',
                message: 'Nobody is in this status right now.',
                actionLabel: 'Show all',
                onAction: () async => setState(() => _filter = null),
                centered: false,
              ),
            );
          }

          return _buildApplicantCard(filtered[index - 1]);
        },
      ),
    );
  }

  Widget _buildFilters() {
    int count(String status) =>
        _applicants.where((a) => _statusOf(a) == status).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _FilterChip(
              label: 'All',
              count: _applicants.length,
              selected: _filter == null,
              color: AuthPalette.ink,
              onTap: () => setState(() => _filter = null),
            ),
            for (final status in _statuses) ...[
              const SizedBox(width: 8),
              _FilterChip(
                label: _label(status),
                count: count(status),
                selected: _filter == status,
                color: _statusColor(status),
                onTap: () => setState(() => _filter = status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> applicant) {
    final name = applicant['applicant_name']?.toString() ?? 'Unknown applicant';
    final email = applicant['applicant_email']?.toString();
    final phone = applicant['applicant_phone']?.toString();
    final coverLetter = applicant['cover_letter']?.toString();
    final resumeUrl = applicant['resume_url']?.toString();

    final status = _statusOf(applicant);
    final statusColor = _statusColor(status);

    final applicationId = int.tryParse(applicant['application_id'].toString());
    final isUpdating = _updatingApplicationId == applicationId;

    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasCover = coverLetter != null && coverLetter.trim().isNotEmpty;
    final hasResume = resumeUrl != null && resumeUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColor(name),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: _label(status),
                icon: _statusIcon(status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ContactChip(
                icon: Icons.mail_outline_rounded,
                label: hasEmail ? email : 'No email provided',
                onTap: hasEmail ? () => _copy(email, 'Email') : null,
              ),
              if (hasPhone)
                _ContactChip(
                  icon: Icons.phone_outlined,
                  label: phone,
                  onTap: () => _copy(phone, 'Phone number'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Cover letter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AuthPalette.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AuthPalette.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: hasCover
                ? _ExpandableText(text: coverLetter.trim())
                : const Text(
                    'No cover letter provided.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AuthPalette.textMuted,
                    ),
                  ),
          ),
          if (hasResume) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(
                color: AuthPalette.mist,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AuthPalette.inkLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resume',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AuthPalette.textMuted,
                          ),
                        ),
                        Text(
                          resumeUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AuthPalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copy(resumeUrl, 'Resume link'),
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthPalette.inkLight,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE9EDF3)),
          const SizedBox(height: 14),
          const Text(
            'Update status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AuthPalette.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _StatusSelector(
            current: status,
            statuses: _statuses,
            updatingStatus: isUpdating ? _updatingStatus : null,
            disabled: isUpdating,
            colorFor: _statusColor,
            iconFor: _statusIcon,
            labelFor: _label,
            onSelected: (newStatus) {
              if (newStatus != status) {
                _onStatusSelected(applicant, newStatus);
              }
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Building blocks
// -----------------------------------------------------------------------------

/// Four-way segmented control; the selected segment takes the status color.
class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.current,
    required this.statuses,
    required this.updatingStatus,
    required this.disabled,
    required this.colorFor,
    required this.iconFor,
    required this.labelFor,
    required this.onSelected,
  });

  final String current;
  final List<String> statuses;
  final String? updatingStatus;
  final bool disabled;
  final Color Function(String) colorFor;
  final IconData Function(String) iconFor;
  final String Function(String) labelFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthPalette.mist,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final status in statuses)
            Expanded(
              child: _Segment(
                label: labelFor(status),
                icon: iconFor(status),
                color: colorFor(status),
                selected: current == status,
                loading: updatingStatus == status,
                enabled: !disabled,
                onTap: () => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = selected || loading;
    final foreground = highlighted ? Colors.white : AuthPalette.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: highlighted ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, size: 18, color: foreground),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: highlighted
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: foreground,
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

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;

  /// Tap to copy; null = not interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: AuthPalette.mist,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AuthPalette.inkLight),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AuthPalette.ink : AuthPalette.textMuted,
                  ),
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: AuthPalette.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
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
                        : color.withOpacity(0.12),
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

/// Long cover letters are cut after 4 lines with a "Read more" toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _maxLines = 4;
  static const _style = TextStyle(
    fontSize: 14.5,
    height: 1.5,
    color: Color(0xFF1F2D3F),
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        if (!painter.didExceedMaxLines) {
          return Text(widget.text, style: _style);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: _style,
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AuthPalette.inkLight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pulsing placeholder card shown during the first load.
class _ApplicantSkeleton extends StatefulWidget {
  const _ApplicantSkeleton();

  @override
  State<_ApplicantSkeleton> createState() => _ApplicantSkeletonState();
}

class _ApplicantSkeletonState extends State<_ApplicantSkeleton>
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
        margin: const EdgeInsets.only(bottom: 16),
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
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _bar,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                _line(width: 140, height: 15),
              ],
            ),
            const SizedBox(height: 16),
            _line(),
            const SizedBox(height: 10),
            _line(width: 220),
            const SizedBox(height: 16),
            _line(height: 52),
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
    this.centered = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  /// false when it already sits inside a scroll view.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
    );

    if (!centered) return content;

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}
