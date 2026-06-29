class ProgressModel {
	final String userId;
	final int jobReadinessScore;
	final int totalSkillsToLearn;
	final int completedSkills;
	final DateTime lastUpdated;
	final Map<String, SkillProgress> skillProgress;
	final int skillsInProgress;
	final int technicalSkillScore;
	final int resumeQualityScore;
	final int experienceScore;
	final int learningProgressScore;
	final List<String> recommendations;
	final double studyHoursLogged;
	final int dailyStudyHoursGoal;
	final List<String> targetSkillsList;
	final List<String> skillsLearnedList;

	const ProgressModel({
		required this.userId,
		required this.jobReadinessScore,
		required this.totalSkillsToLearn,
		required this.completedSkills,
		required this.lastUpdated,
		required this.skillProgress,
		this.skillsInProgress = 0,
		this.technicalSkillScore = 0,
		this.resumeQualityScore = 0,
		this.experienceScore = 0,
		this.learningProgressScore = 0,
		this.recommendations = const [],
		this.studyHoursLogged = 0.0,
		this.dailyStudyHoursGoal = 1,
		this.targetSkillsList = const [],
		this.skillsLearnedList = const [],
	});

	double get overallProgress {
		if (totalSkillsToLearn <= 0) return 0.0;
		return (completedSkills / totalSkillsToLearn).clamp(0.0, 1.0);
	}

	factory ProgressModel.fromJson(Map<String, dynamic> json) {
		final map = <String, SkillProgress>{};
		final rawProgress = json['skill_progress'];
		if (rawProgress is Map) {
			rawProgress.forEach((key, value) {
				map[key.toString()] = SkillProgress.fromJson(_asMap(value));
			});
		}

		return ProgressModel(
			userId: (json['user_id'] ?? '').toString(),
			jobReadinessScore: _toInt(json['job_readiness_score']),
			totalSkillsToLearn: _toInt(json['total_skills_to_learn']),
			completedSkills: _toInt(json['completed_skills']),
			lastUpdated: _toDateTime(json['last_updated']),
			skillProgress: map,
			skillsInProgress: _toInt(json['skills_in_progress']),
			technicalSkillScore: _toInt(json['technical_skill_score']),
			resumeQualityScore: _toInt(json['resume_quality_score']),
			experienceScore: _toInt(json['experience_score']),
			learningProgressScore: _toInt(json['learning_progress_score']),
			recommendations: _stringList(json['recommendations']),
			studyHoursLogged: _toDouble(json['study_hours_logged']),
			dailyStudyHoursGoal: _toInt(json['daily_study_hours_goal']),
			targetSkillsList: _stringList(json['target_skills']),
			skillsLearnedList: _stringList(json['skills_learned']),
		);
	}

	static double _toDouble(dynamic value) {
		if (value is double) return value;
		if (value is int) return value.toDouble();
		if (value is String) return double.tryParse(value) ?? 0.0;
		return 0.0;
	}

	Map<String, dynamic> toJson() {
		return {
			'user_id': userId,
			'job_readiness_score': jobReadinessScore,
			'total_skills_to_learn': totalSkillsToLearn,
			'completed_skills': completedSkills,
			'last_updated': lastUpdated.toIso8601String(),
			'skill_progress': skillProgress.map((k, v) => MapEntry(k, v.toJson())),
			'skills_in_progress': skillsInProgress,
			'technical_skill_score': technicalSkillScore,
			'resume_quality_score': resumeQualityScore,
			'experience_score': experienceScore,
			'learning_progress_score': learningProgressScore,
			'recommendations': recommendations,
			'study_hours_logged': studyHoursLogged,
			'daily_study_hours_goal': dailyStudyHoursGoal,
			'target_skills': targetSkillsList,
			'skills_learned': skillsLearnedList,
		};
	}

	static Map<String, dynamic> _asMap(dynamic value) {
		if (value is Map<String, dynamic>) return value;
		if (value is Map) {
			return value.map((k, v) => MapEntry(k.toString(), v));
		}
		return <String, dynamic>{};
	}

	static int _toInt(dynamic value) {
		if (value is int) return value;
		if (value is double) return value.round();
		if (value is String) return int.tryParse(value) ?? 0;
		return 0;
	}

	static DateTime _toDateTime(dynamic value) {
		if (value is DateTime) return value;
		if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
		return DateTime.now();
	}

	static List<String> _stringList(dynamic value) {
		if (value is List) {
			return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
		}
		return <String>[];
	}
}

class SkillProgress {
	final String skillName;
	final double progressPercentage;
	final bool isCompleted;
	final DateTime? completedAt;
	final List<String> completedSteps;

	const SkillProgress({
		required this.skillName,
		required this.progressPercentage,
		required this.isCompleted,
		this.completedAt,
		required this.completedSteps,
	});

	factory SkillProgress.fromJson(Map<String, dynamic> json) {
		return SkillProgress(
			skillName: (json['skill_name'] ?? '').toString(),
			progressPercentage: _toDouble(json['progress_percentage']),
			isCompleted: json['is_completed'] == true,
			completedAt: _toNullableDateTime(json['completed_at']),
			completedSteps: _stringList(json['completed_steps']),
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'skill_name': skillName,
			'progress_percentage': progressPercentage,
			'is_completed': isCompleted,
			'completed_at': completedAt?.toIso8601String(),
			'completed_steps': completedSteps,
		};
	}

	static double _toDouble(dynamic value) {
		if (value is double) return value;
		if (value is int) return value.toDouble();
		if (value is String) return double.tryParse(value) ?? 0.0;
		return 0.0;
	}

	static DateTime? _toNullableDateTime(dynamic value) {
		if (value is DateTime) return value;
		if (value is String) return DateTime.tryParse(value);
		return null;
	}

	static List<String> _stringList(dynamic value) {
		if (value is List) {
			return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
		}
		return <String>[];
	}
}
