// dart:io is not available on Flutter Web — use string matching for network errors
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';

/// AuthRepository orchestrates authentication and user preference flows.
///
/// Strategy:
///   - Login / Signup   → API only (network required); result cached locally.
///   - Current user     → Cache-first; silent background refresh.
///   - Preferences GET  → API first → Cache fallback → Sensible defaults.
///   - Preferences SAVE → API first; cache updated optimistically.
///   - Logout           → Clear API session and all cache.
class AuthRepository {
  final AuthService  _authService  = AuthService();
  final ApiService   _apiService   = ApiService();
  final AppCacheService _cache     = AppCacheService();

  // ═════════════════════════════════════════════════════════════════════════
  // LOGIN / SIGNUP
  // ═════════════════════════════════════════════════════════════════════════

  /// Sign in and persist the session.
  /// Throws a human-readable [String] message on failure.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 AuthRepository: signing in $email …');

      // Delegate to AuthService (handles token persistence internally).
      await _authService.signInWithEmail(email: email, password: password);

      // Build a UserModel from SharedPreferences written by AuthService.
      final user = await _buildUserFromPrefs();
      await _cache.saveUser(user);

      debugPrint('✅ AuthRepository: login successful for ${user.email}');
      return user;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('No internet') || msg.contains('Failed host lookup')) {
        throw 'No internet connection. Please check your network.';
      }
      debugPrint('❌ AuthRepository.login: $e');
      rethrow;
    }
  }

  /// Sign in with Google using the Google Sign In plugin.
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🔐 AuthRepository: signing in with Google...');

      // IMPORTANT: For Flutter Web, pass `clientId` (Web OAuth Client ID).
      // For Android, pass `serverClientId` (same Web OAuth Client ID).
      // Both use the *Web Application* OAuth 2.0 Client ID from Google Cloud Console.
      // Replace the value below with your actual Web Client ID.
      const webClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '677889353973-4e5bc97onmv6iqhpi5972qsfdg8lb9bj.apps.googleusercontent.com',
      );

      final GoogleSignIn googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId: webClientId,
              scopes: ['email', 'profile'],
            )
          : GoogleSignIn(
              serverClientId: webClientId,
              scopes: ['email', 'profile'],
            );

      // Removed signOut() here as it can cause GIS to fail on Web

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google Sign In was cancelled.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // DEBUG LOGS TO SEE WHAT GIS IS RETURNING
      debugPrint("🛠️ Access Token: ${googleAuth.accessToken}");
      debugPrint("🛠️ ID Token: ${googleAuth.idToken}");
      debugPrint("🛠️ Server Auth Code: ${googleAuth.serverAuthCode}");

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Failed to retrieve ID token from Google. Check your OAuth Client ID configuration.';
      }

      await _authService.signInWithGoogle(idToken: idToken);

      final user = await _buildUserFromPrefs();
      await _cache.saveUser(user);

      debugPrint('✅ AuthRepository: Google login successful for ${user.email}');
      return user;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('No internet') || msg.contains('Failed host lookup')) {
        throw 'No internet connection. Please check your network.';
      }
      debugPrint('❌ AuthRepository.signInWithGoogle: $e');
      rethrow;
    }
  }

  /// Send forgot password email.
  Future<void> forgotPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      debugPrint('❌ AuthRepository.forgotPassword: $e');
      rethrow;
    }
  }

  /// Reset password using token from email.
  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await _authService.resetPasswordWithToken(token: token, newPassword: newPassword);
    } catch (e) {
      debugPrint('❌ AuthRepository.resetPassword: $e');
      rethrow;
    }
  }

  /// Resend email verification.
  Future<void> resendVerification(String email) async {
    try {
      await _authService.resendVerificationEmail(email);
    } catch (e) {
      debugPrint('❌ AuthRepository.resendVerification: $e');
      rethrow;
    }
  }


  /// Sign up and send verification email.
  /// After calling this, navigate the user to VerifyEmailScreen.
  /// Throws a human-readable [String] message on failure.
  Future<void> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      debugPrint('🔐 AuthRepository: signing up $email …');

      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );

      // Do NOT save user / token here — user hasn't verified yet.
      debugPrint('✅ AuthRepository: signup submitted for $email — awaiting email verification');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('No internet') || msg.contains('Failed host lookup')) {
        throw 'No internet connection. Please check your network.';
      }
      debugPrint('❌ AuthRepository.signup: $e');
      rethrow;
    }
  }


  /// Sign out: clear the remote session and all cached data.
  Future<void> logout() async {
    try {
      await _authService.signOut();
      await _cache.clearUser();
      debugPrint('🔓 AuthRepository: logged out');
    } catch (e) {
      debugPrint('❌ AuthRepository.logout: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CURRENT USER
  // ═════════════════════════════════════════════════════════════════════════

  /// Returns the currently logged-in user.
  /// Loads from cache immediately; returns null if not authenticated.
  Future<UserModel?> getCurrentUser() async {
    // 1. Try cache first for instant response.
    final cached = await _cache.loadUser();
    if (cached != null && cached.id.isNotEmpty) {
      debugPrint('💾 AuthRepository: user loaded from cache');
      return cached;
    }

    // 2. Try rebuilding from SharedPreferences (written by AuthService).
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(AppConstants.keyUserId) ?? '';
      if (id.isNotEmpty) {
        final user = await _buildUserFromPrefs();
        await _cache.saveUser(user);
        return user;
      }
    } catch (e) {
      debugPrint('❌ AuthRepository.getCurrentUser: $e');
    }
    return null;
  }

  /// Returns whether the user is currently authenticated.
  Future<bool> isLoggedIn() async {
    try {
      final token = await _authService.getStoredToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the stored user ID, or null if not authenticated.
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(AppConstants.keyUserId);
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // USER PREFERENCES
  // ═════════════════════════════════════════════════════════════════════════

  /// Fetch user preferences.
  /// Strategy: API first → Cache fallback → Factory defaults.
  Future<UserPreferences> getPreferences(String userId) async {
    // 1. API first.
    try {
      debugPrint('🌐 AuthRepository: fetching preferences for $userId …');
      final response = await _apiService.getUserPreferences(userId: userId);
      final pref = UserPreferences.fromJson(response);
      await _cache.savePreferences(pref);
      debugPrint('✅ AuthRepository: preferences fetched from API');
      return pref;
    } catch (e) {
      debugPrint('⚠️ AuthRepository: API preferences failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadPreferences();
    if (cached != null) {
      debugPrint('💾 AuthRepository: preferences loaded from cache');
      return cached;
    }

    // 3. Factory defaults.
    debugPrint('📋 AuthRepository: using default preferences');
    return _defaultPreferences(userId);
  }

  /// Save user preferences.
  /// Writes to cache optimistically, then pushes to API.
  /// On API failure, the cache retains the new values (offline-friendly).
  Future<UserPreferences> savePreferences({
    required String userId,
    required List<String> targetSkills,
    required int dailyStudyHoursGoal,
    required String learningPace,
    required List<String> preferredCategories,
  }) async {
    final optimistic = UserPreferences(
      userId: userId,
      targetSkills: targetSkills,
      dailyStudyHoursGoal: dailyStudyHoursGoal,
      learningPace: learningPace,
      preferredCategories: preferredCategories,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Optimistic cache write.
    await _cache.savePreferences(optimistic);

    try {
      debugPrint('🌐 AuthRepository: saving preferences for $userId …');
      final response = await _apiService.saveUserPreferences(
        userId: userId,
        targetSkills: targetSkills,
        dailyStudyHoursGoal: dailyStudyHoursGoal,
        learningPace: learningPace,
        preferredCategories: preferredCategories,
      );

      // Overwrite cache with API-confirmed copy if available.
      final confirmed = response['data'] is Map<String, dynamic>
          ? UserPreferences.fromJson(response['data'] as Map<String, dynamic>)
          : optimistic;
      await _cache.savePreferences(confirmed);

      debugPrint('✅ AuthRepository: preferences saved to API');
      return confirmed;
    } catch (e) {
      debugPrint('⚠️ AuthRepository: API save failed; preferences kept in cache only. Error: $e');
      return optimistic;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  /// Build a UserModel from the keys written to SharedPreferences by AuthService.
  Future<UserModel> _buildUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return UserModel(
      id:    prefs.getString(AppConstants.keyUserId)    ?? '',
      email: prefs.getString(AppConstants.keyUserEmail) ?? '',
      name:  prefs.getString('user_name')               ?? 'User',
      isAdmin: prefs.getBool('is_admin')                ?? false,
    );
  }

  /// Sensible defaults when no preferences are available anywhere.
  UserPreferences _defaultPreferences(String userId) {
    final now = DateTime.now();
    return UserPreferences(
      userId:               userId,
      targetSkills:         const [],
      dailyStudyHoursGoal:  1,
      learningPace:         'medium',
      preferredCategories:  const [],
      createdAt:            now,
      updatedAt:            now,
    );
  }
}
