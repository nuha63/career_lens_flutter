import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/progress_model.dart';
import '../../models/user_preferences_model.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/custom_button.dart';

class ProgressTrackerScreen extends StatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  State<ProgressTrackerScreen> createState() => _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends State<ProgressTrackerScreen> {
  // ── Repository / Service instances ────────────────────────────────────────
  final ProgressRepository  _progressRepo = ProgressRepository();
  final AuthRepository      _authRepo     = AuthRepository();
  final AppCacheService     _cache        = AppCacheService();
  final ConnectivityService _conn         = ConnectivityService();

  // ── State ─────────────────────────────────────────────────────────────────
  ProgressModel?    _progressModel;
  UserPreferences?  _userPreferences;
  String?           _userId;
  bool              _isRefreshing = false;
  bool              _fromCache    = false;
  bool              _isOffline    = false;
  String?           _cacheAgeLabel;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD STRATEGY: stale-while-revalidate
  //   1. Show stale cached data immediately (no blank screen, no spinner)
  //   2. Fetch fresh from API in background
  //   3. Swap data when fresh arrives
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _bootstrap() async {
    // Step 0: resolve userId
    _userId = await _authRepo.getUserId();
    if (_userId == null || !mounted) return;

    // Step 1: instant cache read (stale allowed)
    await _loadFromCache();

    // Step 2: background API refresh
    await _refreshFromApi();
  }

  Future<void> _loadFromCache() async {
    if (_userId == null) return;

    // Progress (stale OK)
    final entry = await _cache.loadProgressWithMeta(_userId!);
    if (entry != null && mounted) {
      setState(() {
        _progressModel  = entry.data;
        _fromCache      = true;
        _cacheAgeLabel  = entry.ageLabel;
      });
    }

    // Preferences (stale OK)
    final pref = await _cache.loadPreferencesStale();
    if (pref != null && mounted) {
      setState(() => _userPreferences = pref);
    }
  }

