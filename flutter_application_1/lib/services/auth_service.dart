import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static const String cloudName = 'dqvgdumua';
  static const String apiKey = '432254463977341';
  // Do NOT ship apiSecret in production apps; use unsigned preset or server signing
  static const String apiSecret = '2_IIrOgcQHvfEG3tlZJ2Y7plStM';
  static const String uploadPreset = 'unsigned_preset';
  static const String userImagesFolder = 'user-profiles';

  // Stores last Cloudinary error for UI display
  static String? lastCloudinaryError;

  // Firebase instances
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SharedPreferences keys (still used for local storage)
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';

  // Get current Firebase user
  static User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  static Future<String?> uploadImageToCloudinary(String imagePath) async {
    try {
      lastCloudinaryError = null;
      // Use auto to support images or videos
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
      );

      final file = File(imagePath);
      final request = http.MultipartRequest('POST', url)
        ..fields.addAll({
          'upload_preset': uploadPreset,
          'folder': userImagesFolder,
        })
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(responseData);
        return (jsonData['secure_url'] ?? jsonData['url']) as String?;
      } else {
        try {
          final err = jsonDecode(responseData);
          final msg = (err['error']?['message'] as String?) ?? responseData;
          lastCloudinaryError = msg;
          print('Error uploading to Cloudinary: $msg');
        } catch (_) {
          lastCloudinaryError = responseData;
          print('Error uploading to Cloudinary: $responseData');
        }
        return null;
      }
    } catch (e) {
      lastCloudinaryError = e.toString();
      print('Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  // Login with Firebase Authentication
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {'success': false, 'message': 'Login failed'};
      }

      // Require verified email before proceeding
      await user.reload();
      if (!(user.emailVerified)) {
        return {
          'success': false,
          'message':
              'Please verify your email address. We\'ve sent a verification link.',
        };
      }

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      return {
        'success': true,
        'message': 'Login successful',
        'user': {
          'id': user.uid,
          'email': user.email,
          'name': userData?['name'] ?? '',
          'profileImageUrl': userData?['profileImageUrl'] ?? '',
        },
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Register with Firebase Authentication and Firestore
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
    String? profileImageUrl,
  ) async {
    try {
      // 1. Create user in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {'success': false, 'message': 'Registration failed'};
      }

      // 2. Store additional user data in Firestore (best-effort)
      String? profileWriteWarning;
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'profileImageUrl': profileImageUrl ?? '',
          'role': 'user',
          'isAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          profileWriteWarning = ' (profile not saved due to Firestore rules)';
        } else if (e.code == 'not-found' ||
            e.message?.contains('does not exist') == true) {
          profileWriteWarning =
              ' (Firestore database not created - create it in Firebase Console)';
        } else {
          profileWriteWarning = ' (${e.message ?? e.code})';
        }
      }

      // 3. Send verification email (with fallback ActionCodeSettings)
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://lostandfound-4e45a.firebaseapp.com',
          handleCodeInApp: false,
          androidPackageName: 'com.example.flutter_application_1',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        );
        await user.sendEmailVerification(actionCodeSettings);
      } catch (_) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
      }

      return {
        'success': true,
        'message':
            'Registration successful. Check your email for the verification link.${profileWriteWarning != null ? profileWriteWarning : ''}',
        'user': {
          'id': user.uid,
          'email': user.email,
          'name': name,
          'profileImageUrl': profileImageUrl ?? '',
        },
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'email-already-in-use':
          message = 'Email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-in is disabled in Firebase Auth';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection';
          break;
        default:
          message = e.message ?? message;
      }
      return {'success': false, 'message': message};
    } on FirebaseException catch (e) {
      // Firestore permission errors, etc.
      String message = 'Registration failed';
      if (e.code == 'permission-denied') {
        message =
            'Permission denied writing user profile. Check Firestore Rules.';
      } else if (e.code == 'unavailable') {
        message = 'Network unavailable. Please try again.';
      } else if (e.message != null) {
        message = e.message!;
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Forgot Password - Send reset email
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message': 'Password reset email sent. Please check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send password reset email';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Reset Password (Firebase handles this via email link)
  // This method is kept for compatibility, but Firebase reset is done via email
  static Future<Map<String, dynamic>> resetPassword(
    String token,
    String newPassword,
  ) async {
    // Firebase password reset is handled via email link
    // If you need to reset programmatically, use currentUser.updatePassword()
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        return {'success': true, 'message': 'Password reset successful'};
      } else {
        return {'success': false, 'message': 'No user is currently logged in'};
      }
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': 'Error resetting password: ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Logout
  static Future<void> logout() async {
    await _auth.signOut();
    await clearUserData();
  }

  // Clear user data (helper method)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userIdKey);
    await prefs.remove(userEmailKey);
  }

  // Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firestore
  static Future<bool> updateUserData(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // Resend email verification link
  static Future<Map<String, dynamic>> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user is currently logged in'};
      }
      try {
        final actionCodeSettings = ActionCodeSettings(
          url: 'https://lostandfound-4e45a.firebaseapp.com',
          handleCodeInApp: false,
          androidPackageName: 'com.example.flutter_application_1',
          androidInstallApp: true,
          androidMinimumVersion: '21',
        );
        await user.sendEmailVerification(actionCodeSettings);
      } catch (_) {
        await user.sendEmailVerification();
      }
      return {'success': true, 'message': 'Verification email sent'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Set user role (admin/user). Only call this from trusted/admin UI.
  static Future<bool> setUserRole({
    required String userId,
    required String role, // 'admin' or 'user'
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
        'isAdmin': role.toLowerCase() == 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> currentUserIsAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return false;
      final role = (data['role'] as String?) ?? '';
      final isAdmin = (data['isAdmin'] as bool?) ?? false;
      return role.toLowerCase() == 'admin' || isAdmin;
    } catch (_) {
      return false;
    }
  }
}
