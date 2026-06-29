import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/job_role_model.dart';
import '../../repositories/job_match_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/ats_score_card.dart';
import '../../widgets/skill_chip.dart';
import '../../widgets/custom_button.dart';

class JobMatcherScreen extends StatefulWidget {
  const JobMatcherScreen({super.key});

  @override
  State<JobMatcherScreen> createState() => _JobMatcherScreenState();
}

class _JobMatcherScreenState extends State<JobMatcherScreen> {
  // ── Repositories ──────────────────────────────────────────────────────────
  final JobMatchRepository  _jobMatchRepo = JobMatchRepository();
  final AuthRepository      _authRepo     = AuthRepository();
  final AppCacheService     _cache        = AppCacheService();
  final ConnectivityService _conn         = ConnectivityService();

  String? _userId;
  bool    _isLoading  = false;
  bool    _isOffline  = false;

  // ── Form fields ───────────────────────────────────────────────────────────
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _companyController  = TextEditingController();
  double        _resumeScore      = 0.75;
  double        _skillsMatchScore = 80.0;
  int           _experienceYears  = 5;
  String        _educationLevel   = 'Bachelor';
  String        _industry         = 'IT';
  List<String>  _requiredSkills   = [];

  // ── Result state ──────────────────────────────────────────────────────────
  JobMatchBundle?  _currentResult;    // result from current session analysis
  JobMatchResult?  _cachedResult;     // last saved result from previous session
  String?          _cachedResultAge;  // human-readable age label

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await _authRepo.getUserId();
    await _loadLastCachedMatch();
    final online = await _conn.checkConnectivity();
    if (mounted) setState(() => _isOffline = !online);
  }

  // ── Step 1: Show last cached result immediately (stale read) ──────────────
  Future<void> _loadLastCachedMatch() async {
    final entry = await _cache.loadLastJobMatchWithMeta();
    if (entry != null && mounted) {
      setState(() {
        _cachedResult    = entry.data;
        _cachedResultAge = entry.ageLabel;
      });
    }
  }

  // ── Step 2: Run a new job match via repository (handles caching) ──────────
  Future<void> _matchJob() async {
    if (_jobTitleController.text.trim().isEmpty) {
      Helpers.showErrorToast('Please enter a job title');
      return;
    }
    if (_isOffline) {
      Helpers.showErrorToast('No network connection. Showing cached result.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bundle = await _jobMatchRepo.matchJob(
        jobTitle:         _jobTitleController.text.trim(),
        company:          _companyController.text.trim(),
        industry:         _industry,
        resumeScore:      _resumeScore,
        skillsMatchScore: _skillsMatchScore,
        experienceYears:  _experienceYears,
        educationLevel:   _educationLevel,
        requiredSkills:   _requiredSkills,
        userId:           _userId,
      );

      if (mounted) {
        setState(() {
          _currentResult   = bundle;
          _cachedResult    = bundle.matchResult; // update cache preview too
          _cachedResultAge = 'just now';
        });
        Helpers.showSuccessToast('Job match analysis complete!');
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e.toString());
      debugPrint('JobMatcher error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show result view if we have a current-session result
    if (_currentResult != null) return _buildResultView(_currentResult!.matchResult);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Matcher')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Text('Find Your Perfect Match',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('AI-powered job matching based on your profile',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),

            // ── Offline chip ───────────────────────────────────────────────
            if (_isOffline) _buildOfflineBanner(),

            // ── Last cached result card (from previous session) ────────────
            if (_cachedResult != null && !_isOffline) ...[
              _buildPreviousResultCard(_cachedResult!),
              const SizedBox(height: 24),
            ],

            // ── Form ───────────────────────────────────────────────────────
            _buildTextField(label: 'Job Title',
                controller: _jobTitleController, hint: 'e.g., Flutter Developer'),
            const SizedBox(height: 16),
            _buildTextField(label: 'Company',
                controller: _companyController, hint: 'e.g., Google'),
            const SizedBox(height: 16),
            _buildSlider(
              label:     'Resume Score: ${(_resumeScore * 100).toStringAsFixed(0)}%',
              value:     _resumeScore, min: 0, max: 1,
              onChanged: (v) => setState(() => _resumeScore = v),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label:     'Skills Match: ${_skillsMatchScore.toStringAsFixed(0)}%',
              value:     _skillsMatchScore, min: 0, max: 100,
              onChanged: (v) => setState(() => _skillsMatchScore = v),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label:     'Experience Years: $_experienceYears',
              value:     _experienceYears.toDouble(), min: 0, max: 20,
              onChanged: (v) => setState(() => _experienceYears = v.toInt()),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Education Level', value: _educationLevel,
              items: ['High School', 'Bachelor', 'Master', 'PhD'],
              onChanged: (v) { if (v != null) setState(() => _educationLevel = v); },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Industry', value: _industry,
              items: ['IT', 'Finance', 'Healthcare', 'Manufacturing'],
              onChanged: (v) { if (v != null) setState(() => _industry = v); },
            ),
            const SizedBox(height: 32),
            CustomButton(
              label:     _isLoading ? 'Analyzing…' : 'Analyze Match',
              onPressed: _isLoading ? null : _matchJob,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  // ── Previous session cached result preview ────────────────────────────────
  Widget _buildPreviousResultCard(JobMatchResult result) {
    final color = AppTheme.getATSScoreColor(result.matchScore);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('Last Saved Match · $_cachedResultAge',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentResult = JobMatchBundle(
                  matchResult:          result,
                  interviewProbability: result.interviewProbability,
                  confidence:           0,
                  fromCache:            true,
                )),
                child: Text('View →',
                    style: TextStyle(fontSize: 12, color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.jobTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    if (result.company.isNotEmpty)
                      Text(result.company,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${result.matchScore}%',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        AppTheme.errorColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.errorColor.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _cachedResult != null
                    ? '📶 Offline – showing your last saved match from $_cachedResultAge'
                    : '📶 Offline – no cached result available.',
                style: TextStyle(fontSize: 12, color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result view ───────────────────────────────────────────────────────────
  Widget _buildResultView(JobMatchResult result) {
    final fromCache = _currentResult?.fromCache ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _currentResult = null),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:        AppTheme.warningColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppTheme.warningColor.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cached, size: 14, color: AppTheme.warningColor),
                      const SizedBox(width: 8),
                      Text('Showing cached result from $_cachedResultAge',
                          style: TextStyle(fontSize: 12, color: AppTheme.warningColor)),
                    ],
                  ),
                ),
              ),
            Text(result.jobTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(result.company.isNotEmpty ? result.company : 'Not specified',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            ATSScoreCard(score: result.matchScore, title: 'Match Score',
                subtitle: 'How well you match this job'),
            const SizedBox(height: 32),
            // Interview probability
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interview Probability',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('${(result.interviewProbability * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Icon(
                    result.interviewProbability > 0.7 ? Icons.check_circle : Icons.info,
                    color: AppTheme.primaryColor, size: 48,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Recommendation', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        _getRecommendationColor(result).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(
                    color: _getRecommendationColor(result).withOpacity(0.3)),
              ),
              child: Text(
                result.recommendation,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _getRecommendationColor(result), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Analyze a Different Job',
              onPressed: () => setState(() => _currentResult = null),
              icon: Icons.search,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRecommendationColor(JobMatchResult result) {
    final rec = result.recommendation.toLowerCase();
    if (rec.contains('strong') || rec.contains('excellent')) return Colors.green;
    if (rec.contains('moderate') || rec.contains('good')) return Colors.orange;
    return Colors.red;
  }

  // ── Form helpers ──────────────────────────────────────────────────────────
  Widget _buildTextField({
    required String                 label,
    required TextEditingController  controller,
    String?                         hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText:     hint,
            border:       OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String         label,
    required double         value,
    required double         min,
    required double         max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Slider(value: value, min: min, max: max,
            onChanged: onChanged, activeColor: AppTheme.primaryColor),
      ],
    );
  }

  Widget _buildDropdown({
    required String              label,
    required String              value,
    required List<String>        items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value:      value,
          isExpanded: true,
          items:      items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged:  onChanged,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    super.dispose();
  }
}
