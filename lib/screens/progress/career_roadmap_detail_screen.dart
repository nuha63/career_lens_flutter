import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/career_roadmap_model.dart';
import '../../repositories/roadmap_repository.dart';
import '../../widgets/roadmap_timeline_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CareerRoadmapDetailScreen extends StatefulWidget {
  final String roadmapId;

  const CareerRoadmapDetailScreen({
    super.key,
    required this.roadmapId,
  });

  @override
  State<CareerRoadmapDetailScreen> createState() => _CareerRoadmapDetailScreenState();
}

class _CareerRoadmapDetailScreenState extends State<CareerRoadmapDetailScreen> {
  final RoadmapRepository _roadmapRepository = RoadmapRepository();
  bool _isLoading = true;
  String? _error;
  CareerRoadmap? _roadmap;
  List<String> _highlightedSkills = [];

  @override
  void initState() {
    super.initState();
    _loadRoadmapDetails();
  }

  Future<void> _loadRoadmapDetails() async {
    debugPrint('Received roadmapId: ${widget.roadmapId}');
    if (widget.roadmapId.isEmpty) {
      debugPrint('⚠️ Error: roadmapId is empty or null in CareerRoadmapDetailScreen.');
      setState(() {
        _error = 'Invalid roadmap ID.';
        _isLoading = false;
      });
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get user ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.keyUserId);

      // Fetch roadmap structure from repository (handles API -> cache -> templates)
      final roadmap = await _roadmapRepository.getRoadmapById(widget.roadmapId);
      debugPrint('Roadmap Name: ${roadmap.careerName}');
      debugPrint('Phases Count: ${roadmap.phases.length}');
      
      // Try to fetch progress from repository
      List<String> completedPhaseIds = [];
      if (userId != null) {
        completedPhaseIds = await _roadmapRepository.getRoadmapProgress(userId, widget.roadmapId);
      }
      debugPrint('Completed Phase IDs: $completedPhaseIds');

      // Calculate progress explicitly
      final total = roadmap.phases.length;
      final completed = completedPhaseIds.length;
      final progress = total == 0 ? 0.0 : (completed / total * 100);
      debugPrint('Calculated progress: $progress%');

      // Merge progress into roadmap phases (calculate based on skills)
      final updatedPhases = roadmap.phases.map((phase) {
        final totalSkills = phase.keySkills.length;
        int completedSkills = 0;
        final updatedSkills = phase.keySkills.map((s) {
          final isCompleted = completedPhaseIds.contains(s.id);
          if (isCompleted) completedSkills++;
          return s.copyWith(isCompleted: isCompleted);
        }).toList();
        
        final isPhaseCompleted = totalSkills > 0 && completedSkills == totalSkills;
        final completionPercentage = totalSkills > 0 ? (completedSkills / totalSkills * 100).round() : 0;
        
        return phase.copyWith(
          isCompleted: isPhaseCompleted,
          completionPercentage: completionPercentage,
          keySkills: updatedSkills,
        );
      }).toList();

      setState(() {
        _roadmap = roadmap.copyWithPhases(updatedPhases);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSkillCompletion(RoadmapPhase phase, RoadmapSkill skill) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.keyUserId);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save progress')),
      );
      return;
    }

    final newCompletionStatus = !skill.isCompleted;

    // Optimistic UI update
    setState(() {
      final updatedPhases = _roadmap!.phases.map((p) {
        if (p.id == phase.id) {
          final updatedSkills = p.keySkills.map((s) {
            if (s.id == skill.id) return s.copyWith(isCompleted: newCompletionStatus);
            return s;
          }).toList();
          
          final completedSkills = updatedSkills.where((s) => s.isCompleted).length;
          final isPhaseCompleted = p.keySkills.isNotEmpty && completedSkills == p.keySkills.length;
          
          return p.copyWith(
            keySkills: updatedSkills,
            isCompleted: isPhaseCompleted,
            completionPercentage: p.keySkills.isNotEmpty ? (completedSkills / p.keySkills.length * 100).round() : 0,
          );
        }
        return p;
      }).toList();
      _roadmap = _roadmap!.copyWithPhases(updatedPhases);
    });

    try {
      final success = await _roadmapRepository.markSkillComplete(
        userId: userId,
        roadmapId: _roadmap!.id,
        phaseId: phase.id,
        skillId: skill.id,
        isCompleted: newCompletionStatus,
      );

      if (!success) {
        throw Exception('Failed to update progress on backend');
      }
    } catch (e) {
      // Revert UI on failure
      setState(() {
        final updatedPhases = _roadmap!.phases.map((p) {
          if (p.id == phase.id) return p;
          return p;
        }).toList();
        _roadmap = _roadmap!.copyWithPhases(updatedPhases);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving progress: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _roadmap?.careerName ?? 'Roadmap',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRoadmapDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_roadmap == null) {
      return const Center(child: Text('Roadmap not found'));
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Path to ${_roadmap!.careerName}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _roadmap!.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 16),
                
                // Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall Progress',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_roadmap!.overallCompletionPercentage}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _roadmap!.overallCompletionPercentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_roadmap!.completedPhases} of ${_roadmap!.totalPhases} phases completed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Phases',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverToBoxAdapter(
            child: _roadmap!.phases.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No roadmap phases found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : RoadmapTimelineWidget(
                    phases: _roadmap!.phases,
                    highlightedSkills: _highlightedSkills,
                    onPhaseTap: (phase) {
                      // Show bottom sheet to toggle completion
                      _showPhaseDetailsBottomSheet(phase);
                    },
                  ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  void _showPhaseDetailsBottomSheet(RoadmapPhase phase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Dynamically fetch the latest phase data from the outer state
            final currentPhase = _roadmap?.phases.firstWhere(
                  (p) => p.id == phase.id,
                  orElse: () => phase,
                ) ?? phase;

            final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phase ${currentPhase.phaseNumber}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      currentPhase.phaseTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentPhase.phaseDescription,
                      style: TextStyle(height: 1.5, color: isDark ? Colors.grey.shade400 : AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    if (currentPhase.keySkills.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Skills:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          Text(
                            '${currentPhase.keySkills.where((s) => s.isCompleted).length} / ${currentPhase.keySkills.length} Completed',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Render skill checkboxes
                      ...currentPhase.keySkills.map((skill) => CheckboxListTile(
                        value: skill.isCompleted,
                        onChanged: (val) async {
                          // Optimistically update modal state
                          setModalState(() {});
                          await _toggleSkillCompletion(currentPhase, skill);
                          // Ensure modal gets final state from outer widget
                          if (mounted) {
                            setModalState(() {});
                          }
                        },
                        title: Text(
                          skill.skillName,
                          style: TextStyle(
                            fontSize: 15,
                            color: skill.isCompleted ? (isDark ? Colors.grey.shade600 : AppTheme.textSecondary) : textColor,
                            decoration: skill.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.successColor,
                        checkColor: Colors.white,
                        side: BorderSide(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      )),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
