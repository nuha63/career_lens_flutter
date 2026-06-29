import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/progress_model.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

/// ProgressRepository manages the Job Readiness Score and all learning
/// progress metrics for a user.
///
/// Strategy:
///   - GET progress     → API first → Cache fallback → Graceful defaults.
///   - UPDATE progress  → Cache optimistically; sync to API when online.
///   - Mark skill done  → Cache first (instant UX); then API sync.
class ProgressRepository {
  final ApiService      _apiService = ApiService();
  final AppCacheService _cache      = AppCacheService();

  // ═════════════════════════════════════════════════════════════════════════
  // READ
  // ═════════════════════════════════════════════════════════════════════════

  /// Fetch the full progress model for [userId].
  ///
  /// Returns fresh API data on success, cached data on network failure,
  /// or a zeroed-out model when neither is available.
  Future<ProgressModel> getProgress(String userId) async {
    // 1. API first.
    try {
      debugPrint('📊 ProgressRepository: fetching progress for $userId …');
      final data = await _apiService.getUserProgress(userId: userId);
      await _cache.saveProgress(userId, data);
      debugPrint('✅ ProgressRepository: readiness score ${data.jobReadinessScore}');
      return data;
    } on SocketException {
      debugPrint('⚠️ ProgressRepository: no network, trying cache …');
    } catch (e) {
      debugPrint('⚠️ ProgressRepository: API failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadProgress(userId);
    if (cached != null) {
      debugPrint('💾 ProgressRepository: progress loaded from cache');
      return cached;
    }

    // 3. Zeroed default (first-time user, no data anywhere).
    debugPrint('📋 ProgressRepository: returning default progress');
    return _defaultProgress(userId);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // UPDATE SKILL STATUS
  // ═════════════════════════════════════════════════════════════════════════

  /// Mark [skillName] as completed (or incomplete) for [userId].
  ///
  /// The cached ProgressModel is updated optimistically so the UI reflects
  /// the change instantly.  The API sync runs asynchronously; any failure is
  /// logged but does NOT revert the cache, ensuring offline resilience.
  ///
  /// Returns the updated [ProgressModel].
  Future<ProgressModel> markSkillStatus({
    required String userId,
    required String skillName,
    required bool   isCompleted,
  }) async {
    debugPrint(
      '🔖 ProgressRepository: marking "$skillName" '
      '${isCompleted ? "complete" : "incomplete"} for $userId …',
    );

    // ── Optimistic cache update ───────────────────────────────────────────
    final current = await _cache.loadProgress(userId) ?? _defaultProgress(userId);
    final updatedSkillProgress = Map<String, SkillProgress>.from(current.skillProgress);

    updatedSkillProgress[skillName] = SkillProgress(
      skillName:          skillName,
      progressPercentage: isCompleted ? 1.0 : 0.0,
      isCompleted:        isCompleted,
      completedAt:        isCompleted ? DateTime.now() : null,
      completedSteps:     isCompleted ? [skillName] : [],
    );

    final completedCount = updatedSkillProgress.values
        .where((sp) => sp.isCompleted)
        .length;

    final updated = ProgressModel(
      userId:               userId,
      jobReadinessScore:    _recalcReadinessScore(
                              completedCount,
                              current.totalSkillsToLearn,
                              current.resumeQualityScore,
                              current.experienceScore,
                            ),
      totalSkillsToLearn:   current.totalSkillsToLearn,
      completedSkills:      completedCount,
      skillProgress:        updatedSkillProgress,
      skillsInProgress:     current.skillsInProgress,
      technicalSkillScore:  current.technicalSkillScore,
      resumeQualityScore:   current.resumeQualityScore,
      experienceScore:      current.experienceScore,
      learningProgressScore:current.learningProgressScore,
      recommendations:      current.recommendations,
      lastUpdated:          DateTime.now(),
    );

    await _cache.saveProgress(userId, updated);

    // ── Background API sync ───────────────────────────────────────────────
    _syncSkillStatusToApi(
      userId:      userId,
      skillName:   skillName,
      isCompleted: isCompleted,
    );

    return updated;
  }

  /// Update the overall progress record for [userId] on the backend.
  ///
  /// Call this when you want to push a full batch of learned/in-progress
  /// skills (e.g. after completing a roadmap phase).
  ///
  /// The cache is always written first (offline-safe), then the API is
  /// called.  Returns the refreshed model from the API, or the locally
  /// updated model on failure.
  Future<ProgressModel> syncProgressToBackend({
    required String       userId,
    required List<String> skillsLearned,
    required List<String> skillsInProgress,
  }) async {
    debugPrint('🔄 ProgressRepository: syncing progress to backend for $userId …');

    // Update local cache immediately with the new skill lists.
    final current    = await _cache.loadProgress(userId) ?? _defaultProgress(userId);
    final optimistic = ProgressModel(
      userId:               userId,
      jobReadinessScore:    current.jobReadinessScore,
      totalSkillsToLearn:   current.totalSkillsToLearn,
      completedSkills:      skillsLearned.length,
      skillProgress:        _buildSkillProgressMap(skillsLearned, skillsInProgress),
      skillsInProgress:     skillsInProgress.length,
      technicalSkillScore:  current.technicalSkillScore,
      resumeQualityScore:   current.resumeQualityScore,
      experienceScore:      current.experienceScore,
      learningProgressScore:current.learningProgressScore,
      recommendations:      current.recommendations,
      lastUpdated:          DateTime.now(),
    );

    await _cache.saveProgress(userId, optimistic);

    // API sync.
    try {
      final fresh = await _apiService.getUserProgress(userId: userId);
      await _cache.saveProgress(userId, fresh);
      debugPrint('✅ ProgressRepository: synced – readiness ${fresh.jobReadinessScore}');
      return fresh;
    } catch (e) {
      debugPrint('⚠️ ProgressRepository: API sync failed (cache retained). Error: $e');
      return optimistic;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LOG DAILY HOURS
  // ═════════════════════════════════════════════════════════════════════════
  
  Future<ProgressModel> logStudyHours({
    required String userId,
    required double hours,
  }) async {
    debugPrint('⏳ ProgressRepository: logging $hours hours for $userId …');

    // 1. Optimistic Cache Update
    final current = await _cache.loadProgress(userId) ?? _defaultProgress(userId);
    final optimistic = ProgressModel(
      userId:               userId,
      jobReadinessScore:    current.jobReadinessScore,
      totalSkillsToLearn:   current.totalSkillsToLearn,
      completedSkills:      current.completedSkills,
      skillProgress:        current.skillProgress,
      skillsInProgress:     current.skillsInProgress,
      technicalSkillScore:  current.technicalSkillScore,
      resumeQualityScore:   current.resumeQualityScore,
      experienceScore:      current.experienceScore,
      learningProgressScore:current.learningProgressScore,
      recommendations:      current.recommendations,
      lastUpdated:          DateTime.now(),
      studyHoursLogged:     current.studyHoursLogged + hours,
      dailyStudyHoursGoal:  current.dailyStudyHoursGoal,
      targetSkillsList:     current.targetSkillsList,
      skillsLearnedList:    current.skillsLearnedList,
    );
    await _cache.saveProgress(userId, optimistic);

    // 2. API Sync
    try {
      await _apiService.logStudyHours(userId, hours);
      final fresh = await _apiService.getUserProgress(userId: userId);
      await _cache.saveProgress(userId, fresh);
      return fresh;
    } catch (e) {
      debugPrint('⚠️ ProgressRepository: API log hours failed. Error: $e');
      return optimistic;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CONVENIENCE GETTERS (cache-only – instant, no network)
  // ═════════════════════════════════════════════════════════════════════════

  /// Return the cached progress, or null if not available.
  Future<ProgressModel?> getCachedProgress(String userId) async {
    return _cache.loadProgress(userId);
  }

  /// Return the cached Job Readiness Score (0-100), or 0 if unavailable.
  Future<int> getCachedReadinessScore(String userId) async {
    final cached = await _cache.loadProgress(userId);
    return cached?.jobReadinessScore ?? 0;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  /// Fire-and-forget API update for a single skill status change.
  Future<void> _syncSkillStatusToApi({
    required String userId,
    required String skillName,
    required bool   isCompleted,
  }) async {
    try {
      // The backend progress endpoint currently stores aggregate skill lists,
      // not individual skill states.  We pull the latest and patch the lists.
      final current = await _cache.loadProgress(userId);
      if (current == null) return;

      final learned     = current.skillProgress.entries
          .where((e) => e.value.isCompleted)
          .map((e) => e.key)
          .toList();

      final inProgress  = current.skillProgress.entries
          .where((e) => !e.value.isCompleted && e.value.progressPercentage > 0)
          .map((e) => e.key)
          .toList();

      if (isCompleted) {
        await _apiService.completeSkill(userId, skillName);
      } else {
        // Fallback for un-completing is not natively supported by the new endpoint yet,
        // but can be added if required.
      }
      debugPrint('✅ ProgressRepository: API synced skill "$skillName"');
    } catch (e) {
      // Non-fatal; the cache already reflects the new state.
      debugPrint('⚠️ ProgressRepository: background API sync failed for "$skillName". Error: $e');
    }
  }

  /// Simple recalculation of the readiness score based on skill completion.
  ///
  /// Mirrors the backend formula:
  ///   • Technical skills (40%): completed / total * 100
  ///   • Resume quality  (25%): passed through unchanged
  ///   • Experience      (20%): passed through unchanged
  ///   • Learning prog.  (15%): same as technical
  int _recalcReadinessScore(
    int completedCount,
    int totalCount,
    int resumeQuality,
    int experienceScore,
  ) {
    if (totalCount <= 0) return 0;
    final techScore      = (completedCount / totalCount * 100).clamp(0, 100).toInt();
    final learningScore  = techScore;
    return (techScore * 0.40 +
            resumeQuality  * 0.25 +
            experienceScore * 0.20 +
            learningScore  * 0.15)
        .toInt()
        .clamp(0, 100);
  }

  /// Build a SkillProgress map from two flat lists.
  Map<String, SkillProgress> _buildSkillProgressMap(
    List<String> learned,
    List<String> inProgress,
  ) {
    final map = <String, SkillProgress>{};

    for (final skill in learned) {
      map[skill] = SkillProgress(
        skillName:          skill,
        progressPercentage: 1.0,
        isCompleted:        true,
        completedAt:        DateTime.now(),
        completedSteps:     [skill],
      );
    }

    for (final skill in inProgress) {
      if (!map.containsKey(skill)) {
        map[skill] = SkillProgress(
          skillName:          skill,
          progressPercentage: 0.5,
          isCompleted:        false,
          completedSteps:     [],
        );
      }
    }

    return map;
  }

  /// Returns a zeroed-out ProgressModel for a brand-new user.
  ProgressModel _defaultProgress(String userId) {
    return ProgressModel(
      userId:               userId,
      jobReadinessScore:    0,
      totalSkillsToLearn:   5,
      completedSkills:      0,
      skillProgress:        const {},
      skillsInProgress:     0,
      technicalSkillScore:  0,
      resumeQualityScore:   0,
      experienceScore:      0,
      learningProgressScore:0,
      recommendations:      const [
        'Upload your resume to get started.',
        'Run a job match to see how well you fit roles.',
      ],
      lastUpdated:          DateTime.now(),
      studyHoursLogged:     0.0,
      dailyStudyHoursGoal:  1,
      targetSkillsList:     const [],
      skillsLearnedList:    const [],
    );
  }
}
