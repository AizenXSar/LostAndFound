import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
// home_screen is not used directly after auth anymore (kept via MainNav)
import 'main_nav.dart';
import '../admin/home.dart';
import '../utils/sweet_alert.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _hasAgreedToPrivacy = false;
  bool _rememberMe = false;

  static const String _privacyAgreedKey = 'privacy_policy_agreed';
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _rememberedPasswordKey = 'remembered_password';

  @override
  void initState() {
    super.initState();
    _checkPrivacyAgreement();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    if (rememberMe && mounted) {
      setState(() {
        _rememberMe = true;
        _emailController.text = prefs.getString(_rememberedEmailKey) ?? '';
        _passwordController.text = prefs.getString(_rememberedPasswordKey) ?? '';
      });
    }
  }

  Future<void> _saveRememberMeCredentials(bool remember, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
    if (remember) {
      await prefs.setString(_rememberedEmailKey, email);
      await prefs.setString(_rememberedPasswordKey, password);
    } else {
      await prefs.remove(_rememberedEmailKey);
      await prefs.remove(_rememberedPasswordKey);
    }
  }

  Future<void> _checkPrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool(_privacyAgreedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _hasAgreedToPrivacy = agreed;
    });
    
    // Show modal automatically on first load if user hasn't agreed
    if (!agreed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAgreedToPrivacy) {
          _showPrivacyPolicyDialog();
        }
      });
    }
  }

  Future<void> _savePrivacyAgreement(bool agreed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAgreedKey, agreed);
    if (!mounted) return;
    setState(() {
      _hasAgreedToPrivacy = agreed;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Check if user has agreed to privacy policy
    if (!_hasAgreedToPrivacy) {
      // Show privacy policy modal - cannot proceed without agreement
      if (!mounted) return;
      _showPrivacyPolicyDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await AuthService.login(
      email,
      password,
    );

    // Save or clear credentials based on remember me checkbox
    await _saveRememberMeCredentials(_rememberMe, email, password);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      // Decide destination: admin → AdminHomePage (with bottom nav), else → MainNav
      final isAdmin = await AuthService.currentUserIsAdmin();
      final Widget dest = isAdmin ? const AdminHomePage() : const MainNav();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => dest),
        (route) => false,
      );
    } else {
      // If email not verified, offer to resend
      final msg = (result['message'] as String?) ?? 'Login failed';
      if (msg.toLowerCase().contains('verify your email')) {
        // Give user a quick action to resend verification email
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Email not verified'),
              content: const Text(
                'Please verify your email. Would you like us to resend the verification link?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final resp = await AuthService.resendEmailVerification();
                    if (!mounted) return;
                    await SweetAlert.fire(
                      context: context,
                      title: (resp['success'] == true) ? 'Success' : 'Error',
                      message: resp['message'] as String? ?? 'Unknown error',
                      icon: (resp['success'] == true)
                          ? SweetAlertType.success
                          : SweetAlertType.error,
                    );
                  },
                  child: const Text('Resend'),
                ),
              ],
            );
          },
        );
      } else {
        await SweetAlert.error(
          context: context,
          title: 'Login failed',
          message: msg,
        );
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!_hasAgreedToPrivacy) {
      if (!mounted) return;
      _showPrivacyPolicyDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final isAdmin = await AuthService.currentUserIsAdmin();
      final Widget dest = isAdmin ? const AdminHomePage() : const MainNav();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => dest),
        (route) => false,
      );
    } else {
      final msg = (result['message'] as String?) ?? 'Google sign-in failed';
      await SweetAlert.error(
        context: context,
        title: 'Login failed',
        message: msg,
      );
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot skip or dismiss without choosing an option
      builder: (context) => _PrivacyPolicyDialog(
        onAgree: () async {
          await _savePrivacyAgreement(true);
          if (!mounted) return;
          Navigator.of(context).pop();
          // After agreeing, user can proceed with login
        },
        onDisagree: () {
          _savePrivacyAgreement(false);
          // Exit the app immediately without showing any messages
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isIOS) {
            exit(0);
          } else {
            exit(0);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header text
                const Text(
                  'Login to your account.',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Hello, welcome back to your account',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Animation Logo
                SizedBox(
                  height: 160,
                  width: 200,
                  child: Lottie.asset(
                    'assets/animations/Live chatbot.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        width: 1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Remember me + Forgot Password row
                Row(
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: _rememberMe,
                        onChanged: (v) {
                          setState(() {
                            _rememberMe = v ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Remember me'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _isLoading
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
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).dividerColor.withOpacity(0.5))),
                  ],
                ),
                const SizedBox(height: 16),
                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(Icons.g_mobiledata, size: 24, color: Theme.of(context).colorScheme.onSurface),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyPolicyDialog extends StatelessWidget {
  const _PrivacyPolicyDialog({
    required this.onAgree,
    required this.onDisagree,
  });
  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Privacy Policy',
                textAlign: TextAlign.left,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Policy Text
            Wrap(
              children: [
                Text(
                  'This app respects and protects user privacy. To provide you with more accurate and personalized services, this app shall use and disclose your information in accordance with this privacy policy. For details, check the ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service Agreement - Coming soon')),
                    );
                  },
                  child: Text(
                    'Service Agreement',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' and ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy Policy - Coming soon')),
                    );
                  },
                  child: Text(
                    'Privacy Policy',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  '.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // AGREE Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAgree,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text(
                  'AGREE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // DISAGREE AND EXIT
            Center(
              child: GestureDetector(
                onTap: onDisagree,
                child: Text(
                  'DISAGREE AND EXIT',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
