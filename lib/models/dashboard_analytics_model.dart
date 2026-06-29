/// Analytics data returned by GET /api/dashboard/analytics/{user_id}
///
/// Career Readiness formula (backend + Flutter are in sync):
///   career_readiness = 0.4 × resumeQuality
///                    + 0.3 × skillMatch
///                    + 0.3 × jobReadiness
///
/// Weights are redistributed proportionally when some components are missing
/// (handled server-side; this model just stores what the server computed).
class DashboardAnalyticsModel {
  /// Weighted career readiness score 0-100 (computed server-side).
  final int careerReadiness;

  /// Resume quality 0-100. Null = no analysis run yet.
  final int? resumeQuality;

  /// Skill match percentage 0-100. Null = no skill-gap or job-match run yet.
  final int? skillMatch;

  /// Job readiness score 0-100. Null = no job-readiness run yet.
  final int? jobReadiness;

  /// Profile completion percentage 0-100 (always present).
  final int profileComplete;

  /// True when the user has uploaded at least one resume.
  final bool hasResume;

  /// True when at least one AI analysis score exists.
  final bool hasData;

  /// Top missing skills from latest skill-gap analysis (may be empty).
  final List<String> missingSkills;

  /// Top priority skills to learn (may be empty).
  final List<String> prioritySkills;

  const DashboardAnalyticsModel({
    required this.careerReadiness,
    this.resumeQuality,
    this.skillMatch,
    this.jobReadiness,
    required this.profileComplete,
    this.hasResume = false,
    this.hasData = false,
    this.missingSkills = const [],
    this.prioritySkills = const [],
  });

  factory DashboardAnalyticsModel.fromJson(Map<String, dynamic> json) {
    // Backend may return ints or doubles — always convert safely.
    int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();

    List<String> _toStringList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return DashboardAnalyticsModel(
      careerReadiness:  _toInt(json['career_readiness']) ?? 0,
      resumeQuality:    _toInt(json['resume_quality']),
      skillMatch:       _toInt(json['skill_match']),
      jobReadiness:     _toInt(json['job_readiness']),
      // New endpoint uses 'profile_completion'; old uses 'profile_complete'
      profileComplete:  _toInt(json['profile_completion'] ?? json['profile_complete']) ?? 0,
      hasResume:        json['has_resume'] == true,
      hasData:          json['has_data'] == true,
      missingSkills:    _toStringList(json['missing_skills']),
      prioritySkills:   _toStringList(json['priority_skills']),
    );
  }

  /// Empty model for new users / error fallback — hasData is false so the UI
  /// shows the onboarding card instead of analytics.
  factory DashboardAnalyticsModel.empty() => const DashboardAnalyticsModel(
        careerReadiness: 0,
        profileComplete: 0,
        hasResume: false,
        hasData: false,
      );
}
