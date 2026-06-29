import 'package:flutter/foundation.dart';
import '../models/career_roadmap_model.dart';
import '../models/roadmap_template_engine.dart';
import '../services/api_service.dart';
import '../services/roadmap_cache_service.dart';

/// Repository that handles data orchestration for Career Roadmaps.
/// Orchestrates data from API -> SharedPreferences Cache -> Fallback Templates.
class RoadmapRepository {
  final ApiService _apiService = ApiService();
  final RoadmapCacheService _cacheService = RoadmapCacheService();

  /// Returns true when [roadmapId] is a local fallback template (non-numeric).
  /// Template roadmaps only exist in-app — no backend record exists for them.
  bool _isTemplateId(String roadmapId) =>
      int.tryParse(roadmapId) == null;

  /// Retrieve the list of all roadmaps.
  Future<List<CareerRoadmap>> getRoadmaps() async {
    try {
      debugPrint('💼 RoadmapRepository: Retrieving roadmaps list...');
      // 1. Try API first
      final roadmaps = await _apiService.getAllRoadmaps();
      if (roadmaps.isNotEmpty) {
        await _cacheService.saveRoadmapsList(roadmaps);
        return roadmaps;
      }
    } catch (e) {
      debugPrint('⚠️ RoadmapRepository: API failed, trying cache. Error: $e');
    }

    // 2. Try Cache next
    final cached = await _cacheService.loadRoadmapsList();
    if (cached != null && cached.isNotEmpty) {
      debugPrint('💼 RoadmapRepository: Serving roadmaps list from cache');
      return cached;
    }

    // 3. Fallback to Templates list
    debugPrint('💼 RoadmapRepository: Serving roadmaps list from fallback templates');
    return RoadmapTemplateEngine.allTemplates;
  }

  /// Retrieve a single detailed roadmap with phases.
  Future<CareerRoadmap> getRoadmapById(String roadmapId) async {
    try {
      debugPrint('💼 RoadmapRepository: Retrieving roadmap details for $roadmapId...');
      // 1. Try API first
      final roadmap = await _apiService.getRoadmapById(roadmapId);
      if (roadmap.phases.isNotEmpty) {
        await _cacheService.saveRoadmap(roadmap);
        return roadmap;
      }
    } catch (e) {
      debugPrint('⚠️ RoadmapRepository: Details API failed, trying cache. Error: $e');
    }

    // 2. Try Cache next
    final cached = await _cacheService.loadRoadmap(roadmapId);
    if (cached != null && cached.phases.isNotEmpty) {
      debugPrint('💼 RoadmapRepository: Serving roadmap $roadmapId details from cache');
      return cached;
    }

    // 3. Fallback to Template Engine
    debugPrint('💼 RoadmapRepository: Serving roadmap $roadmapId details from fallback templates');
    return RoadmapTemplateEngine.getTemplate(roadmapId);
  }

  /// Mark or unmark a skill as completed.
  Future<bool> markSkillComplete({
    required String userId,
    required String roadmapId,
    required String phaseId,
    required String skillId,
    required bool isCompleted,
  }) async {
    bool success = false;
    
    // For non-template roadmaps, call the backend API first
    if (!_isTemplateId(roadmapId)) {
      try {
        debugPrint('💼 RoadmapRepository: Marking skill $skillId complete for user $userId via API...');
        success = await _apiService.markSkillComplete(
          userId: userId,
          roadmapId: roadmapId,
          phaseId: phaseId,
          skillId: skillId,
          isCompleted: isCompleted,
        );
      } catch (e) {
        debugPrint('⚠️ RoadmapRepository: markSkillComplete API failed. Fallback to cache ONLY. Error: $e');
        success = true; // Assume true if we're working offline
      }
    } else {
      success = true; // Template phase progress is always "successful" since it's local
    }

    if (success) {
      // Manage local cache state
      final currentProgress = await _cacheService.loadProgress(userId, roadmapId) ?? [];
      
      if (isCompleted && !currentProgress.contains(skillId)) {
        currentProgress.add(skillId);
      } else if (!isCompleted) {
        currentProgress.remove(skillId);
      }

      await _cacheService.saveProgress(userId, roadmapId, currentProgress);
      debugPrint('💼 RoadmapRepository: Updated cache for roadmap $roadmapId progress: $currentProgress');
    }

    return success;
  }

  /// Retrieve progress (completed skill IDs) for user + roadmap.
  Future<List<String>> getRoadmapProgress(String userId, String roadmapId) async {
    // Template roadmaps are local-only — skip the API call to avoid a 400.
    if (!_isTemplateId(roadmapId)) {
      try {
        debugPrint('💼 RoadmapRepository: Retrieving user progress for user $userId, roadmap $roadmapId...');
        final progress = await _apiService.getRoadmapProgress(userId, roadmapId);
        await _cacheService.saveProgress(userId, roadmapId, progress);
        return progress;
      } catch (e) {
        debugPrint('⚠️ RoadmapRepository: Progress API failed, trying cache. Error: $e');
      }
    } else {
      debugPrint('💼 RoadmapRepository: Skipping API for template roadmap $roadmapId');
    }

    // Try cache
    final cachedProgress = await _cacheService.loadProgress(userId, roadmapId);
    if (cachedProgress != null) {
      debugPrint('💼 RoadmapRepository: Serving progress from cache');
      return cachedProgress;
    }

    // Fallback to empty list
    debugPrint('💼 RoadmapRepository: Falling back to empty progress list');
    return [];
  }

}
