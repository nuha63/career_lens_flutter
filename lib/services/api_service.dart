import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/skill_model.dart';
import '../models/progress_model.dart';
import '../models/career_roadmap_model.dart';
import 'auth_service.dart';


/// API Service for backend communication
class ApiService {
  final AuthService _authService = AuthService();
  
  // Base URL from constants
  final String _baseUrl = AppConstants.baseUrl;
  
  // HTTP Client with timeout
  final http.Client _client = http.Client();

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 600);
  
  /// Get headers with authentication token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getStoredToken();
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get headers for multipart requests
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _authService.getStoredToken();
    
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================== AUTH APIs ====================

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointLogin}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Login API error: $e');
      throw _handleError(e);
    }
  }

  /// Signup user
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointSignup}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'email': email,
            'password': password,
            'name': name,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Signup API error: $e');
      throw _handleError(e);
    }
  }

  // ==================== RESUME APIs ====================

  /// Upload resume file and extract text (web-safe: accepts bytes)
  Future<Map<String, dynamic>> uploadResume({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointUploadResume}');
      
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getMultipartHeaders());
      
      // Web-safe: use fromBytes instead of fromPath
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Upload resume API error: $e');
      throw _handleError(e);
    }
  }

  /// Analyze resume against job description
  Future<Map<String, dynamic>> analyzeResume({
    required String resumeText,
    required String jobDescription,
    String region = AppConstants.regionGlobal,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointAnalyzeResume}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'resume_text': resumeText,
            'job_description': jobDescription,
            'region': region,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Analyze resume API error: $e');
      throw _handleError(e);
    }
  }

  // ==================== JOB APIs ====================

  /// Find matching jobs based on resume
  Future<Map<String, dynamic>> getJobMatch({
    required String resumeText,
    String region = AppConstants.regionGlobal,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointMatchJob}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'resume_text': resumeText,
            'region': region,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Job match API error: $e');
      throw _handleError(e);
    }
  }

  /// Analyze skill gaps for a target role
  Future<Map<String, dynamic>> analyzeSkillGap({
    required List<String> currentSkills,
    required String targetRole,
    String region = AppConstants.regionGlobal,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointSkillGap}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'current_skills': currentSkills,
            'target_role': targetRole,
            'region': region,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Skill gap analysis API error: $e');
      throw _handleError(e);
    }
  }

  /// Calculate job readiness score
  Future<Map<String, dynamic>> calculateJobReadiness({
    required String resumeText,
    required double experienceYears,
    String region = AppConstants.regionGlobal,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointJobReadiness}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'resume_text': resumeText,
            'experience_years': experienceYears,
            'region': region,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Job readiness API error: $e');
      throw _handleError(e);
    }
  }

  // ==================== SKILL ROADMAP APIs ====================

  /// Generate skill roadmap
  Future<List<SkillRoadmap>> generateSkillRoadmap({
    required List<String> missingSkills,
    required String market,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointSkillRoadmap}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'missing_skills': missingSkills,
            'market': market,
          }),
        ),
      );

      final data = _handleResponse(response);
      final List<dynamic> roadmapsJson = data['roadmaps'] ?? [];
      
      return roadmapsJson
          .map((json) => SkillRoadmap.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Generate roadmap API error: $e');
      throw _handleError(e);
    }
  }

  // ==================== PROGRESS APIs ====================

  /// Update progress
  Future<Map<String, dynamic>> updateProgress({
    required String userId,
    required String skillId,
    required double progressPercentage,
    List<String>? completedSteps,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointProgressUpdate}');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'user_id': userId,
            'skill_id': skillId,
            'progress_percentage': progressPercentage,
            'completed_steps': completedSteps ?? [],
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Update progress API error: $e');
      throw _handleError(e);
    }
  }

  /// Get user progress based on preferences
  Future<ProgressModel> getUserProgress({
    required String userId,
  }) async {
    try {
      // Correct endpoint: /api/user-progress/{user_id}
      final url = Uri.parse('$_baseUrl/api/user-progress/$userId');

      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );

      final data = _handleResponse(response);

      // Backend returns: job_readiness_score, resumes_analyzed, jobs_matched,
      // skill_gaps_analyzed, target_skills, avg_resume_score, avg_match_score
      // Map these to what ProgressModel expects.
      final targetSkills = (data['target_skills'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Build a skill_progress map from target_skills so the UI shows them
      final skillProgressMap = <String, Map<String, dynamic>>{};
      for (final skill in targetSkills) {
        skillProgressMap[skill] = {
          'skill_name': skill,
          'progress_percentage': 0.0,
          'is_completed': false,
          'completed_steps': [],
        };
      }

      final int jobsMatched = (data['jobs_matched'] as num?)?.toInt() ?? 0;
      final int resumesAnalyzed =
          (data['resumes_analyzed'] as num?)?.toInt() ?? 0;
      final double avgResume =
          (data['avg_resume_score'] as num?)?.toDouble() ?? 0.0;
      final double avgMatch =
          (data['avg_match_score'] as num?)?.toDouble() ?? 0.0;

      // Derive scores from backend data
      final int resumeQuality = avgResume.round().clamp(0, 100);
      final int techScore = avgMatch.round().clamp(0, 100);
      final double learningRatio = targetSkills.isNotEmpty 
          ? (jobsMatched / targetSkills.length).clamp(0.0, 1.0) 
          : 0.0;
      final int learningScore = (learningRatio * 100).round();
      
      // Calculate dynamic job readiness score instead of relying on the backend's default 0
      final int readinessScore = (
        (techScore * 0.40) + 
        (resumeQuality * 0.25) + 
        (70 * 0.20) + // baseline experience score
        (learningScore * 0.15)
      ).round().clamp(0, 100);

      final normalised = <String, dynamic>{
        'user_id': userId,
        'job_readiness_score': readinessScore > 0 ? readinessScore : data['job_readiness_score'] ?? 0,
        'total_skills_to_learn': targetSkills.isNotEmpty
            ? targetSkills.length
            : (jobsMatched + resumesAnalyzed).clamp(1, 999),
        'completed_skills': jobsMatched,
        'skills_in_progress': resumesAnalyzed,
        'technical_skill_score': techScore,
        'resume_quality_score': resumeQuality,
        'experience_score': 0,
        'learning_progress_score': 0,
        'skill_progress': skillProgressMap,
        'recommendations': [
          if (resumesAnalyzed == 0) 'Upload your resume to get started.',
          if (jobsMatched == 0)
            'Run a job match to see how well you fit roles.',
          if (targetSkills.isEmpty)
            'Set target skills in Preferences to personalise your plan.',
        ],
        'last_updated': data['last_activity'] ?? DateTime.now().toIso8601String(),
        'study_hours_logged': data['study_hours_logged'] ?? 0.0,
        'daily_study_hours_goal': data['daily_study_hours_goal'] ?? 1,
        'target_skills': data['target_skills'] ?? [],
        'skills_learned': data['skills_learned'] ?? [],
      };

      return ProgressModel.fromJson(normalised);
    } catch (e) {
      debugPrint('❌ Get progress API error: $e');
      throw _handleError(e);
    }
  }

  /// Log daily study hours
  Future<Map<String, dynamic>> logStudyHours(String userId, double hours) async {
    try {
      final url = Uri.parse('$_baseUrl/user-progress/$userId/log-hours');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({'hours': hours}),
        ),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Log study hours API error: $e');
      throw _handleError(e);
    }
  }

  /// Mark a skill as completed
  Future<Map<String, dynamic>> completeSkill(String userId, String skill) async {
    try {
      final url = Uri.parse('$_baseUrl/user-progress/$userId/complete-skill');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({'skill': skill}),
        ),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Complete skill API error: $e');
      throw _handleError(e);
    }
  }


  /// Parse resume file through enhanced backend parser (web-safe: accepts bytes).
  Future<Map<String, dynamic>> parseResumeFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointParseResumeFile}');
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getMultipartHeaders());
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Parse resume file API error: $e');
      throw _handleError(e);
    }
  }

  /// Analyze job description and extract requirements.
  Future<Map<String, dynamic>> analyzeJobDescription({
    required String jobDescription,
    String? jobTitle,
    String? company,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointAnalyzeJob}');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'job_description': jobDescription,
            if (jobTitle != null && jobTitle.isNotEmpty) 'job_title': jobTitle,
            if (company != null && company.isNotEmpty) 'company': company,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Analyze job API error: $e');
      throw _handleError(e);
    }
  }

  /// Optimize resume against a job description.
  Future<Map<String, dynamic>> optimizeResume({
    required String jobDescription,
    String? resumeText,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointOptimizeResume}');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'job_description': jobDescription,
            if (resumeText != null && resumeText.isNotEmpty) 'resume_text': resumeText,
            if (userId != null && userId.isNotEmpty) 'user_id': userId,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Optimize resume API error: $e');
      throw _handleError(e);
    }
  }

  /// Generate a tailored resume template for a target job.
  Future<Map<String, dynamic>> generateResumeTemplate({
    required String jobDescription,
    String? jobTitle,
    String? company,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointGenerateTemplate}');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'job_description': jobDescription,
            if (jobTitle != null && jobTitle.isNotEmpty) 'job_title': jobTitle,
            if (company != null && company.isNotEmpty) 'company': company,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Generate resume template API error: $e');
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
      } on TimeoutException {
        if (attempt > _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempt);
      } catch (e) {
        // On web, SocketException doesn't exist; catch generic exceptions
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
    debugPrint('📡 API Response [${response.statusCode}]: ${response.body}');

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
      throw 'Resource not found.';
    } else if (response.statusCode == 500) {
      throw 'Server error. Please try again later.';
    } else {
      try {
        final error = jsonDecode(response.body);
        final errorMessage = error['message'] ?? error['detail'];
        if (errorMessage is String) {
          throw errorMessage;
        } else if (errorMessage is List && errorMessage.isNotEmpty) {
           throw errorMessage[0]['msg'] ?? 'Validation error';
        }
        throw 'Request failed with status: ${response.statusCode}';
      } catch (e) {
        if (e is String) rethrow;
        throw 'Request failed with status: ${response.statusCode}';
      }
    }
  }

  /// Handle errors
  String _handleError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network is unreachable')) {
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error is http.ClientException) {
      return 'Connection failed. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid response format from server.';
    } else if (error is String) {
      return error;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ==================== USER PREFERENCES APIs ====================

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences({
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/preferences/$userId');

      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Get preferences API error: $e');
      throw _handleError(e);
    }
  }

  /// Save user preferences
  Future<Map<String, dynamic>> saveUserPreferences({
    required String userId,
    required List<String> targetSkills,
    required int dailyStudyHoursGoal,
    required String learningPace,
    required List<String> preferredCategories,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/preferences/$userId');

      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'target_skills': targetSkills,
            'daily_study_hours_goal': dailyStudyHoursGoal,
            'learning_pace': learningPace,
            'preferred_categories': preferredCategories,
          }),
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Save preferences API error: $e');
      throw _handleError(e);
    }
  }

  // ==================== CAREER ROADMAP APIs ====================

  /// Get all career roadmaps (for dropdown listing)
  Future<List<CareerRoadmap>> getAllRoadmaps() async {
    try {
      final url = Uri.parse('$_baseUrl${AppConstants.endpointRoadmaps}');
      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );
      final data = _handleResponse(response);
      final List<dynamic> list = data['roadmaps'] ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((j) => CareerRoadmap.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('❌ Get all roadmaps error: $e');
      throw _handleError(e);
    }
  }

  /// Get a single roadmap with all its phases
  Future<CareerRoadmap> getRoadmapById(String roadmapId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl${AppConstants.endpointRoadmaps}/$roadmapId');
      debugPrint('Fetching roadmap: $roadmapId');
      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );
      final data = _handleResponse(response);
      debugPrint('Roadmap API Response: $data');
      return CareerRoadmap.fromJson(
          data['roadmap'] as Map<String, dynamic>? ?? {});
    } catch (e) {
      debugPrint('❌ Get roadmap by id error: $e');
      throw _handleError(e);
    }
  }

  /// Get personalised roadmap recommendation for a user
  Future<RoadmapRecommendation> getRoadmapRecommendation(
      String userId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl${AppConstants.endpointRoadmapRecommendation}/$userId');
      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );
      final data = _handleResponse(response);
      return RoadmapRecommendation.fromJson(data);
    } catch (e) {
      debugPrint('❌ Get roadmap recommendation error: $e');
      throw _handleError(e);
    }
  }

  /// Get completed skill IDs for a user+roadmap
  Future<List<String>> getRoadmapProgress(
      String userId, String roadmapId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl${AppConstants.endpointRoadmapProgress}/$userId/$roadmapId');
      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );
      final data = _handleResponse(response);
      final List<dynamic> ids = data['completed_skill_ids'] ?? [];
      return ids.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('❌ Get roadmap progress error: $e');
      throw _handleError(e);
    }
  }

  /// Mark or unmark a skill as completed
  Future<bool> markSkillComplete({
    required String userId,
    required String roadmapId,
    required String phaseId,
    required String skillId,
    required bool isCompleted,
  }) async {
    try {
      final url = Uri.parse(
          '$_baseUrl${AppConstants.endpointRoadmapProgress}/skill/$userId');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
          body: jsonEncode({
            'roadmap_id': roadmapId,
            'phase_id': phaseId,
            'skill_id': skillId,
            'is_completed': isCompleted,
          }),
        ),
      );
      final data = _handleResponse(response);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Mark skill complete error: $e');
      throw _handleError(e);
    }
  }

  /// Get dashboard analytics
  ///
  /// Calls GET /api/dashboard/analytics/{userId}.
  /// Returns an empty analytics payload (has_data=false) when the user has
  /// not uploaded a resume yet, so the Flutter UI shows the onboarding card.
  Future<Map<String, dynamic>> getDashboardAnalytics(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/dashboard/analytics/$userId');
      final response = await _requestWithRetry(
        () async => _client.get(
          url,
          headers: _authHeadersSnapshot(await _getHeaders()),
        ),
      );
      final data = _handleResponse(response);
      // has_resume=false → transform to a has_data=false payload so the
      // dashboard model always has the same shape regardless of user state.
      if (data['has_resume'] == false) {
        return {
          'has_resume':        false,
          'has_data':          false,
          'career_readiness':  0,
          'resume_quality':    null,
          'skill_match':       null,
          'job_readiness':     null,
          'profile_completion': 0,
          'missing_skills':    [],
          'priority_skills':   [],
        };
      }
      return data;
    } catch (e) {
      debugPrint('❌ Get dashboard analytics error: $e');
      throw _handleError(e);
    }
  }

  // ==================== PAYMENT APIs ====================

  /// Initialize SSLCommerz Payment
  Future<String?> initPayment({
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/payment/init');
      final response = await _requestWithRetry(
        () async => _client.post(
          url,
          headers: await _getHeaders(),
          body: jsonEncode({
            'amount': amount,
            'customer_name': customerName,
            'customer_email': customerEmail,
          }),
        ),
      );
      
      final data = _handleResponse(response);
      return data['gateway_url'] as String?;
    } catch (e) {
      debugPrint('❌ Init payment error: $e');
      throw _handleError(e);
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _client.close();
  }
}