  Future<void> _refreshFromApi() async {
    if (_userId == null || !mounted) return;

    _isOffline = !(await _conn.checkConnectivity());
    if (_isOffline) {
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      // Progress (API-first via repository)
      final fresh = await _progressRepo.getProgress(_userId!);
      if (mounted) {
        setState(() {
          _progressModel  = fresh;
          _fromCache      = false;
          _cacheAgeLabel  = 'just now';
        });
      }

      // Preferences (API-first via auth repository)
      final freshPref = await _authRepo.getPreferences(_userId!);
      if (mounted) setState(() => _userPreferences = freshPref);
    } catch (e) {
      debugPrint('⚠️ ProgressTracker: refresh failed – $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // Full manual refresh (pull-to-refresh or appbar button)
  Future<void> _fullRefresh() async {
    await _loadFromCache();
    await _refreshFromApi();
  }

  Future<void> _logHours(double hours) async {
    if (_userId == null || _progressModel == null) return;
    // Don't log if daily goal is already reached
    if (_progressModel!.studyHoursLogged >= _progressModel!.dailyStudyHoursGoal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily goal already achieved! Great job! 🎉')),
      );
      return;
    }
    setState(() => _isRefreshing = true);
    final fresh = await _progressRepo.logStudyHours(userId: _userId!, hours: hours);
    if (mounted) {
      setState(() {
        _progressModel = fresh;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _completeSkill(String skill) async {
    if (_userId == null) return;
    setState(() => _isRefreshing = true);
    final fresh = await _progressRepo.markSkillStatus(
      userId: _userId!,
      skillName: skill,
      isCompleted: true,
    );
    if (mounted) {
      setState(() {
        _progressModel = fresh;
        _isRefreshing = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.preferences),
          ),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fullRefresh,
            ),
        ],
      ),
      body: _progressModel == null && !_isRefreshing
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fullRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status banner ──────────────────────────────────────
                    _buildStatusBanner(),

                    // ── Personalized plan card ─────────────────────────────
                    if (_userPreferences != null) ...[
                      _buildPersonalizedInfoCard(),
                      const SizedBox(height: 24),
                    ],

                    // ── Daily Goal Tracker ─────────────────────────────────
                    if (_progressModel != null) ...[
                      _buildDailyGoalTrackerCard(),
                      const SizedBox(height: 24),
                    ],

                    // ── Overall progress ───────────────────────────────────
                    if (_progressModel != null) ...[
                      _buildOverallProgressCard(),
                      const SizedBox(height: 24),

                      // ── Job Readiness button ────────────────────────────
                      CustomButton(
                        label: 'View Job Readiness Score',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.jobReadiness),
                        icon: Icons.assessment,
                        backgroundColor: AppTheme.secondaryColor,
                      ),
                      const SizedBox(height: 32),

                      // ── Skills progress ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Skills Progress',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            '${_progressModel!.completedSkills}/'
                            '${_progressModel!.totalSkillsToLearn}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_progressModel!.skillProgress.isEmpty)
                        _buildNoSkillsYet()
                      else
                        ..._progressModel!.skillProgress.entries.map(
                          (e) => _buildSkillProgressCard(e.key, e.value),
                        ),
                      const SizedBox(height: 24),

                      // ── Footer ──────────────────────────────────────────
                      Center(
                        child: Text(
                          _fromCache
                              ? '💾 Cached · Last updated $_cacheAgeLabel'
                              : 'Last updated: ${Helpers.getTimeAgo(_progressModel!.lastUpdated)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    if (!_isOffline && !_fromCache) return const SizedBox.shrink();

    final isStale = _fromCache && !_isRefreshing;
    final color   = _isOffline ? AppTheme.errorColor : AppTheme.warningColor;
    final icon    = _isOffline ? Icons.wifi_off : Icons.cached;
    final text    = _isOffline
        ? '📶 Offline – showing cached data'
        : '💾 Showing cached data · refreshing…';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              ),
            ),
            if (isStale && !_isOffline)
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined, size: 80,
                color: AppTheme.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text('No Progress Data', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Start your learning journey to track your progress',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            if (_isRefreshing)
              const CircularProgressIndicator()
            else
              CustomButton(
                label: 'Get Started',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.skillRoadmap),
                icon: Icons.play_arrow,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalTrackerCard() {
    final logged = _progressModel!.studyHoursLogged;
    final goal = _progressModel!.dailyStudyHoursGoal;
    final progress = (logged / goal).clamp(0.0, 1.0);
    final bool achieved = progress >= 1.0;

    return Card(
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daily Study Goal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                Icon(achieved ? Icons.star : Icons.timer, 
                     color: achieved ? Colors.amber : AppTheme.primaryColor),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        color: achieved ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                      Center(
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: achieved ? AppTheme.successColor : AppTheme.primaryColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$logged / $goal hours',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achieved 
                          ? 'Goal achieved! You are on fire! 🔥' 
                          : 'Keep going! Log your study time.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: achieved ? null : () => _logHours(0.5),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log 30 min'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgressCard() {
    final progress = _progressModel!.overallProgress;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Progress',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).toInt()}% Complete',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value:           progress,
              minHeight:       12,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedInfoCard() {
    final pace      = _userPreferences!.learningPace;
    final hours     = _userPreferences!.dailyStudyHoursGoal;
    final paceColor = pace == 'fast' ? Colors.green
                    : pace == 'slow' ? Colors.orange
                    : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: paceColor, size: 20),
                const SizedBox(width: 12),
                Text('Your Learning Plan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Learning Pace',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:        paceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pace.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: paceColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Goal',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('$hours hours/day',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Target Skills to Learn',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_progressModel != null && _progressModel!.targetSkillsList.isNotEmpty)
              ..._progressModel!.targetSkillsList.map((skill) {
                final isLearned = _progressModel!.skillsLearnedList.contains(skill);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isLearned ? AppTheme.successColor.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLearned ? AppTheme.successColor.withOpacity(0.3) : Colors.grey.shade300,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      leading: Icon(
                        isLearned ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isLearned ? AppTheme.successColor : Colors.grey.shade400,
                      ),
                      title: Text(
                        skill,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: isLearned ? TextDecoration.lineThrough : null,
                          color: isLearned ? AppTheme.textSecondary : null,
                        ),
                      ),
                      trailing: isLearned
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: () => _completeSkill(skill),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              child: const Text('Mark Complete'),
                            ),
                    ),
                  ),
                );
              }).toList()
            else if (_progressModel != null && _progressModel!.targetSkillsList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('No target skills. Update your preferences.')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSkillsYet() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'No skills tracked yet.\nComplete a roadmap to see progress here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSkillProgressCard(String skillName, SkillProgress progress) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    skillName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (progress.isCompleted)
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:        AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                          const SizedBox(width: 4),
                          Text('Completed',
                              style: TextStyle(
                                fontSize: 11, color: AppTheme.successColor,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CustomProgressBar(
              progress:      progress.progressPercentage,
              showPercentage: true,
            ),
            if (progress.completedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Completed ${Helpers.getTimeAgo(progress.completedAt!)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.successColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}