import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../utils/sweet_alert.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String userEmail;

  const VerifyEmailScreen({super.key, required this.userEmail});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isVerified = false;
  bool _isResending = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Start checking verification status immediately
    _checkVerificationStatus();
    // Auto-check every 3 seconds
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _isVerified) {
        timer.cancel();
        return;
      }
      _checkVerificationStatus();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _checkVerificationStatus() async {
    // Don't check if already verified or currently checking
    if (_isVerified || _isChecking) return;

    if (!mounted) return;

    final user = AuthService.currentUser;
    if (user == null) {
      // User logged out, redirect to login
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      // Reload user to get latest email verification status
      await user.reload();

      if (!mounted) return;

      final emailVerified = user.emailVerified;

      if (emailVerified) {
        // Stop auto-refresh
        _stopAutoRefresh();

        setState(() {
          _isVerified = true;
          _isChecking = false;
        });

        // Wait a moment to show success message then navigate to home
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        // Not verified yet, continue auto-refreshing
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    } catch (e) {
      // Error checking - continue trying
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthService.resendEmailVerification();

      if (!mounted) return;

      setState(() {
        _isResending = false;
      });

      await SweetAlert.fire(
        context: context,
        title: result['success'] == true ? 'Success' : 'Error',
        message: result['message'] as String? ?? 'Unknown error',
        icon: result['success'] == true
            ? SweetAlertType.success
            : SweetAlertType.error,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
        });

        await SweetAlert.error(
          context: context,
          title: 'Error',
          message: 'Failed to resend verification email: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              // Icon
              Icon(
                _isVerified ? Icons.check_circle_outline : Icons.email_outlined,
                size: 100,
                color: _isVerified
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                _isVerified ? 'Email Verified!' : 'Check Your Email',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                _isVerified
                    ? 'Your email has been verified. Redirecting to home...'
                    : 'We\'ve sent a verification link to:\n${widget.userEmail}\n\nPlease check your inbox and click the link to verify your email address.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (!_isVerified) ...[
                // Check Verification Button
                ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerificationStatus,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'I\'ve Verified My Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Resend Email Button
                TextButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resend Verification Email'),
                ),
                const SizedBox(height: 24),
                // Back to Login
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Back to Login'),
                ),
              ] else ...[
                // Loading indicator when verified
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
