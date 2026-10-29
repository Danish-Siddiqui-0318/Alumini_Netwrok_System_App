import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'create_job_screen.dart';
import 'job_details_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// null means "All".
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<JobProvider>().loadJobs();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openCreateJob() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateJobScreen()),
    );

    // Make sure a freshly posted job shows up in the list.
    if (mounted) {
      await context.read<JobProvider>().loadJobs();
    }
  }

  void _openJob(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsScreen(jobId: job.jobId)),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedType = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<JobModel> _applyFilters(List<JobModel> jobs, String? type) {
    final query = _query.toLowerCase();

    return jobs.where((job) {
      if (type != null && job.formattedJobType != type) return false;
      if (query.isEmpty) return true;

      return job.title.toLowerCase().contains(query) ||
          job.company.toLowerCase().contains(query) ||
          (job.location ?? '').toLowerCase().contains(query);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateJob,
        backgroundColor: AuthPalette.brass,
        foregroundColor: AuthPalette.ink,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Post a job',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<JobProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.jobs.isEmpty) {
            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: const [
                _TitleBlock(subtitle: 'Finding opportunities...'),
                SizedBox(height: 18),
                _JobSkeleton(),
                _JobSkeleton(),
                _JobSkeleton(),
                _JobSkeleton(),
              ],
            );
          }

          if (provider.error != null && provider.jobs.isEmpty) {
            return _StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Something went wrong',
              message: provider.error!,
              actionLabel: 'Retry',
              onAction: provider.loadJobs,
            );
          }

          if (provider.jobs.isEmpty) {
            return RefreshIndicator(
              color: AuthPalette.ink,
              onRefresh: provider.loadJobs,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: const [
                  _TitleBlock(subtitle: 'No openings right now'),
                  SizedBox(height: 70),
                  _StateMessage(
                    icon: Icons.work_outline_rounded,
                    title: 'No jobs available yet',
                    message:
                        'Be the first to post an opportunity for the '
                        'community.',
                  ),
                ],
              ),
            );
          }

          // Job types that really exist in the data become filter chips.
          final types =
              provider.jobs
                  .map((j) => j.formattedJobType)
                  .where((t) => t.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          final activeType = types.contains(_selectedType)
              ? _selectedType
              : null;
          final filtered = _applyFilters(provider.jobs, activeType);
          final isFiltering = _query.isNotEmpty || activeType != null;

          return RefreshIndicator(
            color: AuthPalette.ink,
            onRefresh: provider.loadJobs,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TitleBlock(
                          subtitle: isFiltering
                              ? '${filtered.length} of ${provider.jobs.length} '
                                    'jobs'
                              : '${provider.jobs.length} '
                                    '${provider.jobs.length == 1 ? 'opening' : 'openings'}',
                        ),
                        const SizedBox(height: 16),
                        _buildSearchField(),
                        if (types.length > 1) ...[
                          const SizedBox(height: 12),
                          _buildTypeChips(types, activeType),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 100),
                    sliver: SliverToBoxAdapter(
                      child: _StateMessage(
                        icon: Icons.search_off_rounded,
                        title: 'No matching jobs',
                        message:
                            'Try a different keyword or clear the '
                            'filters.',
                        actionLabel: 'Clear filters',
                        onAction: () async => _clearFilters(),
                        centered: false,
                      ),
                    ),
                  )
                else
                  // Bottom padding keeps the last card clear of the button.
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final job = filtered[index];
                        return _JobCard(job: job, onTap: () => _openJob(job));
                      }, childCount: filtered.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search title, company or location',
        hintStyle: const TextStyle(color: AuthPalette.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AuthPalette.textMuted,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AuthPalette.textMuted,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuthPalette.ink, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildTypeChips(List<String> types, String? activeType) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: activeType == null,
            onTap: () => setState(() => _selectedType = null),
          ),
          for (final type in types) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: type,
              selected: activeType == type,
              onTap: () => setState(() => _selectedType = type),
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

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available jobs',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AuthPalette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AuthPalette.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final JobModel job;
  final VoidCallback onTap;

  static const _avatarColors = [
    AuthPalette.ink,
    AuthPalette.inkLight,
    Color(0xFF2E6F95),
    Color(0xFF3A7D6B),
    Color(0xFF6B4E9B),
  ];

  Color _companyColor() {
    if (job.company.isEmpty) return _avatarColors.first;
    final sum = job.company.codeUnits.fold<int>(0, (a, b) => a + b);
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

  @override
  Widget build(BuildContext context) {
    final location = job.location?.trim();
    final hasLocation = location != null && location.isNotEmpty;
    final type = job.formattedJobType;
    final typeColor = _typeColor(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
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
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company "logo": first letter on a colored tile.
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _companyColor(),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      job.company.isNotEmpty
                          ? job.company[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
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
                          job.company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AuthPalette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(
                              icon: Icons.place_outlined,
                              label: hasLocation
                                  ? location
                                  : 'Location not specified',
                              background: AuthPalette.mist,
                              foreground: hasLocation
                                  ? AuthPalette.ink
                                  : AuthPalette.textMuted,
                            ),
                            if (type.trim().isNotEmpty)
                              _MetaChip(
                                icon: Icons.schedule_rounded,
                                label: type,
                                background: typeColor.withOpacity(0.12),
                                foreground: typeColor,
                                bold: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 16),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AuthPalette.textMuted,
                    ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AuthPalette.ink : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AuthPalette.ink : const Color(0xFFD5DCE6),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AuthPalette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder card shown during the first load.
class _JobSkeleton extends StatefulWidget {
  const _JobSkeleton();

  @override
  State<_JobSkeleton> createState() => _JobSkeletonState();
}

class _JobSkeletonState extends State<_JobSkeleton>
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _bar,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(width: 170, height: 15),
                  const SizedBox(height: 8),
                  _line(width: 100),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _line(width: 80, height: 24),
                      const SizedBox(width: 8),
                      _line(width: 64, height: 24),
                    ],
                  ),
                ],
              ),
            ),
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
