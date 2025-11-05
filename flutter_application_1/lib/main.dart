import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart' show FCMService, firebaseMessagingBackgroundHandler;
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav.dart';
import 'admin/home.dart';
import 'theme/theme_controller.dart';

void main() async {
  // Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Add a small delay to ensure native platform is ready
  await Future.delayed(const Duration(milliseconds: 100));

  // Initialize Firebase - this must complete successfully before the app runs
  FirebaseApp? app;
  try {
    app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully: ${app.name}');
  } catch (e, stackTrace) {
    print('Firebase initialization error: $e');
    print('Stack trace: $stackTrace');
    
    // Try to check if Firebase is already initialized
    try {
      app = Firebase.app();
      print('Firebase was already initialized: ${app.name}');
    } catch (_) {
      // Firebase is not initialized - show error screen
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Firebase Initialization Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ));
      return; // Exit early if Firebase fails
    }
  }

  // Load saved theme preference
  await ThemeController.instance.init();

  // Initialize FCM for push notifications
  try {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize FCM service
    await FCMService.initialize();
    print('FCM Service initialized successfully');
  } catch (e) {
    print('Error initializing FCM Service: $e');
    // Continue app startup even if FCM fails
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.listenable,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Lost and Found',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Temporarily show login screen immediately for testing
    // Uncomment the line below and comment out _checkAuthStatus() to test
    // Future.delayed(Duration.zero, () => setState(() { _isLoading = false; }));
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('Checking auth status...');
      final loggedIn = await AuthService.isLoggedIn();
      print('Auth status: $loggedIn');
      bool isAdmin = false;
      if (loggedIn) {
        isAdmin = await AuthService.currentUserIsAdmin();
        print('Is admin: $isAdmin');
      }
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn;
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error checking auth status: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          // Show login screen even on error
          _isLoggedIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _checkAuthStatus();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return _isAdmin ? const AdminHomePage() : const MainNav();
    }
    return const LoginScreen();
  }
}

// AdminDashboardScreen helper removed; AdminHomePage is the admin shell
