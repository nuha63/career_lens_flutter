import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/skill_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class RoadmapDetailScreen extends StatefulWidget {
  final SkillRoadmap skill;

  const RoadmapDetailScreen({
    super.key,
    required this.skill,
  });

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late List<RoadmapStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = List.from(widget.skill.steps);
  }

  void _toggleStepCompletion(int index) {
    setState(() {
      _steps[index] = _steps[index].copyWith(
        isCompleted: !_steps[index].isCompleted,
      );
    });

    if (_steps[index].isCompleted) {
      Helpers.showSuccessToast('Step completed! 🎉');
    }
  }

  Future<void> _openResource(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Helpers.showErrorToast('Could not open link');
      }
    } catch (e) {
      Helpers.showErrorToast('Invalid URL: $e');
    }
  }

  double _getProgress() {
    if (_steps.isEmpty) return 0.0;
    final completed = _steps.where((step) => step.isCompleted).length;
    return completed / _steps.length;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.skill.skillName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress card
            Container(
              padding: const EdgeInsets.all(20),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Progress',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(progress * 100).toInt()}% Complete',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_steps.where((s) => s.isCompleted).length} / ${_steps.length} steps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${widget.skill.estimatedDays} days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Learning Steps
            Text(
              'Learning Steps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            ..._steps.asMap().entries.map((entry) {
              return _buildStepCard(entry.value, entry.key);
            }),

            const SizedBox(height: 32),

            // Resources
            if (widget.skill.resources.isNotEmpty) ...[
              Text(
                'Learning Resources',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              ...widget.skill.resources.map((resource) {
                return _buildResourceCard(resource);
              }),

              const SizedBox(height: 32),
            ],

            // Complete button
            if (progress >= 1.0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: AppTheme.successColor,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Congratulations! 🎉',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have completed all steps for ${widget.skill.skillName}!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(RoadmapStep step, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _toggleStepCompletion(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: step.isCompleted
                      ? AppTheme.successColor
                      : Colors.transparent,
                  border: Border.all(
                    color: step.isCompleted
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: step.isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${step.order}: ${step.title}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: step.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: step.isCompleted
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${step.durationDays} days',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(String resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.link,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          resource,
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.open_in_new,
          color: AppTheme.primaryColor,
        ),
        onTap: () => _openResource(resource),
      ),
    );
  }
}