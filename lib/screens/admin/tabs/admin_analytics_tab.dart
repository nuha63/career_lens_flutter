import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../services/admin_service.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/glass_card.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _mlMetrics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await context.read<AuthRepository>().getCurrentUser();
      if (user == null) throw 'Not logged in';

      final adminService = context.read<AdminService>();
      final stats = await adminService.getDashboardStats(user.id);

      setState(() {
        _mlMetrics = stats['ml_metrics'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ML & AI Usage Analytics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track how frequently the AI systems are being utilized.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildMetricsGrid(),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = [
      {'title': 'Resume Analyses', 'key': 'resume_analyses', 'icon': Icons.document_scanner, 'color': Colors.blue},
      {'title': 'Job Matches Generated', 'key': 'job_matches', 'icon': Icons.work, 'color': Colors.orange},
      {'title': 'Roadmaps Generated', 'key': 'roadmaps_generated', 'icon': Icons.map, 'color': Colors.green},
      {'title': 'Salary Predictions', 'key': 'salary_predictions', 'icon': Icons.attach_money, 'color': Colors.purple},
      {'title': 'Skill Gap Analyses', 'key': 'skill_gap_analyses', 'icon': Icons.radar, 'color': Colors.teal},
    ];

    final isMobile = MediaQuery.of(context).size.width < 600;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        final value = _mlMetrics?[item['key']]?.toString() ?? '0';
        return _buildMetricCard(item['title'] as String, value, item['icon'] as IconData, item['color'] as Color);
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
