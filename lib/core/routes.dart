import 'package:flutter/material.dart';
import '../models/job_role_model.dart';
import '../models/resume_model.dart';
import '../models/skill_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/main_layout.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/home/market_selection_screen.dart';
import '../screens/job/job_description_screen.dart';
import '../screens/job/job_match_screen.dart';
import '../screens/job/salary_prediction_screen.dart';
import '../screens/progress/job_readiness_screen.dart';
import '../screens/progress/progress_tracker_screen.dart';
import '../screens/resume/resume_result_screen.dart';
import '../screens/resume/resume_upload_screen.dart';
import '../screens/roadmap/roadmap_detail_screen.dart';
import '../screens/roadmap/skill_roadmap_screen.dart';
import '../screens/progress/career_roadmap_screen.dart';
import '../screens/progress/career_roadmap_detail_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/preferences_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/home/premium_subscription_screen.dart';
import 'constants.dart';
//import 'package:career_lens_flutter/screens/roadmap/roadmap_detail_screen.dart';
//import 'package:career_lens_flutter/screens/roadmap/skill_roadmap_screen.dart';
class AppRoutes {
  // Route Names
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String adminDashboard = '/admin-dashboard';
  static const String marketSelection = '/market-selection';
  static const String premium = '/premium';
  static const String resumeUpload = '/resume-upload';
  static const String resumeResult = '/resume-result';
  static const String jobDescription = '/job-description';
  static const String jobMatch = '/job-match';
  static const String skillRoadmap = '/skill-roadmap';
  static const String roadmapDetail = '/roadmap-detail';
  static const String progressTracker = '/progress-tracker';
  static const String jobReadiness = '/job-readiness';
  static const String profile = '/profile';
  static const String preferences = '/preferences';
  static const String careerRoadmaps = '/career-roadmaps';
  static const String careerRoadmapDetail = '/career-roadmap-detail';
  static const String salaryPrediction = '/salary-prediction';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Initial Route
  static const String initialRoute = login;

  // Route Generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final mapArgs = args is Map<String, dynamic> ? args : <String, dynamic>{};

    switch (settings.name) {
      case splash:
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());

      case verifyEmail:
        final email = (mapArgs['email'] as String?) ?? '';
        return MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email),
        );

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case resetPassword:
        final token = (mapArgs['token'] as String?) ?? '';
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(token: token),
        );

      case dashboard:
        return MaterialPageRoute(builder: (_) => const MainLayoutScreen());

      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      case premium:
        return MaterialPageRoute(builder: (_) => const PremiumSubscriptionScreen());

      case marketSelection:
        return MaterialPageRoute(builder: (_) => const MarketSelectionScreen());

      case resumeUpload:
        final market = (mapArgs['market'] as String?) ?? AppConstants.marketBangladesh;
        return MaterialPageRoute(
          builder: (_) => ResumeUploadScreen(selectedMarket: market),
        );

      case resumeResult:
        final resultArg = mapArgs['result'];
        final parsedResult = resultArg is ResumeAnalysisResult
            ? resultArg
            : ResumeAnalysisResult.fromApiResponse(
                resultArg is Map<String, dynamic> ? resultArg : <String, dynamic>{},
              );
        return MaterialPageRoute(
          builder: (_) => ResumeResultScreen(analysisResult: parsedResult),
        );

      case jobDescription:
        return MaterialPageRoute(
          builder: (_) => JobDescriptionScreen(resumeData: mapArgs['resumeData']),
        );

      case jobMatch:
        final resultArg = mapArgs['result'];
        final parsedResult = resultArg is JobMatchResult
            ? resultArg
            : JobMatchResult.fromApiResponse(
                resultArg is Map<String, dynamic> ? resultArg : <String, dynamic>{},
                market: (mapArgs['market'] as String?) ?? AppConstants.marketGlobal,
              );
        return MaterialPageRoute(
          builder: (_) => JobMatchScreen(matchResult: parsedResult),
        );

      case skillRoadmap:
        final skillsArg = mapArgs['skills'];
        return MaterialPageRoute(
          builder: (_) => SkillRoadmapScreen(
            missingSkills: skillsArg is List ? skillsArg.cast<String>() : null,
          ),
        );

      case roadmapDetail:
        final skill = mapArgs['skill'];
        if (skill is SkillRoadmap) {
          return MaterialPageRoute(
            builder: (_) => RoadmapDetailScreen(skill: skill),
          );
        }
        return _errorRoute('Missing roadmap details for this screen.');

      case progressTracker:
        return MaterialPageRoute(builder: (_) => const ProgressTrackerScreen());

      case jobReadiness:
        return MaterialPageRoute(builder: (_) => const JobReadinessScreen());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case preferences:
        return MaterialPageRoute(builder: (_) => const PreferencesScreen());

      case careerRoadmaps:
        return MaterialPageRoute(builder: (_) => const CareerRoadmapScreen());

      case careerRoadmapDetail:
        final roadmapId = mapArgs['roadmapId'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => CareerRoadmapDetailScreen(roadmapId: roadmapId),
        );

      case salaryPrediction:
        return MaterialPageRoute(
          builder: (_) => const SalaryPredictionScreen(),
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Navigation Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
