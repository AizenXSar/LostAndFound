import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Animation Logo - same as login screen
                SizedBox(
                  height: 300,
                  width: 300,
                  child: Lottie.asset(
                    'assets/animations/Live chatbot.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                // App Name or Logo Text - Instagram-style cursive font
                Text(
                  'Lost and Found',
                  style: GoogleFonts.dancingScript(
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

