import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/ml_api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class SkillGapAnalyzerScreen extends StatefulWidget {
  const SkillGapAnalyzerScreen({super.key});

  @override
  State<SkillGapAnalyzerScreen> createState() => _SkillGapAnalyzerScreenState();
}

class _SkillGapAnalyzerScreenState extends State<SkillGapAnalyzerScreen> {
  final MLApiService _mlService = getMLApiService();
  final AuthService _authService = AuthService();
  
  String? _userId;
  bool _isAnalyzing = false;
  
  final TextEditingController _targetJobController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  List<String> _userSkills = [];
  
  Map<String, dynamic>? _gapResult;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString(AppConstants.keyUserId);
    });
  }

  void _addSkill() {
    final skill = _skillsController.text.trim();
    if (skill.isNotEmpty && !_userSkills.contains(skill)) {
      setState(() {
        _userSkills.add(skill);
        _skillsController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() => _userSkills.remove(skill));
  }

  Future<void> _analyzeGaps() async {
    if (_targetJobController.text.isEmpty) {
      Helpers.showErrorToast('Please enter a target job');
      return;
    }

    if (_userSkills.isEmpty) {
      Helpers.showErrorToast('Please add at least one skill');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await _mlService.analyzeSkillGaps(
        userSkills: _userSkills,
        targetJob: _targetJobController.text,
        userId: _userId,
      );

      final data = result['data'] as Map<String, dynamic>?;
      
      if (data != null && mounted) {
        setState(() => _gapResult = data);
        Helpers.showSuccessToast('Skill gaps analyzed!');
      }
    } catch (e) {
      Helpers.showErrorToast('Analysis failed: $e');
      debugPrint('Skill gap analysis error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gapResult != null) {
      return _buildResultView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Gap Analyzer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identify Your Skill Gaps',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Discover what skills you need to learn for your target job',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // Target Job
            Text('Target Job', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _targetJobController,
              decoration: InputDecoration(
                hintText: 'e.g., Senior Flutter Developer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Your Skills
            Text('Your Current Skills', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            
            // Skill input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillsController,
                    decoration: InputDecoration(
                      hintText: 'Add a skill',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _addSkill,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Skills list
            if (_userSkills.isEmpty)
              Text(
                'No skills added yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _userSkills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    onDeleted: () => _removeSkill(skill),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),

            // Analyze Button
            CustomButton(
              label: _isAnalyzing ? 'Analyzing...' : 'Analyze Gaps',
              onPressed: _isAnalyzing ? null : _analyzeGaps,
              isLoading: _isAnalyzing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final missingSkills = List<String>.from(_gapResult?['missing_skills'] ?? []);
    final prioritySkills = List<String>.from(_gapResult?['priority_skills'] ?? []);
    final totalMissing = _gapResult?['total_missing'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Gap Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _gapResult = null);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Job
            Text(
              _targetJobController.text,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skills Gap',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalMissing missing skills',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    totalMissing <= 3 ? Icons.check_circle : Icons.info,
                    color: AppTheme.primaryColor,
                    size: 48,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Priority Skills
            if (prioritySkills.isNotEmpty) ...[
              Text(
                'Priority Skills to Learn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Focus on these high-demand skills first',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prioritySkills.length,
                itemBuilder: (context, index) {
                  return _buildSkillItem(
                    skill: prioritySkills[index],
                    index: index + 1,
                    isPriority: true,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // All Missing Skills
            if (missingSkills.isNotEmpty) ...[
              Text(
                'All Missing Skills',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: missingSkills.length,
                itemBuilder: (context, index) {
                  return _buildSkillItem(
                    skill: missingSkills[index],
                    index: index + 1,
                    isPriority: false,
                  );
                },
              ),
              const SizedBox(height: 32),
            ],

            // Learning Path Button
            CustomButton(
              label: 'Create Learning Roadmap',
              onPressed: () {
                Helpers.showSuccessToast('Roadmap creation coming soon!');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillItem({
    required String skill,
    required int index,
    required bool isPriority,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPriority
            ? Colors.orange.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPriority
              ? Colors.orange.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPriority ? Colors.orange : Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                index.toString(),
                style: const TextStyle(
                  color: Colors.white,
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
                  skill,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (isPriority)
                  Text(
                    'High demand',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                  ),
              ],
            ),
          ),
          if (isPriority)
            const Icon(Icons.priority_high, color: Colors.orange, size: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _targetJobController.dispose();
    _skillsController.dispose();
    super.dispose();
  }
}
