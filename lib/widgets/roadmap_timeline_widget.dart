import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/career_roadmap_model.dart';

/// A vertical timeline widget that renders career roadmap phases.
/// Each node connects to the next with a vertical line.
class RoadmapTimelineWidget extends StatelessWidget {
  final List<RoadmapPhase> phases;
  final List<String> highlightedSkills;
  final ValueChanged<RoadmapPhase>? onPhaseTap;

  const RoadmapTimelineWidget({
    super.key,
    required this.phases,
    this.highlightedSkills = const [],
    this.onPhaseTap,
  });

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) return const SizedBox.shrink();
    return Column(
      children: phases.asMap().entries.map((entry) {
        final index = entry.key;
        final phase = entry.value;
        final isLast = index == phases.length - 1;

        // Determine the "active" phase: first incomplete
        final firstIncomplete =
            phases.indexWhere((p) => !p.isCompleted);
        final isActive = index == firstIncomplete;

        return _TimelineNode(
          phase: phase,
          isLast: isLast,
          isActive: isActive,
          highlightedSkills: highlightedSkills,
          onTap: onPhaseTap != null ? () => onPhaseTap!(phase) : null,
        );
      }).toList(),
    );
  }
}


class _TimelineNode extends StatefulWidget {
  final RoadmapPhase phase;
  final bool isLast;
  final bool isActive;
  final List<String> highlightedSkills;
  final VoidCallback? onTap;

  const _TimelineNode({
    required this.phase,
    required this.isLast,
    required this.isActive,
    required this.highlightedSkills,
    this.onTap,
  });

  @override
  State<_TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<_TimelineNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TimelineNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _nodeColor {
    if (widget.phase.isCompleted) return AppTheme.successColor;
    if (widget.isActive) return AppTheme.primaryColor;
    return AppTheme.textSecondary.withOpacity(0.4);
  }

  // Check if any key skill in this phase matches a highlighted skill
  bool get _hasHighlightedSkill {
    if (widget.highlightedSkills.isEmpty) return false;
    final highlightLower =
        widget.highlightedSkills.map((s) => s.toLowerCase()).toSet();
    return widget.phase.keySkills
        .any((s) => highlightLower.contains(s.skillName.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final highlight = _hasHighlightedSkill;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Timeline column (dot + connector line) ───
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Dot / circle
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale =
                        widget.isActive ? _pulseAnimation.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: phase.isCompleted
                          ? _nodeColor
                          : (widget.isActive
                              ? _nodeColor.withOpacity(0.15)
                              : _nodeColor.withOpacity(0.15)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _nodeColor,
                        width: widget.isActive ? 2.5 : 2,
                      ),
                      boxShadow: widget.isActive
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: phase.isCompleted
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : Text(
                              '${phase.phaseNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.isActive
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                    ),
                  ),
                ),
                // Connector line
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            phase.isCompleted
                                ? AppTheme.successColor.withOpacity(0.6)
                                : AppTheme.textSecondary.withOpacity(0.2),
                            AppTheme.textSecondary.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Phase content card ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: phase.isCompleted
                        ? AppTheme.successColor.withOpacity(0.05)
                        : widget.isActive
                            ? AppTheme.primaryColor.withOpacity(0.06)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: highlight
                          ? AppTheme.warningColor.withOpacity(0.7)
                          : phase.isCompleted
                              ? AppTheme.successColor.withOpacity(0.3)
                              : widget.isActive
                                  ? AppTheme.primaryColor.withOpacity(0.4)
                                  : Colors.grey.shade200,
                      width: highlight ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row: title + duration badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase.phaseTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: phase.isCompleted
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                                    decoration: phase.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DurationBadge(weeks: phase.estimatedWeeks),
                        ],
                      ),

                      // Description
                      const SizedBox(height: 6),
                      Text(
                        phase.phaseDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                      ),

                      // Key skills chips
                      if (phase.keySkills.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: phase.keySkills.take(4).map((skill) {
                            final isHighlighted = widget.highlightedSkills
                                .any((h) =>
                                    h.toLowerCase() == skill.skillName.toLowerCase());
                            return _SkillChip(
                              label: skill.skillName,
                              isHighlighted: isHighlighted,
                            );
                          }).toList(),
                        ),
                      ],

                      // Highlighted notice
                      if (highlight) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 12,
                                  color: AppTheme.warningColor),
                              const SizedBox(width: 4),
                              Text(
                                'Skills gap detected here',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Active phase "Continue" pill
                      if (widget.isActive) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Start here →',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DurationBadge extends StatelessWidget {
  final int weeks;
  const _DurationBadge({required this.weeks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: AppTheme.primaryColor),
          const SizedBox(width: 3),
          Text(
            '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class _SkillChip extends StatelessWidget {
  final String label;
  final bool isHighlighted;

  const _SkillChip({required this.label, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final color =
        isHighlighted ? AppTheme.warningColor : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
