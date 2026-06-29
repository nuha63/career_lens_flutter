import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/resume_model.dart';
import '../../widgets/ats_score_card.dart';
import '../../widgets/skill_chip.dart';
import '../../widgets/custom_button.dart';

class ResumeResultScreen extends StatelessWidget {
  final ResumeAnalysisResult analysisResult;

  const ResumeResultScreen({
    super.key,
    required this.analysisResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ATS Score
            ATSScoreCard(
              score: analysisResult.atsScore,
              subtitle: 'Your resume compatibility score with ATS systems',
            ),

            const SizedBox(height: 32),

            // Detected Skills
            Text(
              'Detected Skills',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Skills found in your resume',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),

            if (analysisResult.detectedSkills.isEmpty)
              _buildEmptyState('No skills detected in your resume')
            else
              SkillList(
                skills: analysisResult.detectedSkills,
                areMatched: true,
              ),

            const SizedBox(height: 32),

            // Suggestions
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Tips to improve your ATS score',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),

            if (analysisResult.suggestions.isEmpty)
              _buildEmptyState('No suggestions available')
            else
              ...analysisResult.suggestions.asMap().entries.map((entry) {
                return _buildSuggestionItem(
                  context,
                  entry.key + 1,
                  entry.value,
                );
              }),

            const SizedBox(height: 32),

            // Statistics
            if (analysisResult.statistics.isNotEmpty) ...[
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildStatisticsCard(analysisResult.statistics),
              const SizedBox(height: 32),
            ],

            // Next Steps
            Text(
              'Next Steps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            CustomButton(
              label: 'Match with Job Description',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.jobDescription,
                  arguments: {
                    'resumeData': analysisResult,
                  },
                );
              },
              icon: Icons.work,
            ),

            const SizedBox(height: 12),

            CustomButton(
              label: 'View Skill Roadmap',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.skillRoadmap);
              },
              backgroundColor: AppTheme.secondaryColor,
              icon: Icons.map,
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

  Widget _buildSuggestionItem(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> statistics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: statistics.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatStatKey(entry.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatStatKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}