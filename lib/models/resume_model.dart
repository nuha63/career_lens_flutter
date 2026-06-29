class ResumeAnalysisResult {
	final String resumeId;
	final String resumeText;
	final int atsScore;
	final List<String> detectedSkills;
	final List<String> suggestions;
	final Map<String, dynamic> statistics;
	final String market;

	const ResumeAnalysisResult({
		required this.resumeId,
		required this.resumeText,
		required this.atsScore,
		required this.detectedSkills,
		required this.suggestions,
		required this.statistics,
		required this.market,
	});

	factory ResumeAnalysisResult.fromApiResponse(
		Map<String, dynamic> json, {
		String market = 'global',
	}) {
		final parsedStats = _asMap(json['statistics']);
		final parsedSkills = _asStringList(
			json['detected_skills'] ?? json['skills'] ?? json['missing_skills'],
		);
		final parsedSuggestions = _asStringList(
			json['suggestions'] ?? json['recommendations'],
		);

		return ResumeAnalysisResult(
			resumeId: (json['resume_id'] ?? json['id'] ?? '').toString(),
			resumeText: (json['resume_text'] ?? json['parsed_text'] ?? '').toString(),
			atsScore: _toInt(
				json['ats_score'] ?? json['score'] ?? parsedStats['ats_score'],
			),
			detectedSkills: parsedSkills,
			suggestions: parsedSuggestions,
			statistics: parsedStats,
			market: (json['market'] ?? market).toString(),
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'resume_id': resumeId,
			'resume_text': resumeText,
			'ats_score': atsScore,
			'detected_skills': detectedSkills,
			'suggestions': suggestions,
			'statistics': statistics,
			'market': market,
		};
	}

	static int _toInt(dynamic value) {
		if (value is int) return value;
		if (value is double) return value.round();
		if (value is String) return int.tryParse(value) ?? 0;
		return 0;
	}

	static List<String> _asStringList(dynamic value) {
		if (value is List) {
			return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
		}
		return <String>[];
	}

	static Map<String, dynamic> _asMap(dynamic value) {
		if (value is Map<String, dynamic>) return value;
		if (value is Map) {
			return value.map((key, val) => MapEntry(key.toString(), val));
		}
		return <String, dynamic>{};
	}
}
