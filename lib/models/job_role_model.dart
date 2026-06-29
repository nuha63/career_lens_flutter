class JobMatchResult {
	final String jobTitle;
	final String market;
	final String company;
	final int matchScore;
	final double interviewProbability;
	final String recommendation;
	final List<String> matchedSkills;
	final List<String> missingSkills;
	final List<String> recommendations;

	const JobMatchResult({
		required this.jobTitle,
		required this.market,
		this.company = 'Not specified',
		required this.matchScore,
		this.interviewProbability = 0.5,
		this.recommendation = 'Moderate',
		required this.matchedSkills,
		required this.missingSkills,
		required this.recommendations,
	});

	factory JobMatchResult.fromApiResponse(
		Map<String, dynamic> json, {
		String market = 'global',
	}) {
		final extracted = _map(json['extracted_requirements']);
		final analysis = _map(json['analysis']);

		final matched = _stringList(
			analysis['matched_skills'] ?? json['matched_skills'],
		);

		final missing = _stringList(
			analysis['missing_skills'] ?? extracted['required_skills'] ?? json['missing_skills'],
		);

		return JobMatchResult(
			jobTitle: (json['job_title'] ?? json['title'] ?? 'Target Job').toString(),
			market: (json['market'] ?? market).toString(),
			matchScore: _toInt(
				analysis['match_score'] ?? json['match_score'] ?? json['score'],
			),
			matchedSkills: matched,
			missingSkills: missing,
			recommendations: _stringList(
				analysis['improvement_recommendations'] ?? json['recommendations'],
			),
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'job_title': jobTitle,
			'market': market,
			'match_score': matchScore,
			'matched_skills': matchedSkills,
			'missing_skills': missingSkills,
			'recommendations': recommendations,
		};
	}

	static Map<String, dynamic> _map(dynamic value) {
		if (value is Map<String, dynamic>) return value;
		if (value is Map) {
			return value.map((k, v) => MapEntry(k.toString(), v));
		}
		return <String, dynamic>{};
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
}
