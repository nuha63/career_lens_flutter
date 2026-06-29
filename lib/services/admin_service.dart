import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import 'auth_service.dart';

class AdminService {
  final AuthService _authService = AuthService();
  final String _baseUrl = AppConstants.baseUrl;
  final http.Client _client = http.Client();

  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getStoredToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get Admin Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/stats?user_id=$userId');
      final response = await _client.get(
        url,
        headers: await _getHeaders(),
      ).timeout(_timeout);

      return _parseResponse(response);
    } catch (e) {
      debugPrint('❌ AdminService.getDashboardStats: $e');
      rethrow;
    }
  }

  /// Get All Users
  Future<List<dynamic>> getAllUsers(String userId, {int skip = 0, int limit = 100}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/users?user_id=$userId&skip=$skip&limit=$limit');
      final response = await _client.get(
        url,
        headers: await _getHeaders(),
      ).timeout(_timeout);

      return _parseResponseList(response);
    } catch (e) {
      debugPrint('❌ AdminService.getAllUsers: $e');
      rethrow;
    }
  }

  /// Get All Payments
  Future<List<dynamic>> getAllPayments(String userId, {int skip = 0, int limit = 100}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/payments?user_id=$userId&skip=$skip&limit=$limit');
      final response = await _client.get(
        url,
        headers: await _getHeaders(),
      ).timeout(_timeout);

      return _parseResponseList(response);
    } catch (e) {
      debugPrint('❌ AdminService.getAllPayments: $e');
      rethrow;
    }
  }

  /// Approve or Reject a payment
  Future<void> updatePaymentStatus(String userId, String paymentId, String status) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/payments/approve?user_id=$userId');
      final response = await _client.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'payment_id': paymentId,
          'status': status,
        }),
      ).timeout(_timeout);

      _parseResponse(response);
    } catch (e) {
      debugPrint('❌ AdminService.updatePaymentStatus: $e');
      rethrow;
    }
  }

  /// Get System Feature Toggles
  Future<List<dynamic>> getSystemFeatures(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/features?user_id=$userId');
      final response = await _client.get(
        url,
        headers: await _getHeaders(),
      ).timeout(_timeout);

      return _parseResponseList(response);
    } catch (e) {
      debugPrint('❌ AdminService.getSystemFeatures: $e');
      rethrow;
    }
  }

  /// Update a System Feature Toggle
  Future<void> toggleFeature(String userId, String featureId, bool isActive) async {
    try {
      final url = Uri.parse('$_baseUrl/api/admin/features/$featureId?user_id=$userId');
      final response = await _client.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'is_active': isActive,
        }),
      ).timeout(_timeout);

      _parseResponse(response);
    } catch (e) {
      debugPrint('❌ AdminService.toggleFeature: $e');
      rethrow;
    }
  }

  // --- Helpers ---

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    }
    _handleError(response);
  }

  List<dynamic> _parseResponseList(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      return [];
    }
    _handleError(response);
  }

  Never _handleError(http.Response response) {
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
        errorMessage = 'Server error (${response.statusCode}).';
      }
    }
    throw errorMessage;
  }
}
