import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/api_service.dart';
import '../../models/dashboard_analytics_model.dart';
import '../../widgets/animated_background.dart';

// ─────────────────────────────────────────────────────────────
// Dashboard loading state
// ─────────────────────────────────────────────────────────────
enum _AnalyticsState { loading, loaded, empty, error }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final AppCacheService _cache = AppCacheService();
  final ConnectivityService _conn = ConnectivityService();
  final ApiService _apiService = ApiService();

  String _userName = 'User';
  bool _isOffline = false;
  _AnalyticsState _analyticsState = _AnalyticsState.loading;
  DashboardAnalyticsModel? _analytics;

  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initData();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (mounted) setState(() => _analyticsState = _AnalyticsState.loading);
    await Future.wait([_loadFromCache(), _checkConnectivity()]);
    await _fetchAnalytics();
  }

  Future<void> _loadFromCache() async {
    final user = await _cache.loadUserStale();
    if (user != null && mounted) {
      setState(() => _userName = user.name.isNotEmpty ? user.name : 'User');
    } else {
      final sp = await SharedPreferences.getInstance();
      final name = sp.getString('user_name') ?? 'User';
      if (mounted) setState(() => _userName = name.isNotEmpty ? name : 'User');
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await _conn.checkConnectivity();
    if (mounted) setState(() => _isOffline = !online);
  }

  Future<void> _fetchAnalytics() async {
    if (_isOffline) {
      if (mounted) setState(() => _analyticsState = _AnalyticsState.empty);
      return;
    }
    try {
      final user = await _cache.loadUserStale();
      if (user == null) {
        if (mounted) setState(() => _analyticsState = _AnalyticsState.empty);
        return;
      }
      final data = await _apiService.getDashboardAnalytics(user.id);
      final model = DashboardAnalyticsModel.fromJson(data);
      if (mounted) {
        setState(() {
          _analytics = model;
          _analyticsState =
              model.hasData ? _AnalyticsState.loaded : _AnalyticsState.empty;
        });
        if (model.hasData) _ringController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) setState(() => _analyticsState = _AnalyticsState.error);
    }
  }

  // ── Career Readiness from formula: 40% Resume + 30% Skill + 30% Job ──
  int get _computedCareerReadiness {
    final a = _analytics;
    if (a == null) return 0;
    double score = 0;
    int weight = 0;
    if (a.resumeQuality != null) { score += a.resumeQuality! * 0.4; weight += 40; }
    if (a.skillMatch != null)    { score += a.skillMatch!    * 0.3; weight += 30; }
    if (a.jobReadiness != null)  { score += a.jobReadiness!  * 0.3; weight += 30; }
    if (weight == 0) return a.careerReadiness; // fallback to backend value
    // Scale to full 100 if some data is missing
    return (score / (weight / 100)).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Evening';
    if (hour < 12)      greeting = 'Good Morning';
    else if (hour < 17) greeting = 'Good Afternoon';

    return Scaffold(
      body: AnimatedBackground(
        staticImage: 'assets/images/background.jpg',
        child: RefreshIndicator(
          onRefresh: _initData,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ───────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_off,
                                      size: 14,
                                      color: AppTheme.errorColor),
                                  const SizedBox(width: 4),
                                  Text('Offline Mode',
                                      style: TextStyle(
                                          color: AppTheme.errorColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ).animate().fade().slideY(begin: -0.5, end: 0),
                          const Spacer(),
                          Text(greeting,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppTheme.textSecondary))
                              .animate()
                              .fade(duration: 500.ms)
                              .slideX(begin: -0.1, end: 0),
                          const SizedBox(height: 4),
                          Text(_userName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold))
                              .animate()
                              .fade(delay: 200.ms)
                              .slideX(begin: -0.1, end: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Analytics Section ───────────────────────────────
                    _buildAnalyticsSection(context),

                    const SizedBox(height: 32),

                    // ── Quick Actions ───────────────────────────────────
                    Text('Quick Actions',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600))
                        .animate()
                        .fade(delay: 400.ms),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),

                    const SizedBox(height: 32),

                    // ── Recommendations ─────────────────────────────────
                    _buildRecommendationsSection(context),

                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Analytics Section – switches on _analyticsState
  // ─────────────────────────────────────────────────────────────
  Widget _buildAnalyticsSection(BuildContext context) {
    switch (_analyticsState) {
      case _AnalyticsState.loading:
        return _buildLoadingShimmer(context);

      case _AnalyticsState.error:
        return _buildErrorCard(context);

      case _AnalyticsState.empty:
        return _buildOnboardingCard(context);

      case _AnalyticsState.loaded:
        return _buildAnalyticsDashboard(context);
    }
  }

  // ── Loading Shimmer ───────────────────────────────────────────
  Widget _buildLoadingShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base =
        isDark ? AppTheme.darkSurfaceColor : const Color(0xFFE5E7EB);
    final highlight =
        isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6);

    Widget shimmerBox(double h, {double? w, double radius = 12}) =>
        Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(
              duration: 1200.ms,
              color: highlight,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shimmerBox(160, radius: 24),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: shimmerBox(90, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: shimmerBox(90, radius: 20)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: shimmerBox(90, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: shimmerBox(90, radius: 20)),
        ]),
      ],
    );
  }

  // ── Error Card ────────────────────────────────────────────────
  Widget _buildErrorCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded,
                size: 40, color: AppTheme.errorColor),
          ),
          const SizedBox(height: 16),
          Text('Unable to load career insights right now.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Pull down to refresh or check your connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            onPressed: _initData,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0);
  }

  // ── Onboarding Card (no resume yet) ──────────────────────────
  Widget _buildOnboardingCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Illustration ring
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.15),
                  AppTheme.secondaryColor.withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.insert_chart_outlined_rounded,
                size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text('Career Readiness Not Available',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Upload your resume to generate personalized career '
            'insights, job readiness scores, skill gap analysis, '
            'and roadmap recommendations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 24),
          // Feature pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _FeaturePill(icon: Icons.description_outlined,   label: 'Resume Quality'),
              _FeaturePill(icon: Icons.psychology_outlined,    label: 'Skill Match'),
              _FeaturePill(icon: Icons.work_outline_rounded,   label: 'Job Readiness'),
              _FeaturePill(icon: Icons.route_rounded,          label: 'Career Roadmap'),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Resume'),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.resumeUpload),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.08, end: 0);
  }

  // ── Full Analytics Dashboard ──────────────────────────────────
  Widget _buildAnalyticsDashboard(BuildContext context) {
    final a = _analytics!;
    final readiness = _computedCareerReadiness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score ring card
        _buildReadinessRingCard(context, readiness),
        const SizedBox(height: 16),

        // 2×2 metric cards
        Row(children: [
          Expanded(
              child: _buildMetricCard(
            context,
            label: 'Resume Quality',
            value: a.resumeQuality,
            icon: Icons.description_outlined,
            color: AppTheme.successColor,
            delay: 200.ms,
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _buildMetricCard(
            context,
            label: 'Skill Match',
            value: a.skillMatch,
            icon: Icons.psychology_outlined,
            color: AppTheme.warningColor,
            delay: 300.ms,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _buildMetricCard(
            context,
            label: 'Job Readiness',
            value: a.jobReadiness,
            icon: Icons.work_outline_rounded,
            color: AppTheme.primaryColor,
            delay: 400.ms,
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _buildMetricCard(
            context,
            label: 'Profile Complete',
            value: a.profileComplete,
            icon: Icons.person_outline_rounded,
            color: AppTheme.secondaryColor,
            delay: 500.ms,
          )),
        ]),

        // Personalized insights
        if (a.resumeQuality != null || a.skillMatch != null) ...[
          const SizedBox(height: 24),
          _buildInsightsCard(context, a),
        ],
      ],
    );
  }

  // ── Readiness Ring Card ───────────────────────────────────────
  Widget _buildReadinessRingCard(BuildContext context, int score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scoreColor = score >= 70
        ? AppTheme.successColor
        : score >= 40
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final label = score >= 70
        ? 'Career Ready 🎉'
        : score >= 40
            ? 'In Progress 🚀'
            : 'Just Getting Started ✨';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
        border: Border.all(color: scoreColor.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (_, __) => SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  progress: _ringController.value * (score / 100),
                  color: scoreColor,
                  background:
                      isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                ),
                child: Center(
                  child: Text(
                    '${(score * _ringController.value).round()}',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: scoreColor),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Career Readiness',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('$score / 100',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: scoreColor)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Formula: 40% Resume + 30% Skill + 30% Job Readiness',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 100.ms).slideY(begin: 0.08, end: 0);
  }

  // ── Metric Card ───────────────────────────────────────────────
  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required dynamic value,
    required IconData icon,
    required Color color,
    required Duration delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int pct = (value is int) ? value : (value ?? 0) as int;
    final bool hasValue = value != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (hasValue)
                Text('$pct%',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          hasValue
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100.0,
                    backgroundColor: color.withOpacity(0.1),
                    color: color,
                    minHeight: 6,
                  ),
                )
              : Text('—',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    ).animate(delay: delay).fade().slideY(begin: 0.1, end: 0);
  }

  // ── Insights Card ─────────────────────────────────────────────
  Widget _buildInsightsCard(BuildContext context, DashboardAnalyticsModel a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color _statusColor(int? v) =>
        v == null ? Colors.grey : v >= 70 ? AppTheme.successColor : v >= 40 ? AppTheme.warningColor : AppTheme.errorColor;

    String _statusText(int? v) =>
        v == null ? 'N/A' : v >= 70 ? 'Good' : v >= 40 ? 'Needs Work' : 'Low';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personalized Insights',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600))
            .animate()
            .fade(delay: 600.ms),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              _insightRow(context, 'Resume Quality', a.resumeQuality,
                  _statusColor(a.resumeQuality), _statusText(a.resumeQuality)),
              _divider(),
              _insightRow(context, 'Skill Match', a.skillMatch,
                  _statusColor(a.skillMatch), _statusText(a.skillMatch)),
              _divider(),
              _insightRow(context, 'Job Readiness', a.jobReadiness,
                  _statusColor(a.jobReadiness), _statusText(a.jobReadiness)),
              _divider(),
              _insightRow(context, 'Profile Complete', a.profileComplete,
                  _statusColor(a.profileComplete), _statusText(a.profileComplete)),
            ],
          ),
        ).animate().fade(delay: 650.ms),
      ],
    );
  }

  Widget _insightRow(BuildContext context, String label, dynamic value,
      Color color, String status) {
    final int pct = value is int ? value : (value ?? 0) as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100.0,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$pct%',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.12));

  // ─────────────────────────────────────────────────────────────
  // Quick Actions
  // ─────────────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildActionTile(context,
            title: 'Job Market',
            icon: Icons.public_rounded,
            color: AppTheme.primaryColor,
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.marketSelection),
            delay: 400.ms),
        _buildActionTile(context,
            title: 'Roadmaps',
            icon: Icons.route_rounded,
            color: AppTheme.warningColor,
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.careerRoadmaps),
            delay: 500.ms),
        _buildActionTile(context,
            title: 'Track Progress',
            icon: Icons.trending_up_rounded,
            color: AppTheme.successColor,
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.progressTracker),
            delay: 600.ms),
        _buildActionTile(context,
            title: 'Salary Predict',
            icon: Icons.attach_money_rounded,
            color: AppTheme.secondaryColor,
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.salaryPrediction),
            delay: 700.ms),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ).animate().fade(delay: delay).scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack);
  }

  // ─────────────────────────────────────────────────────────────
  // Recommendations
  // ─────────────────────────────────────────────────────────────
  Widget _buildRecommendationsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI Recommendations',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600))
            .animate()
            .fade(delay: 800.ms),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.resumeUpload),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor.withOpacity(isDark ? 0.35 : 0.85),
                  AppTheme.primaryColor.withOpacity(isDark ? 0.20 : 0.70),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Skill Gap Analysis',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        _analyticsState == _AnalyticsState.loaded
                            ? 'See exactly which skills are missing for your target role.'
                            : 'Upload your resume to unlock skill gap analysis.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ).animate().fade(delay: 900.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Score Ring Painter
// ─────────────────────────────────────────────────────────────
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;

  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 6;
    const stroke = 9.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = background
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Feature Pill (onboarding card)
// ─────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}