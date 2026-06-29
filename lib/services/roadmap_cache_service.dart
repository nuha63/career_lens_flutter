import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/career_roadmap_model.dart';

/// Service to handle local caching and persistence of career roadmaps.
class RoadmapCacheService {
  static const String _keyRoadmapsList = 'cached_roadmaps_list';
  static const String _keyRoadmapPrefix = 'cached_roadmap_';
  static const String _keyProgressPrefix = 'cached_roadmap_progress_';

  /// Save the list of roadmaps to local cache
  Future<void> saveRoadmapsList(List<CareerRoadmap> roadmaps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(roadmaps.map((r) => r.toJson()).toList());
      await prefs.setString(_keyRoadmapsList, jsonStr);
      debugPrint('💾 Saved roadmaps list to cache (${roadmaps.length} items)');
    } catch (e) {
      debugPrint('❌ Error saving roadmaps list to cache: $e');
    }
  }

  /// Load the list of roadmaps from local cache
  Future<List<CareerRoadmap>?> loadRoadmapsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyRoadmapsList);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final list = decoded.map((j) => CareerRoadmap.fromJson(j as Map<String, dynamic>)).toList();
        debugPrint('💾 Loaded roadmaps list from cache (${list.length} items)');
        return list;
      }
    } catch (e) {
      debugPrint('❌ Error loading roadmaps list from cache: $e');
    }
    return null;
  }

  /// Save a single detailed roadmap to local cache
  Future<void> saveRoadmap(CareerRoadmap roadmap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(roadmap.toJson());
      await prefs.setString('$_keyRoadmapPrefix${roadmap.id}', jsonStr);
      debugPrint('💾 Saved detailed roadmap ${roadmap.id} to cache');
    } catch (e) {
      debugPrint('❌ Error saving roadmap to cache: $e');
    }
  }

  /// Load a single detailed roadmap from local cache
  Future<CareerRoadmap?> loadRoadmap(String roadmapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('$_keyRoadmapPrefix$roadmapId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        final roadmap = CareerRoadmap.fromJson(decoded as Map<String, dynamic>);
        debugPrint('💾 Loaded detailed roadmap $roadmapId from cache');
        return roadmap;
      }
    } catch (e) {
      debugPrint('❌ Error loading roadmap from cache: $e');
    }
    return null;
  }

  /// Save completed phase IDs locally
  Future<void> saveProgress(String userId, String roadmapId, List<String> completedPhaseIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_keyProgressPrefix${userId}_$roadmapId', completedPhaseIds);
      debugPrint('💾 Saved completed phase IDs for user $userId, roadmap $roadmapId to cache: $completedPhaseIds');
    } catch (e) {
      debugPrint('❌ Error saving progress to cache: $e');
    }
  }

  /// Load completed phase IDs from local cache
  Future<List<String>?> loadProgress(String userId, String roadmapId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? progress = prefs.getStringList('$_keyProgressPrefix${userId}_$roadmapId');
      if (progress != null) {
        debugPrint('💾 Loaded completed phase IDs from cache: $progress');
        return progress;
      }
    } catch (e) {
      debugPrint('❌ Error loading progress from cache: $e');
    }
    return null;
  }
}
