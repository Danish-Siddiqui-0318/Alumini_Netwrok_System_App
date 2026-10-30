import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/alumni_model.dart';
import '../providers/alumni_provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../messages/screens/chat_screen.dart';

class AlumniScreen extends StatefulWidget {
  const AlumniScreen({super.key});

  @override
  State<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// What is currently typed, used for the clear button and empty state.
  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AlumniProvider>().loadAlumni();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// Waits until the user stops typing, so we don't send a request per letter.
  void _onSearchChanged(String value) {
    setState(() => _query = value.trim());

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search(value);
    });
  }

  void _search(String value) {
    context.read<AlumniProvider>().searchAlumni(value);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
    context.read<AlumniProvider>().loadAlumni();
  }

  void _openProfile(AlumniModel alumni) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: alumni.userId),
      ),
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

  void _messageAlumni(AlumniModel alumni) {
    final currentUserId = context.read<AuthProvider>().currentUser?.userId;

    if (currentUserId == null) {
      _showSnack('Please log in again to send messages.', error: true);
      return;
    }

    if (currentUserId == alumni.userId) {
      _showSnack('You cannot message yourself.', error: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: alumni.userId,
          otherUserName: alumni.name,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuthPalette.mist,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alumni directory',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AuthPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer<AlumniProvider>(
                  builder: (context, provider, child) {
                    final count = provider.alumni.length;
                    final text = _query.isNotEmpty
                        ? '$count ${count == 1 ? 'result' : 'results'} for '
                              '"$_query"'
                        : 'Connect with $count ${count == 1 ? 'graduate' : 'graduates'}';

                    return Text(
                      provider.alumni.isEmpty && provider.isLoading
                          ? 'Finding alumni...'
                          : text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AuthPalette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildSearchField(),
              ],
            ),
          ),
          Expanded(
            child: Consumer<AlumniProvider>(
              builder: (context, provider, child) {
                return _buildList(provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onSubmitted: (value) {
        // Search immediately when the user presses the keyboard's search key.
        _debounce?.cancel();
        _search(value);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search alumni by name',
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
                onPressed: _clearSearch,
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

  Widget _buildList(AlumniProvider provider) {
    final alumni = provider.alumni;

    // Only the very first load hides the list; later searches keep showing
    // results with a thin progress bar (no flashing on every keystroke).
    if (provider.isLoading && alumni.isEmpty) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [
          _AlumniSkeleton(),
          _AlumniSkeleton(),
          _AlumniSkeleton(),
        ],
      );
    }

    if (provider.error != null && alumni.isEmpty) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: provider.error!,
        actionLabel: 'Retry',
        onAction: provider.loadAlumni,
      );
    }

    if (alumni.isEmpty) {
      return RefreshIndicator(
        color: AuthPalette.ink,
        onRefresh: provider.loadAlumni,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 50),
            _StateMessage(
              icon: Icons.person_search_rounded,
              title: 'No alumni found',
              message: _query.isEmpty
                  ? 'Alumni will appear here once they join the network.'
                  : 'Nobody matches "$_query". Try a different name.',
              actionLabel: _query.isEmpty ? null : 'Clear search',
              onAction: _query.isEmpty ? null : () async => _clearSearch(),
              centered: false,
            ),
          ],
        ),
      );
    }

    final currentUserId = context.read<AuthProvider>().currentUser?.userId;

    return RefreshIndicator(
      color: AuthPalette.ink,
      onRefresh: provider.loadAlumni,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        // Extra first row for the progress bar / error banner.
        itemCount: alumni.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
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
                if (provider.error != null)
                  _ErrorBanner(
                    message: provider.error!,
                    onRetry: provider.loadAlumni,
                  ),
              ],
            );
          }

          final person = alumni[index - 1];

          return AlumniCard(
            alumni: person,
            isCurrentUser: currentUserId == person.userId,
            onViewProfile: () => _openProfile(person),
            onMessage: () => _messageAlumni(person),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Alumni card
// -----------------------------------------------------------------------------

class AlumniCard extends StatelessWidget {
  final AlumniModel alumni;
  final VoidCallback onViewProfile;
  final VoidCallback onMessage;

  /// Hides the Message button on your own card.
  final bool isCurrentUser;

  const AlumniCard({
    super.key,
    required this.alumni,
    required this.onViewProfile,
    required this.onMessage,
    this.isCurrentUser = false,
  });

  static const _avatarColors = [
    AuthPalette.ink,
    AuthPalette.inkLight,
    Color(0xFF2E6F95),
    Color(0xFF3A7D6B),
    Color(0xFF6B4E9B),
  ];

  bool _has(String? value) => value != null && value.trim().isNotEmpty;

  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarColors.first;
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _avatarColors[sum % _avatarColors.length];
  }

  /// "Software Engineer at Google", or whichever part exists.
  String _headline() {
    final title = alumni.jobTitle?.trim() ?? '';
    final company = alumni.currentCompany?.trim() ?? '';

    if (title.isNotEmpty && company.isNotEmpty) return '$title at $company';
    return title.isNotEmpty ? title : company;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _has(alumni.profilePicture);
    final headline = _headline();
    final initial = alumni.name.isNotEmpty ? alumni.name[0].toUpperCase() : '?';

    final chips = <Widget>[
      if (_has(alumni.degree))
        _MetaChip(icon: Icons.school_outlined, label: alumni.degree!.trim()),
      if (_has(alumni.department))
        _MetaChip(
          icon: Icons.account_balance_outlined,
          label: alumni.department!.trim(),
        ),
      if (_has(alumni.location))
        _MetaChip(icon: Icons.place_outlined, label: alumni.location!.trim()),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          borderRadius: BorderRadius.circular(22),
          onTap: onViewProfile,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brass ring around the avatar.
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: AuthPalette.brass,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: _avatarColor(alumni.name),
                        backgroundImage: hasImage
                            ? NetworkImage(alumni.profilePicture!)
                            : null,
                        child: hasImage
                            ? null
                            : Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    alumni.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AuthPalette.ink,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AuthPalette.brass.withOpacity(
                                        0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF7A5510),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (headline.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                headline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: AuthPalette.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewProfile,
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        label: const Text('View profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AuthPalette.ink,
                          side: const BorderSide(color: Color(0xFFD5DCE6)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (!isCurrentUser) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onMessage,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 19,
                          ),
                          label: const Text('Message'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AuthPalette.brass,
                            foregroundColor: AuthPalette.ink,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
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
          Icon(icon, size: 14, color: AuthPalette.inkLight),
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

/// Shown above the list when a refresh fails but old results are still there.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AuthPalette.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AuthPalette.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AuthPalette.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AuthPalette.error,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder card shown during the first load.
class _AlumniSkeleton extends StatefulWidget {
  const _AlumniSkeleton();

  @override
  State<_AlumniSkeleton> createState() => _AlumniSkeletonState();
}

class _AlumniSkeletonState extends State<_AlumniSkeleton>
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
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 61,
                  height: 61,
                  decoration: const BoxDecoration(
                    color: _bar,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(width: 150, height: 16),
                    const SizedBox(height: 10),
                    _line(width: 120),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _line(height: 44)),
                const SizedBox(width: 10),
                Expanded(child: _line(height: 44)),
              ],
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
