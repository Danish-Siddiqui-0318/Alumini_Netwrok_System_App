import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/auth_palette.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home_posts/providers/post_provider.dart';
import 'features/home_posts/screens/main_navigation_screen.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/messages/providers/message_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
      child: const AlumniNetworkApp(),
    ),
  );
}

class AlumniNetworkApp extends StatelessWidget {
  const AlumniNetworkApp({super.key});

  ThemeData _buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AuthPalette.ink,
          brightness: Brightness.light,
        ).copyWith(
          primary: AuthPalette.ink,
          onPrimary: Colors.white,
          secondary: AuthPalette.brass,
          onSecondary: AuthPalette.ink,
          error: AuthPalette.error,
          surface: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AuthPalette.mist,
      // Any spinner or refresh indicator not styled by hand uses the brand ink.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuthPalette.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuthPalette.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alumni Network',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AppStartupGate(),
    );
  }
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().checkAuthStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isCheckingSession) {
          return const _SplashScreen();
        }

        if (auth.isAuthenticated) {
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

/// Shown while the saved session is being checked.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthPalette.ink, AuthPalette.inkLight],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AuthPalette.brass,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 48,
                color: AuthPalette.ink,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Alumni Network',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AuthPalette.brass,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
