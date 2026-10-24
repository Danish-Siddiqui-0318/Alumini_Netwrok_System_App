import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/auth_palette.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;

  final int unreadMessages;
  final int unreadNotifications;
  final bool confirmLogout;

  const AppAppBar({
    super.key,
    required this.onLogout,
    required this.onMessages,
    required this.onNotifications,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.confirmLogout = true,
  });

  Future<void> _handleLogout(BuildContext context) async {
    if (!confirmLogout) {
      onLogout();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.logout_rounded,
          color: AuthPalette.ink,
          size: 30,
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AuthPalette.ink),
        ),
        content: const Text(
          'You will need to sign in again to access your network.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AuthPalette.textMuted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AuthPalette.ink),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AuthPalette.brass,
              foregroundColor: AuthPalette.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleSpacing: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthPalette.ink, AuthPalette.inkLight],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AuthPalette.brass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AuthPalette.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              'Alumni Network',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        _AppBarAction(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Messages',
          count: unreadMessages,
          onPressed: onMessages,
        ),
        const SizedBox(width: 8),
        _AppBarAction(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          count: unreadNotifications,
          onPressed: onNotifications,
        ),
        const SizedBox(width: 8),
        _AppBarAction(
          icon: Icons.logout_rounded,
          tooltip: 'Logout',
          onPressed: () => _handleLogout(context),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.count = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int count;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22, color: Colors.white),
      ),
    );

    if (count <= 0) {
      return Center(child: button);
    }

    return Center(
      child: Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: AuthPalette.brass,
        textColor: AuthPalette.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        child: button,
      ),
    );
  }
}
