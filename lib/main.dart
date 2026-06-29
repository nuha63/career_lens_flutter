import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/routes.dart';
import 'services/auth_service.dart';
import 'repositories/auth_repository.dart';
import 'repositories/resume_repository.dart';
import 'repositories/job_match_repository.dart';
import 'repositories/progress_repository.dart';
import 'services/admin_service.dart';
import 'repositories/roadmap_repository.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize auth state
  final authService = AuthService();
  await authService.initializeAuth();

  runApp(CareerLensApp(authService: authService));
}

class CareerLensApp extends StatelessWidget {
  final AuthService authService;

  const CareerLensApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Low-level services ───────────────────────────────────────────
        Provider<AuthService>(
          create: (_) => authService,
        ),

        // ── Repositories (clean-architecture layer) ──────────────────────
        // AuthRepository: login, signup, preferences
        Provider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),

        // ResumeRepository: file upload, ML analysis, skill-gap
        Provider<ResumeRepository>(
          create: (_) => ResumeRepository(),
        ),

        // JobMatchRepository: job matching, salary prediction, history
        Provider<JobMatchRepository>(
          create: (_) => JobMatchRepository(),
        ),

        // AdminService: admin APIs
        Provider<AdminService>(
          create: (_) => AdminService(),
        ),

        // ProgressRepository: Job Readiness Score, skill tracking
        Provider<ProgressRepository>(
          create: (_) => ProgressRepository(),
        ),

        // RoadmapRepository: career roadmaps with cache + fallback templates
        Provider<RoadmapRepository>(
          create: (_) => RoadmapRepository(),
        ),
      ],
      child: MaterialApp(
        title: 'CareerLens',
        debugShowCheckedModeBanner: false,

        // Theme
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

        // Routes
        initialRoute: authService.isAuthenticated ? AppRoutes.dashboard : AppRoutes.initialRoute,
        onGenerateRoute: AppRoutes.generateRoute,

        // Builder for global configurations
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0), // Prevent system font scaling
            ),
            child: child!,
          );
        },
      ),
    );
  }
}