class UserPreferences {
  final String userId;
  final List<String> targetSkills; // Skills user wants to learn
  final int dailyStudyHoursGoal; // Hours per day
  final String learningPace; // 'slow', 'medium', 'fast'
  final List<String> preferredCategories; // Job categories of interest
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    required this.userId,
    required this.targetSkills,
    required this.dailyStudyHoursGoal,
    required this.learningPace,
    required this.preferredCategories,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['user_id'] ?? '',
      targetSkills: List<String>.from(json['target_skills'] ?? []),
      dailyStudyHoursGoal: json['daily_study_hours_goal'] ?? 1,
      learningPace: json['learning_pace'] ?? 'medium',
      preferredCategories: List<String>.from(json['preferred_categories'] ?? []),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'target_skills': targetSkills,
      'daily_study_hours_goal': dailyStudyHoursGoal,
      'learning_pace': learningPace,
      'preferred_categories': preferredCategories,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Get expected completion time based on pace
  int getExpectedCompletionDays(int totalSteps) {
    final stepsPerDay = learningPace == 'fast' ? 3 : learningPace == 'medium' ? 2 : 1;
    return (totalSteps / stepsPerDay).ceil();
  }

  // Calculate daily target based on goal and pace
  double getDailyTarget() {
    return (learningPace == 'fast' ? dailyStudyHoursGoal * 1.5 :
            learningPace == 'medium' ? dailyStudyHoursGoal.toDouble() :
            dailyStudyHoursGoal * 0.7).toDouble();
  }
}
