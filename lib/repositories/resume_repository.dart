import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/resume_model.dart';
import '../services/api_service.dart';
import '../services/ml_api_service.dart';
import '../services/cache_service.dart';

/// Result object returned by ResumeRepository.analyzeResume().
class ResumeAnalysisBundle {
  /// The structured result parsed from the upload/mock response.
  final ResumeAnalysisResult uploadResult;

  /// The ML-enhanced analysis score (0-100), or null when offline.
  final int? mlMatchPercentage;

  /// Strengths identified by the ML model.
  final List<String> strengths;

  /// Weaknesses / areas to improve identified by the ML model.
  final List<String> weaknesses;

  /// Actionable suggestions from the ML model.
  final List<String> mlSuggestions;

  /// True when the data was served from local cache (no network used).
  final bool fromCache;

  const ResumeAnalysisBundle({
    required this.uploadResult,
    this.mlMatchPercentage,
    this.strengths      = const [],
    this.weaknesses     = const [],
    this.mlSuggestions  = const [],
    this.fromCache      = false,
  });
}

/// ResumeRepository orchestrates resume upload, extraction, and ML analysis.
///
/// Strategy:
///   - Upload + parse   → API only (file must be sent to server).
///   - ML analysis      → ML API; result cached locally.
///   - Last result GET  → API first → Cache fallback → null.
class ResumeRepository {
  final ApiService      _apiService  = ApiService();
  final MLApiService    _mlService   = getMLApiService();
  final AppCacheService _cache       = AppCacheService();

  // ═════════════════════════════════════════════════════════════════════════
  // UPLOAD + ANALYZE
  // ═════════════════════════════════════════════════════════════════════════

  /// Upload [file] to the backend, then run the ML analysis pipeline.
  ///
  /// Returns a [ResumeAnalysisBundle] combining the parse result and the
  /// ML-enriched scores.  The bundle is cached locally for offline use.
  ///
  /// Throws a human-readable [String] on unrecoverable failure.
  Future<ResumeAnalysisBundle> uploadAndAnalyze({
    required Uint8List fileBytes,
    required String    fileName,
    required String    market,
    String? userId,
    int    experienceYears    = 2,
    String educationLevel     = 'Bachelor',
    double skillsMatchScore   = 70.0,
    String locationType       = 'Remote',
    String industry           = 'IT',
    String jobMarketDemand    = 'High',
  }) async {
    debugPrint('📤 ResumeRepository: uploading $fileName …');

    // ── Step 1: Upload the file to backend ─────────────────────────────────
    late ResumeAnalysisResult uploadResult;
    try {
      final uploadResponse = await _apiService.uploadResume(
        fileBytes: fileBytes,
        fileName:  fileName,
      );
      uploadResult = ResumeAnalysisResult.fromApiResponse(
        uploadResponse,
        market: market,
      );
      debugPrint('✅ ResumeRepository: file uploaded – ATS \${uploadResult.atsScore}');
    } catch (e) {
      debugPrint('❌ ResumeRepository: upload failed – $e');
      throw _friendlyError(e);
    }

    // ── Step 2: Run ML analysis (non-fatal; we keep upload result on error) ─
    int?         mlMatchPercentage;
    List<String> strengths     = [];
    List<String> weaknesses    = [];
    List<String> mlSuggestions = [];

    try {
      final mlResponse = await _mlService.analyzeResume(
        experienceYears:  experienceYears,
        educationLevel:   educationLevel,
        skillsMatchScore: skillsMatchScore,
        locationTime:     locationType,
        industry:         industry,
        jobMarketDemand:  jobMarketDemand,
        userId:           userId,
      );

      final data = mlResponse['data'] as Map<String, dynamic>?;
      if (data != null) {
        mlMatchPercentage = (data['match_percentage'] as num?)?.toInt();
        strengths     = _stringList(data['strengths']);
        weaknesses    = _stringList(data['weaknesses']);
        mlSuggestions = _stringList(data['suggestions']);
      }
      debugPrint('✅ ResumeRepository: ML analysis – $mlMatchPercentage%');
    } catch (e) {
      debugPrint('⚠️ ResumeRepository: ML analysis failed (non-fatal) – $e');
    }

    // ── Step 3: Cache the upload result ────────────────────────────────────
    await _cache.saveLastResumeResult(uploadResult);

    return ResumeAnalysisBundle(
      uploadResult:      uploadResult,
      mlMatchPercentage: mlMatchPercentage,
      strengths:         strengths,
      weaknesses:        weaknesses,
      mlSuggestions:     mlSuggestions,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SKILL-GAP ANALYSIS
  // ═════════════════════════════════════════════════════════════════════════

  /// Analyze the skill gap between [currentSkills] and [targetRole].
  ///
  /// Strategy: ML API first → Cache fallback → null.
  /// The result is always cached (last analysis is sufficient for most UX).
  Future<Map<String, dynamic>?> analyzeSkillGap({
    required List<String> currentSkills,
    required String       targetRole,
    String? userId,
  }) async {
    // 1. ML API first.
    try {
      debugPrint('🧠 ResumeRepository: skill-gap for "$targetRole" …');
      final response = await _mlService.analyzeSkillGaps(
        userSkills: currentSkills,
        targetJob:  targetRole,
        userId:     userId,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        await _cache.saveLastSkillGap(data);
        await _cache.appendSkillGapHistory(data);
        debugPrint('✅ ResumeRepository: skill-gap – ${data['total_missing']} missing');
        return data;
      }
    } catch (e) {
      debugPrint('⚠️ ResumeRepository: skill-gap API failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadLastSkillGap();
    if (cached != null) {
      debugPrint('💾 ResumeRepository: skill-gap loaded from cache');
      return cached;
    }

    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LAST RESULT
  // ═════════════════════════════════════════════════════════════════════════

  /// Return the most recently cached resume analysis result, or null.
  Future<ResumeAnalysisResult?> getLastResumeResult() async {
    return _cache.loadLastResumeResult();
  }

  /// Return the most recently cached skill-gap payload, or null.
  Future<Map<String, dynamic>?> getLastSkillGap() async {
    return _cache.loadLastSkillGap();
  }

  /// Return the full skill-gap history (up to 20 entries), newest first.
  Future<List<Map<String, dynamic>>> getSkillGapHistory() async {
    return _cache.loadSkillGapHistory();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _friendlyError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('No internet')) {
      return 'No internet connection. Please check your network.';
    }
    if (error is String) return error;
    return 'Resume upload failed. Please try again.';
  }
}
