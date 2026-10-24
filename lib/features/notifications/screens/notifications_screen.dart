import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/auth_palette.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// UI-only filter: false = "All", true = "Unread".
  bool _unreadOnly = false;

  static const _groupOrder = ['Today', 'Yesterday', 'This week', 'Earlier'];
  static const _unreadTint = Color(0xFFF0F4FA);
  static const _divider = Color(0xFFE9EDF3);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications();
      }
    });
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
  // Logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _markAllAsRead() async {
    final provider = context.read<NotificationProvider>();
    final success = await provider.markAllAsRead();

    if (!mounted) return;

    _showSnack(
      success
          ? 'All notifications marked as read.'
          : provider.errorMessage ?? 'Could not update notifications.',
      error: !success,
    );
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final provider = context.read<NotificationProvider>();
    final success = await provider.deleteNotification(
      notification.notificationId,
    );

    if (!mounted) return;

    _showSnack(
      success
          ? 'Notification deleted.'
          : provider.errorMessage ?? 'Could not delete notification.',
      error: !success,
    );
  }

  Future<void> _openNotification(NotificationModel notification) async {
    final provider = context.read<NotificationProvider>();

    if (!notification.isRead) {
      await provider.markAsRead(notification.notificationId);
    }

    // Post navigation can be added once the backend's reference_id
    // convention and notification types are confirmed.
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final localDate = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inSeconds < 60 && !difference.isNegative) {
      return 'Just now';
    }
    if (difference.inMinutes < 60 && !difference.isNegative) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24 && !difference.isNegative) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7 && !difference.isNegative) {
      return '${difference.inDays}d ago';
    }

    return '${localDate.day} ${_months[localDate.month - 1]} ${localDate.year}';
  }

  /// Which section a notification belongs to.
  String _groupFor(DateTime? date) {
    if (date == null) return 'Earlier';

    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today
        .difference(day)
        .inDays;

    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
      case 'post_like':
        return Icons.favorite_rounded;

      case 'comment':
      case 'post_comment':
        return Icons.mode_comment_rounded;

      case 'job':
      case 'job_application':
        return Icons.work_rounded;

      case 'message':
        return Icons.chat_bubble_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
      case 'post_like':
        return const Color(0xFFD64560);

      case 'comment':
      case 'post_comment':
        return AuthPalette.inkLight;

      case 'job':
      case 'job_application':
        return const Color(0xFFB9811D);

      case 'message':
        return AuthPalette.good;

      default:
        return AuthPalette.textMuted;
    }
  }

  String _labelForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
      case 'post_like':
        return 'Like';

      case 'comment':
      case 'post_comment':
        return 'Comment';

      case 'job':
      case 'job_application':
        return 'Job';

      case 'message':
        return 'Message';

      default:
        return 'Update';
    }
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
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      title: const Text(
        'Notifications',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AuthPalette.ink,
        ),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            if (provider.unreadCount == 0) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: provider.isLoading ? null : _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all read'),
                style: TextButton.styleFrom(
                  foregroundColor: AuthPalette.inkLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.mist,
      appBar: _buildAppBar(),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AuthPalette.ink),
            );
          }

          if (provider.errorMessage != null && provider.notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Something went wrong',
                  message: provider.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: provider.loadNotifications,
                ),
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return RefreshIndicator(
              color: AuthPalette.ink,
              onRefresh: provider.loadNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 90),
                  _StateMessage(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up",
                    message:
                    'New likes, comments and job updates will '
                        'show up here.',
                  ),
                ],
              ),
            );
          }

          final visible = _unreadOnly
              ? provider.notifications.where((n) => !n.isRead).toList()
              : provider.notifications;

          return Column(
            children: [
              _buildFilters(provider),
              Expanded(
                child: RefreshIndicator(
                  color: AuthPalette.ink,
                  onRefresh: provider.loadNotifications,
                  child: visible.isEmpty
                      ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 70),
                      _StateMessage(
                        icon: Icons.mark_email_read_outlined,
                        title: 'No unread notifications',
                        message: "You've read everything. Nice!",
                        actionLabel: 'Show all',
                        onAction: () =>
                            setState(() => _unreadOnly = false),
                      ),
                    ],
                  )
                      : _buildGroupedList(visible),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(NotificationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: !_unreadOnly,
            onTap: () => setState(() => _unreadOnly = false),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Unread',
            count: provider.unreadCount,
            selected: _unreadOnly,
            onTap: () => setState(() => _unreadOnly = true),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<NotificationModel> items) {
    // Keep the provider's order inside each section.
    final groups = <String, List<NotificationModel>>{
      for (final name in _groupOrder) name: [],
    };
    for (final n in items) {
      groups[_groupFor(n.createdAt)]!.add(n);
    }

    final children = <Widget>[];
    for (final name in _groupOrder) {
      final list = groups[name]!;
      if (list.isEmpty) continue;

      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(6, children.isEmpty ? 8 : 20, 0, 10),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AuthPalette.ink,
              letterSpacing: -0.1,
            ),
          ),
        ),
      );

      children.add(
        Container(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  _buildRow(list[i]),
                  if (i != list.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 80,
                      color: _divider,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: children,
    );
  }

  Widget _buildRow(NotificationModel notification) {
    final accent = _colorForType(notification.type);
    final unread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AuthPalette.error,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        _deleteNotification(notification);
      },
      child: Material(
        color: unread ? _unreadTint : Colors.white,
        child: InkWell(
          onTap: () => _openNotification(notification),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Solid circle when unread, soft tint once read.
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: unread ? accent : accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForType(notification.type),
                    size: 23,
                    color: unread ? Colors.white : accent.withOpacity(0.75),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          fontWeight: unread ? FontWeight.w700 : FontWeight
                              .w500,
                          color: unread
                              ? AuthPalette.ink
                              : const Color(0xFF3F4F63),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _labelForType(notification.type),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: unread ? accent : AuthPalette.textMuted,
                              ),
                            ),
                            const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: _formatDate(notification.createdAt),
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AuthPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 6),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AuthPalette.brass,
                        shape: BoxShape.circle,
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

/// "All" / "Unread" pill.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

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
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AuthPalette.brass,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared look for the empty and error states.
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
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}