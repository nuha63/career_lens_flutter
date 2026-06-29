import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/ml_api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/custom_button.dart';

class MLProgressTrackerScreen extends StatefulWidget {
  const MLProgressTrackerScreen({super.key});

  @override
  State<MLProgressTrackerScreen> createState() => _MLProgressTrackerScreenState();
}

class _MLProgressTrackerScreenState extends State<MLProgressTrackerScreen> {
  final MLApiService _mlService = getMLApiService();
  final AuthService _authService = AuthService();
  
  String? _userId;
  bool _isLoading = true;
  
  Map<String, dynamic>? _userProgress;

  @override
  void initState() {
    super.initState();
    _loadUserProgress();
  }

  Future<void> _loadUserProgress() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.keyUserId);

      if (userId == null || userId.isEmpty) {
        throw 'User not authenticated';
      }

      setState(() => _userId = userId);

      final result = await _mlService.getUserProgress(userId: userId);
      final progress = result as Map<String, dynamic>;

      if (mounted) {
        setState(() => _userProgress = progress);
      }
    } catch (e) {
      debugPrint('Failed to load progress: $e');
      Helpers.showErrorToast('Failed to load progress: $e');
      
      // Load mock data for demo
      if (mounted) {
        _loadMockProgress();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadMockProgress() {
    setState(() {
      _userProgress = {
        'user_id': _userId ?? 'user_123',
        'job_readiness_score': 68.0,
        'resumes_analyzed': 3,
        'jobs_matched': 7,
        'skill_gaps_analyzed': 2,
        'target_skills': ['Flutter', 'Python', 'AWS'],
        'learning_pace': 'medium',
        'avg_resume_score': 0.72,
        'avg_match_score': 0.65,
        'last_activity': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress Tracker')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userProgress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress Tracker')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load progress', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Retry',
                onPressed: _loadUserProgress,
              ),
            ],
          ),
        ),
      );
    }

    final readinessScore = (_userProgress?['job_readiness_score'] as num?)?.toDouble() ?? 0.0;
    final resumesAnalyzed = _userProgress?['resumes_analyzed'] as int? ?? 0;
    final jobsMatched = _userProgress?['jobs_matched'] as int? ?? 0;
    final skillGapsAnalyzed = _userProgress?['skill_gaps_analyzed'] as int? ?? 0;
    final avgResumeScore = (_userProgress?['avg_resume_score'] as num?)?.toDouble() ?? 0.0;
    final avgMatchScore = (_userProgress?['avg_match_score'] as num?)?.toDouble() ?? 0.0;
    final targetSkills = List<String>.from(_userProgress?['target_skills'] ?? []);
    final learningPace = _userProgress?['learning_pace'] as String? ?? 'medium';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserProgress,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Readiness Score
            Text(
              'Job Readiness',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${readinessScore.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: readinessScore / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getReadinessLabel(readinessScore),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Statistics Grid
            Text(
              'Activity Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard('Resumes Analyzed', resumesAnalyzed.toString(), Icons.description),
                _buildStatCard('Jobs Matched', jobsMatched.toString(), Icons.work),
                _buildStatCard('Skill Gaps', skillGapsAnalyzed.toString(), Icons.trending_up),
                _buildStatCard('Avg Resume Score', '${(avgResumeScore * 100).toStringAsFixed(0)}%', Icons.grade),
              ],
            ),
            const SizedBox(height: 32),

            // Target Skills
            if (targetSkills.isNotEmpty) ...[
              Text(
                'Target Skills',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: targetSkills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Learning Pace
            Text(
              'Learning Pace',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    learningPace.capitalize(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Icon(
                    _getLearningPaceIcon(learningPace),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            CustomButton(
              label: 'View Detailed Analysis',
              onPressed: () {
                Helpers.showSuccessToast('Detailed view coming soon!');
              },
            ),
            const SizedBox(height: 12),
            CustomOutlinedButton(
            text: 'Download Report',
            onPressed: () { Helpers.showSuccessToast('Report generation coming soon!'); },
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: AppTheme.primaryColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getReadinessLabel(double score) {
    if (score >= 80) return 'Excellent - Ready to apply!';
    if (score >= 60) return 'Good - Almost ready';
    if (score >= 40) return 'Fair - Keep improving';
    return 'Needs improvement';
  }

  IconData _getLearningPaceIcon(String pace) {
    switch (pace.toLowerCase()) {
      case 'fast':
        return Icons.speed;
      case 'slow':
        return Icons.slow_motion_video;
      default:
        return Icons.trending_flat;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
