import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/job_role_model.dart';
import '../../widgets/ats_score_card.dart';
import '../../widgets/skill_chip.dart';
import '../../widgets/custom_button.dart';

class JobMatchScreen extends StatelessWidget {
  final JobMatchResult matchResult;

  const JobMatchScreen({
    super.key,
    required this.matchResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Match Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Title
            Text(
              matchResult.jobTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                matchResult.market == 'bangladesh'
                    ? '🇧🇩 Bangladesh'
                    : '🌍 Global',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Match Score
            ATSScoreCard(
              score: matchResult.matchScore,
              title: 'Match Score',
              subtitle: 'How well your resume matches this job',
            ),

            const SizedBox(height: 32),

            // Matched Skills
            Text(
              'Matched Skills ✓',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Skills you have that match the job requirements',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),

            if (matchResult.matchedSkills.isEmpty)
              _buildEmptyState('No matching skills found')
            else
              SkillList(
                skills: matchResult.matchedSkills,
                areMatched: true,
              ),

            const SizedBox(height: 32),

            // Missing Skills
            Text(
              'Missing Skills ⚠️',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Skills required for this job that you need to learn',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),

            if (matchResult.missingSkills.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: AppTheme.successColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Great! You have all the required skills for this job! 🎉',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              SkillList(
                skills: matchResult.missingSkills,
                areMatched: false,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommendation',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            matchResult.missingSkills.isNotEmpty
                                ? 'Learn ${matchResult.missingSkills.first} to increase score to ${((matchResult.matchScore + 0.07) * 100).toInt()}%'
                                : 'Consider learning these skills to increase your chances. '
                                  'We can generate a personalized learning roadmap for you!',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Next Steps
            Text(
              'Next Steps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            if (matchResult.missingSkills.isNotEmpty)
              CustomButton(
                label: 'Generate Skill Roadmap',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.skillRoadmap,
                    arguments: {
                      'skills': matchResult.missingSkills,
                    },
                  );
                },
                icon: Icons.map,
              ),

            const SizedBox(height: 12),

            CustomButton(
              label: 'Track Your Progress',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.progressTracker);
              },
              backgroundColor: AppTheme.secondaryColor,
              icon: Icons.trending_up,
            ),

            const SizedBox(height: 12),

            CustomButton(
              label: 'Try Another Job',
              onPressed: () {
                Navigator.pop(context);
              },
              backgroundColor: AppTheme.textSecondary,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}