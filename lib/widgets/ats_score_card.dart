import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../core/theme.dart';

/// ATS Score Display Card
class ATSScoreCard extends StatelessWidget {
  final int score;
  final String title;
  final String? subtitle;

  const ATSScoreCard({
    super.key,
    required this.score,
    this.title = 'ATS Score',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getATSScoreColor(score);
    final status = _getScoreStatus(score);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: score / 100,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$score',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'out of 100',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              progressColor: color,
              backgroundColor: color.withValues(alpha: 0.2),
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: 1500,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getScoreStatus(int score) {
    if (score >= 80) return '🎉 Excellent Match';
    if (score >= 60) return '👍 Good Match';
    if (score >= 40) return '⚠️ Fair Match';
    return '❌ Needs Improvement';
  }
}