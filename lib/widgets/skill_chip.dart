import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Skill chip widget
class SkillChip extends StatelessWidget {
  final String label;
  final bool isMatched;
  final VoidCallback? onTap;
  final bool showIcon;

  const SkillChip({
    super.key,
    required this.label,
    this.isMatched = false,
    this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMatched
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : AppTheme.warningColor.withValues(alpha: 0.1),
          border: Border.all(
            color: isMatched ? AppTheme.successColor : AppTheme.warningColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                isMatched ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: isMatched ? AppTheme.successColor : AppTheme.warningColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isMatched ? AppTheme.successColor : AppTheme.warningColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skill list widget
class SkillList extends StatelessWidget {
  final List<String> skills;
  final bool areMatched;

  const SkillList({
    super.key,
    required this.skills,
    this.areMatched = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map((skill) => SkillChip(
                label: skill,
                isMatched: areMatched,
              ))
          .toList(),
    );
  }
}