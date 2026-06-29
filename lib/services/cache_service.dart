import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_preferences_model.dart';
import '../models/resume_model.dart';
import '../models/job_role_model.dart';
import '../models/progress_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TTL constants (how long each domain's data is considered fresh)
// ─────────────────────────────────────────────────────────────────────────────
class CacheTTL {
  static const Duration user      = Duration(hours: 24);
  static const Duration prefs     = Duration(days: 7);
  static const Duration resume    = Duration(days: 30);
  static const Duration skillGap  = Duration(days: 7);
  static const Duration jobMatch  = Duration(days: 30);
  static const Duration salary    = Duration(days: 1);
  static const Duration progress  = Duration(hours: 2);
}

// ─────────────────────────────────────────────────────────────────────────────
// CacheEntry<T>  – carries data + metadata returned by *WithMeta() methods
// ─────────────────────────────────────────────────────────────────────────────
class CacheEntry<T> {
  final T        data;
  final DateTime cachedAt;
  final Duration ttl;
  final bool     isExpired;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
    required this.isExpired,
  });

  /// How old the entry is.
  Duration get age => DateTime.now().difference(cachedAt);

  /// Human-readable "X ago" label for display in the UI.
  String get ageLabel {
    final m = age.inMinutes;
    if (m < 1)  return 'just now';
    if (m < 60) return '$m min ago';
    final h = age.inHours;
    if (h < 24) return '${h}h ago';
    return '${age.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppCacheService
// ─────────────────────────────────────────────────────────────────────────────
/// Centralized SharedPreferences cache with TTL-envelope storage.
///
/// Every value is stored as:
///   { "_v": 1, "_t": <ms-epoch>, "_x": <ttl-ms>, "_d": <data> }
///
/// Legacy entries written by the previous implementation (no "_v" key) are
/// treated as invalid on the first read and silently evicted.
class AppCacheService {
  // Schema version – bump when the envelope structure changes.
  static const int _schemaVersion = 1;

  // ── Shared-preference keys ────────────────────────────────────────────────
  static const String _kUser            = 'cache_user';
  static const String _kPrefs           = 'cache_user_prefs';
  static const String _kLastResume      = 'cache_last_resume';
  static const String _kLastSkillGap    = 'cache_last_skill_gap';
  static const String _kLastJobMatch    = 'cache_last_job_match';
  static const String _kLastSalary      = 'cache_last_salary';
  static const String _kProgress        = 'cache_progress_';
  static const String _kSkillGapHistory = 'cache_skill_gap_history';
  static const String _kJobMatchHistory = 'cache_job_match_history';

  // ═══════════════════════════════════════════════════════════════════════════
  // LOW-LEVEL TTL HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String _wrapJson(dynamic data, Duration ttl) => jsonEncode({
    '_v': _schemaVersion,
    '_t': DateTime.now().millisecondsSinceEpoch,
    '_x': ttl.inMilliseconds,
    '_d': data,
  });

  /// Returns the `_d` field or null when:
  ///   • raw is null/empty
  ///   • JSON parsing fails
  ///   • schema version mismatch
  ///   • entry is expired (unless [allowStale] is true)
  static dynamic _unwrap(String? raw, {bool allowStale = false}) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final e = jsonDecode(raw) as Map<String, dynamic>;
      if ((e['_v'] as int?) != _schemaVersion) return null;
      if (!allowStale) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - (e['_t'] as int);
        if (ageMs > (e['_x'] as int)) return null; // expired
      }
      return e['_d'];
    } catch (_) {
      return null;
    }
  }

  /// Parses the envelope but returns null only when the JSON is bad.
  /// Always returns data (even if expired) — use [CacheEntry.isExpired] at
  /// call-site to decide whether to show a "stale" indicator.
  static CacheEntry<dynamic>? _buildEntry(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final e        = jsonDecode(raw) as Map<String, dynamic>;
      if ((e['_v'] as int?) != _schemaVersion) return null;
      final cachedMs = (e['_t'] as int?) ?? 0;
      final ttlMs    = (e['_x'] as int?) ?? 0;
      final ageMs    = DateTime.now().millisecondsSinceEpoch - cachedMs;
      return CacheEntry(
        data:      e['_d'],
        cachedAt:  DateTime.fromMillisecondsSinceEpoch(cachedMs),
        ttl:       Duration(milliseconds: ttlMs),
        isExpired: ageMs > ttlMs,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH / USER
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveUser(UserModel user) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kUser, _wrapJson(user.toJson(), CacheTTL.user));
      debugPrint('💾 Cache[user] saved – TTL ${CacheTTL.user.inHours}h');
    } catch (e) { debugPrint('❌ Cache.saveUser: $e'); }
  }

  /// Returns null when missing or TTL exceeded (fresh-only read).
  Future<UserModel?> loadUser() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kUser));
      if (data is Map<String, dynamic>) return UserModel.fromJson(data);
    } catch (e) { debugPrint('❌ Cache.loadUser: $e'); }
    return null;
  }

  /// Returns stale data (ignores TTL) — for immediate startup display.
  Future<UserModel?> loadUserStale() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kUser), allowStale: true);
      if (data is Map<String, dynamic>) return UserModel.fromJson(data);
    } catch (e) { debugPrint('❌ Cache.loadUserStale: $e'); }
    return null;
  }

  Future<void> savePreferences(UserPreferences pref) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPrefs, _wrapJson(pref.toJson(), CacheTTL.prefs));
      debugPrint('💾 Cache[prefs] saved');
    } catch (e) { debugPrint('❌ Cache.savePreferences: $e'); }
  }

  Future<UserPreferences?> loadPreferences() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kPrefs));
      if (data is Map<String, dynamic>) return UserPreferences.fromJson(data);
    } catch (e) { debugPrint('❌ Cache.loadPreferences: $e'); }
    return null;
  }

  Future<UserPreferences?> loadPreferencesStale() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kPrefs), allowStale: true);
      if (data is Map<String, dynamic>) return UserPreferences.fromJson(data);
    } catch (_) {}
    return null;
  }

  Future<void> clearUser() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kUser);
      await p.remove(_kPrefs);
      debugPrint('🗑️ Cache[user+prefs] cleared');
    } catch (e) { debugPrint('❌ Cache.clearUser: $e'); }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESUME
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveLastResumeResult(ResumeAnalysisResult result) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLastResume, _wrapJson(result.toJson(), CacheTTL.resume));
      debugPrint('💾 Cache[resume] saved – ATS ${result.atsScore}');
    } catch (e) { debugPrint('❌ Cache.saveLastResumeResult: $e'); }
  }

  Future<ResumeAnalysisResult?> loadLastResumeResult({bool allowStale = false}) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kLastResume), allowStale: allowStale);
      if (data is Map<String, dynamic>) return ResumeAnalysisResult.fromApiResponse(data);
    } catch (e) { debugPrint('❌ Cache.loadLastResumeResult: $e'); }
    return null;
  }

  Future<CacheEntry<ResumeAnalysisResult>?> loadLastResumeWithMeta() async {
    try {
      final p     = await SharedPreferences.getInstance();
      final entry = _buildEntry(p.getString(_kLastResume));
      if (entry?.data is Map<String, dynamic>) {
        return CacheEntry(
          data:      ResumeAnalysisResult.fromApiResponse(entry!.data as Map<String, dynamic>),
          cachedAt:  entry.cachedAt,
          ttl:       entry.ttl,
          isExpired: entry.isExpired,
        );
      }
    } catch (e) { debugPrint('❌ Cache.loadLastResumeWithMeta: $e'); }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SKILL GAP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveLastSkillGap(Map<String, dynamic> data) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLastSkillGap, _wrapJson(data, CacheTTL.skillGap));
      debugPrint('💾 Cache[skill_gap] saved');
    } catch (e) { debugPrint('❌ Cache.saveLastSkillGap: $e'); }
  }

  Future<Map<String, dynamic>?> loadLastSkillGap({bool allowStale = false}) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kLastSkillGap), allowStale: allowStale);
      if (data is Map<String, dynamic>) return data;
    } catch (e) { debugPrint('❌ Cache.loadLastSkillGap: $e'); }
    return null;
  }

  /// Append a new skill-gap snapshot to the timestamped history (≤ 20 entries).
  Future<void> appendSkillGapHistory(Map<String, dynamic> data) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final raw  = p.getString(_kSkillGapHistory);
      final list = raw != null ? (jsonDecode(raw) as List<dynamic>) : <dynamic>[];
      list.insert(0, {'data': data, 'saved_at': DateTime.now().toIso8601String()});
      if (list.length > 20) list.removeLast();
      await p.setString(_kSkillGapHistory, jsonEncode(list));
    } catch (e) { debugPrint('❌ Cache.appendSkillGapHistory: $e'); }
  }

  Future<List<Map<String, dynamic>>> loadSkillGapHistory() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kSkillGapHistory);
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) { debugPrint('❌ Cache.loadSkillGapHistory: $e'); }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB MATCH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveLastJobMatch(JobMatchResult result) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLastJobMatch, _wrapJson(result.toJson(), CacheTTL.jobMatch));
      debugPrint('💾 Cache[job_match] saved – ${result.matchScore}%');
    } catch (e) { debugPrint('❌ Cache.saveLastJobMatch: $e'); }
  }

  Future<JobMatchResult?> loadLastJobMatch({bool allowStale = false}) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kLastJobMatch), allowStale: allowStale);
      if (data is Map<String, dynamic>) return JobMatchResult.fromApiResponse(data);
    } catch (e) { debugPrint('❌ Cache.loadLastJobMatch: $e'); }
    return null;
  }

  Future<CacheEntry<JobMatchResult>?> loadLastJobMatchWithMeta() async {
    try {
      final p     = await SharedPreferences.getInstance();
      final entry = _buildEntry(p.getString(_kLastJobMatch));
      if (entry?.data is Map<String, dynamic>) {
        return CacheEntry(
          data:      JobMatchResult.fromApiResponse(entry!.data as Map<String, dynamic>),
          cachedAt:  entry.cachedAt,
          ttl:       entry.ttl,
          isExpired: entry.isExpired,
        );
      }
    } catch (e) { debugPrint('❌ Cache.loadLastJobMatchWithMeta: $e'); }
    return null;
  }

  /// Append to history list (≤ 20 entries, newest-first).
  Future<void> appendJobMatchHistory(JobMatchResult result) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final raw  = p.getString(_kJobMatchHistory);
      final list = raw != null ? (jsonDecode(raw) as List<dynamic>) : <dynamic>[];
      list.insert(0, {'data': result.toJson(), 'saved_at': DateTime.now().toIso8601String()});
      if (list.length > 20) list.removeLast();
      await p.setString(_kJobMatchHistory, jsonEncode(list));
    } catch (e) { debugPrint('❌ Cache.appendJobMatchHistory: $e'); }
  }

  Future<List<JobMatchResult>> loadJobMatchHistory() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kJobMatchHistory);
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) {
              final d = e['data'];
              return d is Map<String, dynamic> ? JobMatchResult.fromApiResponse(d) : null;
            })
            .whereType<JobMatchResult>()
            .toList();
      }
    } catch (e) { debugPrint('❌ Cache.loadJobMatchHistory: $e'); }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SALARY PREDICTION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveLastSalaryPrediction(Map<String, dynamic> data) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kLastSalary, _wrapJson(data, CacheTTL.salary));
      debugPrint('💾 Cache[salary] saved');
    } catch (e) { debugPrint('❌ Cache.saveLastSalaryPrediction: $e'); }
  }

  Future<Map<String, dynamic>?> loadLastSalaryPrediction({bool allowStale = false}) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(p.getString(_kLastSalary), allowStale: allowStale);
      if (data is Map<String, dynamic>) return data;
    } catch (e) { debugPrint('❌ Cache.loadLastSalaryPrediction: $e'); }
    return null;
  }

  Future<CacheEntry<Map<String, dynamic>>?> loadLastSalaryWithMeta() async {
    try {
      final p     = await SharedPreferences.getInstance();
      final entry = _buildEntry(p.getString(_kLastSalary));
      if (entry?.data is Map<String, dynamic>) {
        return CacheEntry(
          data:      entry!.data as Map<String, dynamic>,
          cachedAt:  entry.cachedAt,
          ttl:       entry.ttl,
          isExpired: entry.isExpired,
        );
      }
    } catch (e) { debugPrint('❌ Cache.loadLastSalaryWithMeta: $e'); }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRESS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> saveProgress(String userId, ProgressModel progress) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        '$_kProgress$userId',
        _wrapJson(progress.toJson(), CacheTTL.progress),
      );
      debugPrint('💾 Cache[progress:$userId] saved – score ${progress.jobReadinessScore}');
    } catch (e) { debugPrint('❌ Cache.saveProgress: $e'); }
  }

  Future<ProgressModel?> loadProgress(String userId, {bool allowStale = false}) async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = _unwrap(
        p.getString('$_kProgress$userId'),
        allowStale: allowStale,
      );
      if (data is Map<String, dynamic>) return ProgressModel.fromJson(data);
    } catch (e) { debugPrint('❌ Cache.loadProgress: $e'); }
    return null;
  }

  Future<CacheEntry<ProgressModel>?> loadProgressWithMeta(String userId) async {
    try {
      final p     = await SharedPreferences.getInstance();
      final entry = _buildEntry(p.getString('$_kProgress$userId'));
      if (entry?.data is Map<String, dynamic>) {
        return CacheEntry(
          data:      ProgressModel.fromJson(entry!.data as Map<String, dynamic>),
          cachedAt:  entry.cachedAt,
          ttl:       entry.ttl,
          isExpired: entry.isExpired,
        );
      }
    } catch (e) { debugPrint('❌ Cache.loadProgressWithMeta: $e'); }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOBAL UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Remove all keys with the 'cache_' prefix.
  /// Call on logout or version mismatch.
  Future<void> clearAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getKeys().where((k) => k.startsWith('cache_')).toList();
      for (final k in keys) { await p.remove(k); }
      debugPrint('🗑️ Cache: all ${keys.length} entries cleared');
    } catch (e) { debugPrint('❌ Cache.clearAll: $e'); }
  }

  /// Returns cache freshness metadata for a given key (for debug/UI display).
  Future<CacheEntry<dynamic>?> inspectKey(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      return _buildEntry(p.getString(key));
    } catch (_) {}
    return null;
  }
}
