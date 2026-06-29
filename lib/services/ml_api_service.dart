import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import 'auth_service.dart';

/// ML API Service - Handle all machine learning predictions
class MLApiService {
  final AuthService _authService = AuthService();
  
  // Base URL from constants
  final String _baseUrl = AppConstants.baseUrl;
  
  // HTTP Client with timeout
  final http.Client _client = http.Client();

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 600);
  
  /// Get headers with authentication token and user ID
  Future<Map<String, String>> _getHeaders({String? userId}) async {
    final token = await _authService.getStoredToken();
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (userId != null) 'X-User-ID': userId,
    };
  }

  // ==================== ML API ENDPOINTS ====================

  /// Analyze resume quality
  Future<Map<String, dynamic>> analyzeResume({
    required int experienceYears,
    required String educationLevel,
    required double skillsMatchScore,
    String? locationTime = "Remote",
    String? industry = "IT",
    String? jobMarketDemand = "High",
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/analyze-resume');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders(userId: userId)),
          body: jsonEncode({
            'experience_years': experienceYears,
            'education_level': educationLevel,
            'skills_match_score': skillsMatchScore,
            'location_type': locationTime,
            'industry': industry,
            'job_market_demand': jobMarketDemand,
          }),
        ),
      );

      final response_data = _handleResponse(response);
      debugPrint('✅ Resume analyzed: ${response_data['data']?['match_percentage']}%');
      return response_data;
    } catch (e) {
      debugPrint('❌ Resume analysis error: $e');
      throw _handleError(e);
    }
  }

  /// Match job opportunity
  Future<Map<String, dynamic>> matchJob({
    required String jobTitle,
    required String company,
    required String industry,
    required double resumeScore,
    required double skillsMatchScore,
    required int experienceYears,
    required String educationLevel,
    List<String>? requiredSkills,
    String? jobMarketDemand = "High",
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/job-match');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders(userId: userId)),
          body: jsonEncode({
            'job_title': jobTitle,
            'company': company,
            'industry': industry,
            'resume_score': resumeScore,
            'skills_match_score': skillsMatchScore,
            'experience_years': experienceYears,
            'education_level': educationLevel,
            'required_skills': requiredSkills ?? [],
            'job_market_demand': jobMarketDemand,
          }),
        ),
      );

      final response_data = _handleResponse(response);
      debugPrint('✅ Job matched: ${response_data['data']?['recommendation']}');
      return response_data;
    } catch (e) {
      debugPrint('❌ Job match error: $e');
      throw _handleError(e);
    }
  }

  /// Analyze skill gaps
  Future<Map<String, dynamic>> analyzeSkillGaps({
    required List<String> userSkills,
    required String targetJob,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/skill-gap');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders(userId: userId)),
          body: jsonEncode({
            'user_skills': userSkills,
            'target_job': targetJob,
          }),
        ),
      );

      final response_data = _handleResponse(response);
      final data = response_data['data'] as Map<String, dynamic>?;
      debugPrint('✅ Skill gaps analyzed: ${data?['total_missing']} missing');
      return response_data;
    } catch (e) {
      debugPrint('❌ Skill gap analysis error: $e');
      throw _handleError(e);
    }
  }

  /// Predict salary range
  Future<Map<String, dynamic>> predictSalary({
    required String companySize,
    required String industry,
    required bool remoteOption,
    required int numSkills,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/salary-prediction');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders(userId: userId)),
          body: jsonEncode({
            'company_size': companySize,
            'industry': industry,
            'remote_option': remoteOption,
            'num_skills': numSkills,
          }),
        ),
      );

      final response_data = _handleResponse(response);
      final data = response_data['data'] as Map<String, dynamic>?;
      debugPrint('✅ Salary predicted: \$${data?['salary_avg']}');
      return response_data;
    } catch (e) {
      debugPrint('❌ Salary prediction error: $e');
      throw _handleError(e);
    }
  }

  /// Get ML system status
  Future<Map<String, dynamic>> checkMLStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/api/ml-status');

      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ ML status check error: $e');
      throw _handleError(e);
    }
  }

  /// Get user progress from database
  Future<Map<String, dynamic>> getUserProgress({
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/user-progress/$userId');

      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders(userId: userId)),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Get user progress error: $e');
      throw _handleError(e);
    }
  }

  // ==================== RESPONSE HANDLERS ====================

  Map<String, String> _authHeadersSnapshot(Map<String, String> headers) {
    return Map<String, String>.from(headers);
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final response = await request().timeout(AppConstants.apiTimeout);
        if (_isRetriableStatus(response.statusCode) && attempt <= _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
        return response;
      } on SocketException {
        if (attempt > _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempt);
      } on TimeoutException {
        if (attempt > _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempt);
      }
    }
  }

  bool _isRetriableStatus(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('📡 ML API Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return {'success': true, 'data': response.body};
      }
    } else if (response.statusCode == 401) {
      throw 'Session expired. Please login again.';
    } else if (response.statusCode == 403) {
      throw 'Access denied. You do not have permission.';
    } else if (response.statusCode == 404) {
      throw 'ML service not available.';
    } else if (response.statusCode == 500) {
      throw 'ML server error. Please try again later.';
    } else {
      try {
        final error = jsonDecode(response.body);
        throw error['detail'] ?? error['message'] ?? 'Request failed with status: ${response.statusCode}';
      } catch (e) {
        throw 'ML request failed with status: ${response.statusCode}';
      }
    }
  }

  /// Handle errors
  String _handleError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'ML request timed out. Please try again.';
    } else if (error is http.ClientException) {
      return 'Connection failed. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid response format from ML server.';
    } else if (error is String) {
      return error;
    } else {
      return 'An unexpected error occurred: $error';
    }
  }
}

/// Singleton instance for ML API service
MLApiService? _mlApiServiceInstance;

/// Get or create ML API service singleton
MLApiService getMLApiService() {
  _mlApiServiceInstance ??= MLApiService();
  return _mlApiServiceInstance!;
}
