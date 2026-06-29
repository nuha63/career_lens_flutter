import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/job_role_model.dart';
import '../services/ml_api_service.dart';
import '../services/cache_service.dart';

/// Result of a full job-match analysis cycle.
class JobMatchBundle {
  /// Core match result parsed into a typed model.
  final JobMatchResult matchResult;

  /// Raw interview probability (0.0–1.0) from the ML model.
  final double interviewProbability;

  /// ML-produced confidence value (0.0–1.0).
  final double confidence;

  /// Whether the result was served from local cache.
  final bool fromCache;

  const JobMatchBundle({
    required this.matchResult,
    required this.interviewProbability,
    required this.confidence,
    this.fromCache = false,
  });
}

/// Result of a salary prediction.
class SalaryBundle {
  final int    salaryMin;
  final int    salaryMax;
  final int    salaryAvg;
  final bool   fromCache;

  const SalaryBundle({
    required this.salaryMin,
    required this.salaryMax,
    required this.salaryAvg,
    this.fromCache = false,
  });
}

/// JobMatchRepository orchestrates job matching, skill-gap analysis, and
/// salary prediction.
///
/// Strategy:
///   - Match / Salary   → ML API first → Cache fallback.
///   - History GET      → Cache only (local persistence).
class JobMatchRepository {
  final MLApiService    _mlService = getMLApiService();
  final AppCacheService _cache     = AppCacheService();

  // ═════════════════════════════════════════════════════════════════════════
  // JOB MATCHING
  // ═════════════════════════════════════════════════════════════════════════

