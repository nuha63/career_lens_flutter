import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../core/theme.dart';

/// Linear progress bar widget
class CustomProgressBar extends StatelessWidget {
  final double progress;
  final String? label;
  final bool showPercentage;
  final double height;

  const CustomProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.showPercentage = true,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();
    final color = AppTheme.getProgressColor(progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (showPercentage)
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        LinearPercentIndicator(
          padding: EdgeInsets.zero,
          lineHeight: height,
          percent: progress.clamp(0.0, 1.0),
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.2),
          barRadius: Radius.circular(height / 2),
          animation: true,
          animationDuration: 1000,
        ),
      ],
    );
  }
}

/// Circular progress widget
class CustomCircularProgress extends StatelessWidget {
  final double progress;
  final String label;
  final double size;

  const CustomCircularProgress({
    super.key,
    required this.progress,
    required this.label,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();
    final color = AppTheme.getProgressColor(progress);

    return Column(
      children: [
        SizedBox(
          height: size,
          width: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: size,
                width: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}