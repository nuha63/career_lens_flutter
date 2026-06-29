import 'package:flutter/foundation.dart';

/// Models for the AI Career Roadmap feature.

class CareerRoadmap {
  final String id;
  final String careerName;
  final String description;
  final String estimatedDuration;
  final String iconName;
  final int totalPhases;
  final int completedPhases;
  final int overallCompletionPercentage;
  final List<RoadmapPhase> phases;
  final DateTime? createdAt;

  const CareerRoadmap({
    required this.id,
    required this.careerName,
    required this.description,
    required this.estimatedDuration,
    required this.iconName,
    this.totalPhases = 0,
    this.completedPhases = 0,
    this.overallCompletionPercentage = 0,
    this.phases = const [],
    this.createdAt,
  });

  factory CareerRoadmap.fromJson(Map<String, dynamic> json) {
    // If the response is nested under 'data' or 'roadmap' key, extract it
    Map<String, dynamic> parsedJson = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      parsedJson = json['data'] as Map<String, dynamic>;
    }
    if (parsedJson.containsKey('roadmap') && parsedJson['roadmap'] is Map<String, dynamic>) {
      parsedJson = parsedJson['roadmap'] as Map<String, dynamic>;
    }

    debugPrint('CareerRoadmap JSON: $parsedJson');
    final phasesJson = parsedJson['phases'];
    final phases = phasesJson is List
        ? phasesJson.map((p) => RoadmapPhase.fromJson(p as Map<String, dynamic>)).toList()
        : <RoadmapPhase>[];
    debugPrint('Mapped phases count: ${phases.length}');
    
    return CareerRoadmap(
      id: (parsedJson['id'] ?? '').toString(),
      careerName: (parsedJson['career_name'] ?? 'Unknown Career').toString(),
      description: (parsedJson['description'] ?? '').toString(),
      estimatedDuration: (parsedJson['estimated_duration'] ?? '').toString(),
      iconName: (parsedJson['icon_name'] ?? 'work').toString(),
      totalPhases: _toInt(parsedJson['total_phases']),
      completedPhases: _toInt(parsedJson['completed_phases']),
      overallCompletionPercentage: _toInt(parsedJson['overall_completion_percentage']),
      phases: phases,
      createdAt: parsedJson['created_at'] != null
          ? DateTime.tryParse(parsedJson['created_at'].toString())
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Return a copy with updated phases (e.g. after toggling completion).
  CareerRoadmap copyWithPhases(List<RoadmapPhase> newPhases) {
    final total = newPhases.length;
    final completed = newPhases.where((p) => p.isCompleted).length;
    final progress = total == 0 ? 0 : (completed / total * 100).round();
    return CareerRoadmap(
      id: id,
      careerName: careerName,
      description: description,
      estimatedDuration: estimatedDuration,
      iconName: iconName,
      totalPhases: total,
      completedPhases: completed,
      overallCompletionPercentage: progress,
      phases: newPhases,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'career_name': careerName,
      'description': description,
      'estimated_duration': estimatedDuration,
      'icon_name': iconName,
      'total_phases': totalPhases,
      'completed_phases': completedPhases,
      'overall_completion_percentage': overallCompletionPercentage,
      'phases': phases.map((p) => p.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class RoadmapSkill {
  final String id;
  final String skillName;
  final bool isCompleted;

  const RoadmapSkill({
    required this.id,
    required this.skillName,
    this.isCompleted = false,
  });

  factory RoadmapSkill.fromJson(Map<String, dynamic> json) {
    return RoadmapSkill(
      id: (json['id'] ?? '').toString(),
      skillName: (json['skill_name'] ?? '').toString(),
      isCompleted: json['is_completed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'skill_name': skillName,
      'is_completed': isCompleted,
    };
  }

  RoadmapSkill copyWith({bool? isCompleted}) {
    return RoadmapSkill(
      id: id,
      skillName: skillName,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class RoadmapPhase {
  final String id;
  final String roadmapId;
  final int phaseNumber;
  final String phaseTitle;
  final String phaseDescription;
  final int estimatedWeeks;
  final int completionPercentage;
  final List<RoadmapSkill> keySkills;
  final bool isCompleted;
  final DateTime? createdAt;

  const RoadmapPhase({
    required this.id,
    required this.roadmapId,
    required this.phaseNumber,
    required this.phaseTitle,
    required this.phaseDescription,
    required this.estimatedWeeks,
    required this.completionPercentage,
    this.keySkills = const [],
    this.isCompleted = false,
    this.createdAt,
  });

  factory RoadmapPhase.fromJson(Map<String, dynamic> json) {
    return RoadmapPhase(
      id: (json['id'] ?? '').toString(),
      roadmapId: (json['roadmap_id'] ?? '').toString(),
      phaseNumber: _toInt(json['phase_number']),
      phaseTitle: (json['phase_title'] ?? '').toString(),
      phaseDescription: (json['phase_description'] ?? '').toString(),
      estimatedWeeks: _toInt(json['estimated_weeks']),
      completionPercentage: _toInt(json['completion_percentage']),
      keySkills: json['key_skills'] is List
          ? (json['key_skills'] as List).map((e) {
              if (e is Map<String, dynamic>) {
                return RoadmapSkill.fromJson(e);
              } else {
                return RoadmapSkill(id: e.toString(), skillName: e.toString());
              }
            }).toList()
          : [],
      isCompleted: json['is_completed'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  RoadmapPhase copyWith({
    bool? isCompleted,
    int? completionPercentage,
    List<RoadmapSkill>? keySkills,
  }) {
    return RoadmapPhase(
      id: id,
      roadmapId: roadmapId,
      phaseNumber: phaseNumber,
      phaseTitle: phaseTitle,
      phaseDescription: phaseDescription,
      estimatedWeeks: estimatedWeeks,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      keySkills: keySkills ?? this.keySkills,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roadmap_id': roadmapId,
      'phase_number': phaseNumber,
      'phase_title': phaseTitle,
      'phase_description': phaseDescription,
      'estimated_weeks': estimatedWeeks,
      'completion_percentage': completionPercentage,
      'key_skills': keySkills.map((s) => s.toJson()).toList(),
      'is_completed': isCompleted,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}


class RoadmapRecommendation {
  final CareerRoadmap roadmap;
  final String reason;
  final List<String> highlightedSkills;

  const RoadmapRecommendation({
    required this.roadmap,
    required this.reason,
    this.highlightedSkills = const [],
  });

  factory RoadmapRecommendation.fromJson(Map<String, dynamic> json) {
    return RoadmapRecommendation(
      roadmap: CareerRoadmap.fromJson(
        json['roadmap'] is Map<String, dynamic>
            ? json['roadmap'] as Map<String, dynamic>
            : {},
      ),
      reason: (json['reason'] ?? '').toString(),
      highlightedSkills: json['highlighted_skills'] is List
          ? (json['highlighted_skills'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}
