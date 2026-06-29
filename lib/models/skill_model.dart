 class SkillRoadmap {
	final String skillId;
	final String skillName;
	final int estimatedDays;
	final List<String> resources;
	final List<RoadmapStep> steps;

	const SkillRoadmap({
		required this.skillId,
		required this.skillName,
		required this.estimatedDays,
		required this.resources,
		required this.steps,
	});

	factory SkillRoadmap.fromJson(Map<String, dynamic> json) {
		final stepsJson = json['steps'];
		return SkillRoadmap(
			skillId: (json['skill_id'] ?? json['id'] ?? '').toString(),
			skillName: (json['skill_name'] ?? json['name'] ?? 'Unknown Skill').toString(),
			estimatedDays: _toInt(json['estimated_days']),
			resources: _stringList(json['resources']),
			steps: stepsJson is List
					? stepsJson
							.map((step) => RoadmapStep.fromJson(_map(step)))
							.toList()
					: <RoadmapStep>[],
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'skill_id': skillId,
			'skill_name': skillName,
			'estimated_days': estimatedDays,
			'resources': resources,
			'steps': steps.map((s) => s.toJson()).toList(),
		};
	}

	static List<String> _stringList(dynamic value) {
		if (value is List) {
			return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
		}
		return <String>[];
	}

	static int _toInt(dynamic value) {
		if (value is int) return value;
		if (value is double) return value.round();
		if (value is String) return int.tryParse(value) ?? 0;
		return 0;
	}

	static Map<String, dynamic> _map(dynamic value) {
		if (value is Map<String, dynamic>) return value;
		if (value is Map) {
			return value.map((k, v) => MapEntry(k.toString(), v));
		}
		return <String, dynamic>{};
	}
}

class RoadmapStep {
	final int order;
	final String title;
	final String description;
	final int durationDays;
	final bool isCompleted;

	const RoadmapStep({
		required this.order,
		required this.title,
		required this.description,
		required this.durationDays,
		this.isCompleted = false,
	});

	factory RoadmapStep.fromJson(Map<String, dynamic> json) {
		return RoadmapStep(
			order: _toInt(json['order']),
			title: (json['title'] ?? '').toString(),
			description: (json['description'] ?? '').toString(),
			durationDays: _toInt(json['duration_days']),
			isCompleted: json['is_completed'] == true,
		);
	}

	RoadmapStep copyWith({
		int? order,
		String? title,
		String? description,
		int? durationDays,
		bool? isCompleted,
	}) {
		return RoadmapStep(
			order: order ?? this.order,
			title: title ?? this.title,
			description: description ?? this.description,
			durationDays: durationDays ?? this.durationDays,
			isCompleted: isCompleted ?? this.isCompleted,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'order': order,
			'title': title,
			'description': description,
			'duration_days': durationDays,
			'is_completed': isCompleted,
		};
	}

	static int _toInt(dynamic value) {
		if (value is int) return value;
		if (value is double) return value.round();
		if (value is String) return int.tryParse(value) ?? 0;
		return 0;
	}
}
