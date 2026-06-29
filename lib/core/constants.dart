import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyAccessToken = 'access_token';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyJobMarket = 'job_market';
  
  // API Constants
  // Read from .env file at runtime (BACKEND_URL)
  static String get baseUrl {
    if (kReleaseMode) {
      return dotenv.env['BACKEND_URL'] ?? 'https://carrerlensbackend.onrender.com';
    } else {
      return 'https://carrerlensbackend.onrender.com'; // Default for local network testing
    }
  }
  static const Duration apiTimeout = Duration(seconds: 90);

  // Resume Upload
  static const List<String> allowedFileTypes = ['pdf', 'doc', 'docx'];
  static const int maxFileSizeMB = 10;
  
  // API Endpoints
  static const String endpointLogin = '/auth/login';
  static const String endpointSignup = '/auth/signup';
  static const String endpointUploadResume = '/api/upload-resume';
  static const String endpointAnalyzeResume = '/api/analyze-resume';
  static const String endpointMatchJob = '/api/job-match';
  static const String endpointSkillGap = '/api/skill-gap';
  static const String endpointJobReadiness = '/api/job-readiness';
  static const String endpointSkillRoadmap = '/api/skill-roadmap';
  static const String endpointProgressUpdate = '/api/progress/update';
  static const String endpointProgressGet = '/api/progress';

  // Resume Builder / Enhanced endpoints
  static const String endpointParseResumeFile = '/api/enhanced/parse-resume-file';
  static const String endpointAnalyzeJob = '/api/resume-builder/analyze-job';
  static const String endpointOptimizeResume = '/api/resume-builder/optimize-resume';
  static const String endpointGenerateTemplate = '/api/resume-builder/generate-template';

  // Career Roadmap endpoints
  static const String endpointRoadmaps = '/roadmaps';
  static const String endpointRoadmapRecommendation = '/roadmaps/recommendations';
  static const String endpointRoadmapProgress = '/roadmaps/progress';
  
  // Market/Region Options
  static const String regionBangladesh = 'bd';
  static const String regionGlobal = 'global';
  static const String marketBangladesh = 'bangladesh';
  static const String marketGlobal = 'global';
  
  // App Constants
  static const String appName = 'CareerLens';
  static const String appVersion = '1.0.0';
}
