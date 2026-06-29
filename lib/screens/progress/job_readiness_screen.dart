import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/progress_model.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/custom_button.dart';

class JobReadinessScreen extends StatefulWidget {
  const JobReadinessScreen({super.key});

  @override
  State<JobReadinessScreen> createState() => _JobReadinessScreenState();
}

class _JobReadinessScreenState extends State<JobReadinessScreen> {
  final ProgressRepository  _progressRepo = ProgressRepository();
  final AuthRepository      _authRepo     = AuthRepository();
  final AppCacheService     _cache        = AppCacheService();
  final ConnectivityService _conn         = ConnectivityService();

  ProgressModel? _data;
  String?        _userId;
  bool           _isRefreshing = false;
  bool           _fromCache    = false;
  bool           _isOffline    = false;
  String?        _cacheAgeLabel;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ── Stale-while-revalidate ───────────────────────────────────────────────
  Future<void> _bootstrap() async {
    _userId = await _authRepo.getUserId();
    if (_userId == null) return;

    // Step 1: instant stale read → no blank screen
    await _loadFromCache();

    // Step 2: background fresh fetch
    await _refreshFromApi();
  }

  Future<void> _loadFromCache() async {
    if (_userId == null) return;
    final entry = await _cache.loadProgressWithMeta(_userId!);
    if (entry != null && mounted) {
      setState(() {
        _data          = entry.data;
        _fromCache     = true;
        _cacheAgeLabel = entry.ageLabel;
      });
    }
  }

  Future<void> _refreshFromApi() async {
    if (_userId == null || !mounted) return;
    _isOffline = !(await _conn.checkConnectivity());
    if (_isOffline) { if (mounted) setState(() {}); return; }

    setState(() => _isRefreshing = true);
    try {
      final fresh = await _progressRepo.getProgress(_userId!);
      if (mounted) {
        setState(() {
          _data          = fresh;
          _fromCache     = false;
          _cacheAgeLabel = 'just now';
          _isRefreshing  = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ JobReadiness refresh failed: $e');
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _retry() async {
    setState(() { _data = null; _fromCache = false; });
    await _bootstrap();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Loading state: only if we have no data at all yet
    if (_data == null && _isRefreshing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Readiness')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // No data and not refreshing → error / empty
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Readiness')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assessment_outlined, size: 72,
                  color: AppTheme.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 20),
              Text(_isOffline ? 'No cached data available offline.'
                  : 'Unable to load readiness data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Readiness'),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _retry),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ──────────────────────────────────────────────
            if (_fromCache || _isOffline) _buildStatusBanner(),

            // ── Main score card ────────────────────────────────────────────
            _buildScoreCard(),
            const SizedBox(height: 32),

            // ── Stats grid ────────────────────────────────────────────────
            _buildStatsGrid(),
            const SizedBox(height: 32),

            // ── Score breakdown ───────────────────────────────────────────
            Text('Score Breakdown', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildBreakdownItem('Technical Skills',  _data!.technicalSkillScore,
                'Your proficiency in required technical skills'),
            _buildBreakdownItem('Resume Quality',    _data!.resumeQualityScore,
                'ATS compatibility and resume optimization'),
            _buildBreakdownItem('Experience Match',  _data!.experienceScore,
                'How your experience matches job requirements'),
            _buildBreakdownItem('Learning Progress', _data!.learningProgressScore,
                'Your commitment to continuous learning'),
            const SizedBox(height: 32),

            // ── Recommendations ───────────────────────────────────────────
            _buildRecommendationsBox(),
            const SizedBox(height: 32),

            // ── Actions ───────────────────────────────────────────────────
            CustomButton(
              label: 'Continue Learning',
              onPressed: () => Navigator.pop(context),
              icon: Icons.school,
            ),
            const SizedBox(height: 12),
            CustomButton(
              label: 'View Career Roadmaps',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.careerRoadmaps),
              icon: Icons.map,
            ),

            // ── Cache footer ──────────────────────────────────────────────
            if (_fromCache) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '💾 Cached data · $_cacheAgeLabel',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final color = _isOffline ? AppTheme.errorColor : AppTheme.warningColor;
    final text  = _isOffline
        ? '📶 Offline – showing cached data from $_cacheAgeLabel'
        : '💾 Showing cached data · refreshing in background…';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Icon(_isOffline ? Icons.wifi_off : Icons.cached, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            ),
            if (!_isOffline)
              SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final score = _data!.jobReadinessScore;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:       AppTheme.primaryColor.withOpacity(0.1),
              blurRadius:  20,
              offset:      const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text('Job Readiness Score', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            CircularPercentIndicator(
              radius:    100,
              lineWidth: 16,
              percent:   (score / 100).clamp(0.0, 1.0),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$score',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color:       AppTheme.getATSScoreColor(score),
                      fontWeight:  FontWeight.bold,
                      fontSize:    48,
                    )),
                  Text('out of 100', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              progressColor:      AppTheme.getATSScoreColor(score),
              backgroundColor:    AppTheme.getATSScoreColor(score).withOpacity(0.2),
              circularStrokeCap:  CircularStrokeCap.round,
              animation:          true,
              animationDuration:  1500,
            ),
            const SizedBox(height: 24),
            Text(
              _getReadinessMessage(score),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final completed   = _data!.completedSkills;
    final total       = _data!.totalSkillsToLearn;
    final inProgress  = _data!.skillsInProgress;
    final toLearn     = (total - completed - inProgress).clamp(0, total);

    return Row(
      children: [
        Expanded(child: _buildStatCard(Icons.check_circle, '$completed',   'Skills\nCompleted', AppTheme.successColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(Icons.schedule,     '$inProgress',  'In\nProgress',      AppTheme.warningColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(Icons.pending,      '$toLearn',     'To\nLearn',         AppTheme.errorColor)),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String title, int score, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:        AppTheme.getATSScoreColor(score).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$score%',
                      style: TextStyle(
                        color:       AppTheme.getATSScoreColor(score),
                        fontWeight:  FontWeight.bold,
                        fontSize:    14,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           (score / 100).clamp(0.0, 1.0),
                minHeight:       6,
                backgroundColor: AppTheme.getATSScoreColor(score).withOpacity(0.2),
                valueColor:      AlwaysStoppedAnimation<Color>(AppTheme.getATSScoreColor(score)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsBox() {
    if (_data!.recommendations.isEmpty) return const SizedBox.shrink();
    return Container(
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.infoColor),
              const SizedBox(width: 8),
              Text('Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:       AppTheme.infoColor,
                    fontWeight:  FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ..._data!.recommendations.map(_buildRecommendationItem),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 20, color: AppTheme.infoColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _getReadinessMessage(int score) {
    if (score >= 80) return 'Excellent! You\'re ready to apply for jobs!';
    if (score >= 60) return 'Good progress! Keep learning to boost your chances.';
    if (score >= 40) return 'You\'re on the right track. Continue improving your skills.';
    return 'Focus on completing your learning roadmap.';
  }
}