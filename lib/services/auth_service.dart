import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// Authentication Service - Handles user authentication
class AuthService {
  final http.Client _client = http.Client();
  bool _isAuthenticated = false;

  // Get auth status from local storage snapshot.
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize auth state from SharedPreferences
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken);
      _isAuthenticated = token != null && token.isNotEmpty;
      debugPrint('🔐 Auth initialized: $_isAuthenticated');
    } catch (e) {
      debugPrint('❌ Error initializing auth: $e');
      _isAuthenticated = false;
    }
  }

  /// Sign up with email and password using backend API.
  /// Returns the email address on success. Throws on error.
  /// NOTE: After signup, user must verify email before logging in.
  Future<String> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointSignup}'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'name': name,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      // 201 = created + needs verification (no access token yet)
      // 200 = legacy immediate login (shouldn't happen with new backend)
      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Backend sign up successful for: $email (status ${response.statusCode})');
        return email; // Return email so UI can pass it to VerifyEmailScreen
      }

      // Any other status is an error
      _parseResponse(response); // Will throw with error message
      return email;
    } catch (e) {
      debugPrint('❌ Unexpected sign up error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password using backend API.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}${AppConstants.endpointLogin}'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      final payload = _parseResponse(response);
      await _saveUserDataLocally(payload);
      _isAuthenticated = true;

      debugPrint('✅ Backend sign in successful for: $email');
    } catch (e) {
      debugPrint('❌ Unexpected sign in error: $e');
      rethrow;
    }
  }

  /// Sign in with Google using backend API.
  Future<void> signInWithGoogle({
    required String idToken,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/google'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'id_token': idToken,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      final payload = _parseResponse(response);
      await _saveUserDataLocally(payload);
      _isAuthenticated = true;

      debugPrint('✅ Backend Google sign in successful');
    } catch (e) {
      debugPrint('❌ Unexpected Google sign in error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _clearUserDataLocally();
      _isAuthenticated = false;
      debugPrint('🔓 User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      throw 'Failed to sign out. Please try again.';
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(AppConstants.apiTimeout);

      _parseResponse(response);
      debugPrint('✅ Password reset email sent to: $email');
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      rethrow;
    }
  }

  /// Resend email verification
  Future<void> resendVerificationEmail(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/resend-verification'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(AppConstants.apiTimeout);

      _parseResponse(response);
      debugPrint('✅ Verification email resent to: $email');
    } catch (e) {
      debugPrint('❌ Resend verification error: $e');
      rethrow;
    }
  }

  /// Reset password with token
  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'token': token,
              'new_password': newPassword,
            }),
          )
          .timeout(AppConstants.apiTimeout);

      _parseResponse(response);
      debugPrint('✅ Password reset successfully');
    } catch (e) {
      debugPrint('❌ Reset password error: $e');
      rethrow;
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    throw 'Account deletion API is not implemented yet.';
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    throw 'Profile update API is not implemented yet.';
  }

  /// Save user data to local storage
  Future<void> _saveUserDataLocally(Map<String, dynamic> payload) async {
    try {
      final user = (payload['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final token = (payload['access_token'] as String?) ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserId, (user['id'] as String?) ?? '');
      await prefs.setString(AppConstants.keyUserEmail, (user['email'] as String?) ?? '');
      await prefs.setString('user_name', (user['name'] as String?) ?? '');
      await prefs.setBool('is_admin', (user['is_admin'] as bool?) ?? false);
      await prefs.setString(AppConstants.keyAccessToken, token);
      await prefs.setBool(AppConstants.keyIsLoggedIn, token.isNotEmpty);
      
      debugPrint('💾 User data saved locally');
    } catch (e) {
      debugPrint('❌ Save user data error: $e');
    }
  }

  /// Clear user data from local storage
  Future<void> _clearUserDataLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserId);
      await prefs.remove(AppConstants.keyUserEmail);
      await prefs.remove(AppConstants.keyAccessToken);
      await prefs.remove('user_name');
      await prefs.remove('is_admin');
      await prefs.setBool(AppConstants.keyIsLoggedIn, false);
      debugPrint('🗑️ User data cleared locally');
    } catch (e) {
      debugPrint('❌ Clear user data error: $e');
    }
  }

  /// Get stored access token
  Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.keyAccessToken);
    } catch (e) {
      debugPrint('❌ Get stored token error: $e');
      return null;
    }
  }

  /// Refresh access token
  Future<String?> refreshToken() async {
    return getStoredToken();
  }

  Future<String?> getStoredUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    debugPrint('📡 Auth API [${response.statusCode}]: ${response.body.substring(0, response.body.length.clamp(0, 200))}');

    // Check status code FIRST — before any JSON parsing
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Try to decode JSON; fall back gracefully on unexpected format
      if (response.body.isEmpty) return {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {};
      } catch (_) {
        return {};
      }
    }

    // Error response — try to extract JSON detail, else use raw body
    String errorMessage = 'Request failed (${response.statusCode}).';
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          errorMessage = decoded['detail']?.toString() ??
              decoded['message']?.toString() ??
              errorMessage;
        }
      } catch (_) {
        // Body is not JSON (e.g. "Internal Server Error" HTML)
        errorMessage = 'Server error (${response.statusCode}). Please try again later.';
      }
    }
    throw errorMessage;
  }
}