  /// Run a job-match prediction for the given parameters.
  ///
  /// The result is persisted to local cache and added to the history list.
  /// Returns a [JobMatchBundle] on success, or the last cached result when
  /// the network is unavailable.
  ///
  /// Throws a human-readable [String] only when both API and cache fail.
  Future<JobMatchBundle> matchJob({
    required String jobTitle,
    required String company,
    required String industry,
    required double resumeScore,
    required double skillsMatchScore,
    required int    experienceYears,
    required String educationLevel,
    List<String>?   requiredSkills,
    String          jobMarketDemand = 'High',
    String          market          = 'global',
    String?         userId,
  }) async {
    // 1. ML API.
    try {
      debugPrint('🤖 JobMatchRepository: matching "$jobTitle" …');
      final response = await _mlService.matchJob(
        jobTitle:         jobTitle,
        company:          company,
        industry:         industry,
        resumeScore:      resumeScore,
        skillsMatchScore: skillsMatchScore,
        experienceYears:  experienceYears,
        educationLevel:   educationLevel,
        requiredSkills:   requiredSkills,
        jobMarketDemand:  jobMarketDemand,
        userId:           userId,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        final matchScore         = (data['match_score']          as num?)?.toDouble() ?? 0.0;
        final interviewProb      = (data['interview_probability'] as num?)?.toDouble() ?? 0.0;
        final confidence         = (data['confidence']           as num?)?.toDouble() ?? 0.0;
        final recommendation     = (data['recommendation']       as String?) ?? 'Moderate Match';

        final result = JobMatchResult(
          jobTitle:             jobTitle,
          company:              company.isEmpty ? 'Not specified' : company,
          market:               market,
          matchScore:           (matchScore * 100).toInt(),
          interviewProbability: interviewProb,
          recommendation:       recommendation,
          matchedSkills:        requiredSkills?.take(3).toList() ?? [],
          missingSkills:        const [],
          recommendations:      [recommendation],
        );

        // Persist and add to history.
        await _cache.saveLastJobMatch(result);
        await _cache.appendJobMatchHistory(result);

        debugPrint('✅ JobMatchRepository: match score ${result.matchScore}%');
        return JobMatchBundle(
          matchResult:          result,
          interviewProbability: interviewProb,
          confidence:           confidence,
        );
      }

      throw 'ML service returned an unexpected response.';
    } on SocketException {
      debugPrint('⚠️ JobMatchRepository: no network, trying cache …');
    } catch (e) {
      debugPrint('⚠️ JobMatchRepository: API failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadLastJobMatch();
    if (cached != null) {
      debugPrint('💾 JobMatchRepository: job match loaded from cache');
      return JobMatchBundle(
        matchResult:          cached,
        interviewProbability: cached.interviewProbability,
        confidence:           0.0,
        fromCache:            true,
      );
    }

    throw 'Unable to match job. Please check your network and try again.';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SKILL-GAP ANALYSIS  (convenience wrapper – delegates to ML service)
  // ═════════════════════════════════════════════════════════════════════════

  /// Analyze skill gaps for [targetJob] given the user's [currentSkills].
  ///
  /// Strategy: ML API first → Cache fallback → empty payload.
  Future<Map<String, dynamic>> analyzeSkillGap({
    required List<String> currentSkills,
    required String       targetJob,
    String?               userId,
  }) async {
    // 1. ML API.
    try {
      debugPrint('🧠 JobMatchRepository: skill-gap for "$targetJob" …');
      final response = await _mlService.analyzeSkillGaps(
        userSkills: currentSkills,
        targetJob:  targetJob,
        userId:     userId,
      );

      final data = (response['data'] as Map<String, dynamic>?) ?? {};
      if (data.isNotEmpty) {
        await _cache.saveLastSkillGap(data);
        await _cache.appendSkillGapHistory(data);
        debugPrint('✅ JobMatchRepository: ${data['total_missing']} missing skills');
        return data;
      }
    } on SocketException {
      debugPrint('⚠️ JobMatchRepository: no network for skill-gap, trying cache …');
    } catch (e) {
      debugPrint('⚠️ JobMatchRepository: skill-gap API failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadLastSkillGap();
    if (cached != null) {
      debugPrint('💾 JobMatchRepository: skill-gap loaded from cache');
      return cached;
    }

    // 3. Empty fallback so callers never receive null.
    return const {
      'missing_skills':  [],
      'priority_skills': [],
      'total_missing':   0,
      'skill_demands':   {},
    };
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SALARY PREDICTION
  // ═════════════════════════════════════════════════════════════════════════

  /// Predict a salary range for the given market factors.
  ///
  /// Strategy: ML API first → Cache fallback → sensible defaults.
  Future<SalaryBundle> predictSalary({
    required String companySize,
    required String industry,
    required bool   remoteOption,
    required int    numSkills,
    String?         userId,
  }) async {
    // 1. ML API.
    try {
      debugPrint('💰 JobMatchRepository: salary prediction …');
      final response = await _mlService.predictSalary(
        companySize:  companySize,
        industry:     industry,
        remoteOption: remoteOption,
        numSkills:    numSkills,
        userId:       userId,
      );

      final data = (response['data'] as Map<String, dynamic>?) ?? {};
      if (data.isNotEmpty) {
        final bundle = SalaryBundle(
          salaryMin: (data['salary_min'] as num?)?.toInt() ?? 0,
          salaryMax: (data['salary_max'] as num?)?.toInt() ?? 0,
          salaryAvg: (data['salary_avg'] as num?)?.toInt() ?? 0,
        );
        await _cache.saveLastSalaryPrediction(data);
        debugPrint('✅ JobMatchRepository: salary avg \$${bundle.salaryAvg}');
        return bundle;
      }
    } on SocketException {
      debugPrint('⚠️ JobMatchRepository: no network for salary, trying cache …');
    } catch (e) {
      debugPrint('⚠️ JobMatchRepository: salary API failed, trying cache. Error: $e');
    }

    // 2. Cache fallback.
    final cached = await _cache.loadLastSalaryPrediction();
    if (cached != null) {
      debugPrint('💾 JobMatchRepository: salary loaded from cache');
      return SalaryBundle(
        salaryMin: (cached['salary_min'] as num?)?.toInt() ?? 0,
        salaryMax: (cached['salary_max'] as num?)?.toInt() ?? 0,
        salaryAvg: (cached['salary_avg'] as num?)?.toInt() ?? 0,
        fromCache: true,
      );
    }

    // 3. Sensible defaults (show zeros rather than crash).
    return const SalaryBundle(
      salaryMin: 0,
      salaryMax: 0,
      salaryAvg: 0,
      fromCache: true,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HISTORY  (cache-only)
  // ═════════════════════════════════════════════════════════════════════════

  /// Return all locally cached job-match results, newest first.
  Future<List<JobMatchResult>> getJobMatchHistory() async {
    return _cache.loadJobMatchHistory();
  }

  /// Return all locally cached skill-gap results, newest first.
  Future<List<Map<String, dynamic>>> getSkillGapHistory() async {
    return _cache.loadSkillGapHistory();
  }

  /// Return the most-recently cached job match, or null.
  Future<JobMatchResult?> getLastJobMatch() async {
    return _cache.loadLastJobMatch();
  }

  /// Return the most-recently cached salary prediction payload, or null.
  Future<Map<String, dynamic>?> getLastSalaryPrediction() async {
    return _cache.loadLastSalaryPrediction();
  }
}
