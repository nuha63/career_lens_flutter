import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../models/user_preferences_model.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> with RouteAware {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  late TextEditingController _skillsController;
  late TextEditingController _categoriesController;
  final FocusNode _skillsFocusNode = FocusNode();
  final FocusNode _categoriesFocusNode = FocusNode();

  int _currentPage = 0;
  final int _totalPages = 4;

  int _dailyHours = 1;
  String _learningPace = 'medium';
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasLoaded = false;

  final List<String> _paceOptions = ['slow', 'medium', 'fast'];
  List<String> _targetSkills = [];
  List<String> _preferredCategories = [];

  @override
  void initState() {
    super.initState();
    _skillsController = TextEditingController();
    _categoriesController = TextEditingController();
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) {
      _loadPreferences();
    }
  }

  @override
  void dispose() {
    _skillsController.dispose();
    _categoriesController.dispose();
    _skillsFocusNode.dispose();
    _categoriesFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.keyUserId);

      if (userId == null || userId.isEmpty) {
        throw 'User not authenticated';
      }

      final cachedSkills = prefs.getStringList('pref_skills_$userId');
      final cachedCategories = prefs.getStringList('pref_categories_$userId');
      final cachedHours = prefs.getInt('pref_hours_$userId');
      final cachedPace = prefs.getString('pref_pace_$userId');

      if (cachedSkills != null || cachedCategories != null || cachedHours != null || cachedPace != null) {
        if (mounted) {
          setState(() {
            if (cachedSkills != null) _targetSkills = List<String>.from(cachedSkills);
            if (cachedCategories != null) _preferredCategories = List<String>.from(cachedCategories);
            if (cachedHours != null) _dailyHours = cachedHours;
            if (cachedPace != null) _learningPace = cachedPace;
          });
        }
      }

      final response = await _apiService.getUserPreferences(userId: userId);

      if (mounted) {
        setState(() {
          _targetSkills = List<String>.from(response['target_skills'] ?? []);
          _preferredCategories =
              List<String>.from(response['preferred_categories'] ?? []);
          _dailyHours = (response['daily_study_hours_goal'] as int?) ?? 1;
          _learningPace = (response['learning_pace'] as String?) ?? 'medium';
          _hasLoaded = true;
        });

        await prefs.setStringList('pref_skills_$userId', _targetSkills);
        await prefs.setStringList('pref_categories_$userId', _preferredCategories);
        await prefs.setInt('pref_hours_$userId', _dailyHours);
        await prefs.setString('pref_pace_$userId', _learningPace);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast('Failed to load preferences');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.keyUserId);

      if (userId == null || userId.isEmpty) {
        throw 'User not authenticated';
      }

      await _apiService.saveUserPreferences(
        userId: userId,
        targetSkills: _targetSkills,
        dailyStudyHoursGoal: _dailyHours,
        learningPace: _learningPace,
        preferredCategories: _preferredCategories,
      );

      final newPrefs = UserPreferences(
        userId: userId,
        targetSkills: _targetSkills,
        dailyStudyHoursGoal: _dailyHours,
        learningPace: _learningPace,
        preferredCategories: _preferredCategories,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final cache = AppCacheService();
      await cache.savePreferences(newPrefs);

      if (mounted) {
        Helpers.showSuccessToast('Preferences saved successfully! 🎯');
        Navigator.pop(context); // Exit wizard after saving
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast('Failed to save: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addSkill(String raw) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    if (_targetSkills.any((s) => s.toLowerCase() == skill.toLowerCase())) {
      _skillsController.clear();
      return;
    }
    setState(() {
      _targetSkills.add(skill);
      _skillsController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _targetSkills.remove(skill));
  }

  void _addCategory(String raw) {
    final category = raw.trim();
    if (category.isEmpty) return;
    if (_preferredCategories.any((c) => c.toLowerCase() == category.toLowerCase())) {
      _categoriesController.clear();
      return;
    }
    setState(() {
      _preferredCategories.add(category);
      _categoriesController.clear();
    });
  }

  void _removeCategory(String category) {
    setState(() => _preferredCategories.remove(category));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Learning Wizard', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Premium Progress Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of $_totalPages',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / _totalPages,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                            color: AppTheme.primaryColor,
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Disable swipe
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildSkillsPage(),
                      _buildCategoriesPage(),
                      _buildPacePage(),
                      _buildGoalPage(),
                    ],
                  ),
                ),
                
                // Bottom Navigation Bar
                _buildBottomNav(),
              ],
            ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Back', style: TextStyle(fontSize: 16)),
            )
          else
            const SizedBox.shrink(),
            
          if (_currentPage < _totalPages - 1)
            ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                elevation: 0,
              ),
              child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          else
            ElevatedButton(
              onPressed: _isSaving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save & Finish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _buildPageContainer({required String title, required String subtitle, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  // ── Step 1: Skills ────────────────────────────────────────────────────────

  Widget _buildSkillsPage() {
    return _buildPageContainer(
      title: 'Target Skills',
      subtitle: 'What skills are you aiming to master?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _skillsController,
            focusNode: _skillsFocusNode,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Add a skill',
              hintText: 'e.g., Flutter, Python, AWS',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
                onPressed: () => _addSkill(_skillsController.text),
              ),
            ),
            onSubmitted: _addSkill,
          ),
          const SizedBox(height: 16),
          if (_targetSkills.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No skills added yet. Type a skill and press + to add it.',
                      style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _targetSkills.map((skill) {
                return Chip(
                  label: Text(skill, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: AppTheme.primaryColor),
                  onDeleted: () => _removeSkill(skill),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Step 2: Categories ─────────────────────────────────────────────────────

  Widget _buildCategoriesPage() {
    return _buildPageContainer(
      title: 'Job Categories',
      subtitle: 'What industries or roles excite you?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _categoriesController,
            focusNode: _categoriesFocusNode,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Add a job category',
              hintText: 'e.g., Software Engineering, Data Science',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor, size: 28),
                onPressed: () => _addCategory(_categoriesController.text),
              ),
            ),
            onSubmitted: _addCategory,
          ),
          const SizedBox(height: 16),
          if (_preferredCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No categories added. Add some to get personalized job matches.',
                      style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _preferredCategories.map((category) {
                return Chip(
                  label: Text(category, style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: AppTheme.secondaryColor),
                  onDeleted: () => _removeCategory(category),
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                  side: BorderSide(color: AppTheme.secondaryColor.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Step 3: Pace ───────────────────────────────────────────────────────────

  Widget _buildPacePage() {
    return _buildPageContainer(
      title: 'Learning Pace',
      subtitle: 'How intense should your roadmap be?',
      child: Column(
        children: _paceOptions.map((pace) {
          final isSelected = pace == _learningPace;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () => setState(() => _learningPace = pace),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _paceLabel(pace),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _paceDescription(pace),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _paceLabel(String pace) {
    switch (pace) {
      case 'slow': return '🐢 Relaxed';
      case 'fast': return '🚀 Fast Track';
      default: return '⚡ Balanced';
    }
  }

  String _paceDescription(String pace) {
    switch (pace) {
      case 'slow': return 'Learn at a comfortable pace — great for beginners';
      case 'fast': return 'Intensive learning — maximize speed and growth';
      default: return 'Balanced approach for steady, consistent progress';
    }
  }

  // ── Step 4: Daily Goal ─────────────────────────────────────────────────────

  Widget _buildGoalPage() {
    return _buildPageContainer(
      title: 'Daily Goal',
      subtitle: 'How much time can you commit to learning each day?',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$_dailyHours Hour${_dailyHours > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daily Study Commitment',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: AppTheme.primaryColor.withOpacity(0.2),
                thumbColor: AppTheme.primaryColor,
                overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
              ),
              child: Slider(
                value: _dailyHours.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                onChanged: (value) => setState(() => _dailyHours = value.toInt()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('1 hr', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text('8 hrs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
