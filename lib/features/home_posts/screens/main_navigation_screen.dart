import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_app_bar.dart';
import '../../../core/widgets/app_bottom_navigation.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../directory/screens/alumni_screen.dart';
import '../../jobs/screens/jobs_screen.dart';
import '../../applications/screens/applications_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../profile/screens/profile_screen.dart';

import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [
    HomeScreen(),
    AlumniScreen(),
    JobsScreen(),
    ApplicationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications();
      }
    });
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );

    if (!mounted) return;

    await context.read<NotificationProvider>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return Scaffold(
          appBar: AppAppBar(
            onLogout: _logout,
            onMessages: _openMessages,
            onNotifications: _openNotifications,
            unreadNotifications: notificationProvider.unreadCount,
          ),
          body: IndexedStack(index: _currentIndex, children: _pages),
          bottomNavigationBar: AppBottomNavigation(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        );
      },
    );
  }
}
