import 'package:flutter/material.dart';
//import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
//import '../../services/auth_service.dart';
import '../../models/skill_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
class SkillRoadmapScreen extends StatefulWidget {
  final List<String>? missingSkills;

  const SkillRoadmapScreen({
    super.key,
    this.missingSkills,
  });

  @override
  State<SkillRoadmapScreen> createState() => _SkillRoadmapScreenState();
}

class _SkillRoadmapScreenState extends State<SkillRoadmapScreen> {
  final ApiService _apiService = ApiService();
  List<SkillRoadmap> _roadmaps = [];
  bool _isLoading = false;
  String _selectedMarket = AppConstants.marketBangladesh;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadMarket();
    if (widget.missingSkills != null && widget.missingSkills!.isNotEmpty) {
      await _generateRoadmaps();
    }
  }

  Future<void> _loadMarket() async {
    final prefs = await SharedPreferences.getInstance();
    final market = prefs.getString(AppConstants.keyJobMarket);
    if (market != null) {
      setState(() => _selectedMarket = market);
    }
  }

  Future<void> _generateRoadmaps() async {
    if (widget.missingSkills == null || widget.missingSkills!.isEmpty) {
      Helpers.showErrorToast('No skills to generate roadmap');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roadmaps = await _apiService.generateSkillRoadmap(
        missingSkills: widget.missingSkills!,
        market: _selectedMarket,
      );

      setState(() {
        _roadmaps = roadmaps;
      });

      Helpers.showSuccessToast('Roadmap generated successfully! 🎉');
    } catch (e) {
      Helpers.showErrorToast('Failed to generate roadmap: $e');
      // For demo purposes, show mock data
      _loadMockRoadmaps();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadMockRoadmaps() {
    // Mock roadmap data for demo
    setState(() {
      _roadmaps = [
        SkillRoadmap(
          skillId: '1',
          skillName: 'Flutter Development',
          estimatedDays: 45,
          resources: [
            'https://flutter.dev/docs',
            'https://www.udemy.com/flutter-course',
          ],
          steps: [
            RoadmapStep(
              order: 1,
              title: 'Dart Fundamentals',
              description: 'Learn Dart programming language basics',
              durationDays: 7,
            ),
            RoadmapStep(
              order: 2,
              title: 'Flutter Widgets',
              description: 'Master StatelessWidget and StatefulWidget',
              durationDays: 10,
            ),
            RoadmapStep(
              order: 3,
              title: 'State Management',
              description: 'Learn Provider, Bloc, or Riverpod',
              durationDays: 14,
            ),
            RoadmapStep(
              order: 4,
              title: 'API Integration',
              description: 'Connect Flutter app with REST APIs',
              durationDays: 7,
            ),
            RoadmapStep(
              order: 5,
              title: 'Build Real Project',
              description: 'Create a complete Flutter application',
              durationDays: 7,
            ),
          ],
        ),

      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Roadmap'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _roadmaps.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Your Learning Roadmap',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow these personalized learning paths to master the required skills',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),

                      const SizedBox(height: 24),

                      // Total duration
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Duration',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                  Text(
                                    '${_calculateTotalDays()} days',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Roadmaps
                      ..._roadmaps.asMap().entries.map((entry) {
                        return _buildRoadmapCard(entry.value, entry.key);
                      }),

                      const SizedBox(height: 24),

                      // Start Learning button
                      CustomButton(
                        label: 'Start Learning Journey',
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.progressTracker,
                          );
                          Helpers.showSuccessToast(
                            'Good luck on your learning journey! 🚀',
                          );
                        },
                        icon: Icons.play_arrow,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Roadmap Available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a job match analysis to generate your personalized learning roadmap',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Analyze Job Match',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.jobDescription);
              },
              icon: Icons.analytics,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard(SkillRoadmap roadmap, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skill header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roadmap.skillName,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        '${roadmap.estimatedDays} days • ${roadmap.steps.length} steps',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.roadmapDetail,
                      arguments: {
                        'skill': roadmap,
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Steps preview (first 3)
            Text(
              'Learning Steps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            ...roadmap.steps.take(3).map((step) {
              return _buildStepPreview(step);
            }),

            if (roadmap.steps.length > 3) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.roadmapDetail,
                    arguments: {
                      'skill': roadmap,
                    },
                  );
                },
                child: Text('View all ${roadmap.steps.length} steps'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepPreview(RoadmapStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: step.isCompleted
                  ? AppTheme.successColor
                  : AppTheme.textSecondary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${step.order}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: step.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
                Text(
                  '${step.durationDays} days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalDays() {
    return _roadmaps.fold(0, (sum, roadmap) => sum + roadmap.estimatedDays);
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}