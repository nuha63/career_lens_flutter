import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import '../../utils/helpers.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  bool _isUpgrading = false;

  Future<void> _handleUpgrade() async {
    setState(() => _isUpgrading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'User';
      final userEmail = prefs.getString(AppConstants.keyUserEmail) ?? 'user@example.com';

      final apiService = ApiService();
      final gatewayUrl = await apiService.initPayment(
        amount: 199,
        customerName: userName,
        customerEmail: userEmail,
      );

      if (gatewayUrl != null && gatewayUrl.isNotEmpty) {
        final uri = Uri.parse(gatewayUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch payment gateway';
        }
      } else {
        throw 'Invalid payment gateway URL received';
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast('Failed to start payment: $e');
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildPricingCard(context),
                const SizedBox(height: 32),
                _buildFeaturesList(context),
                const SizedBox(height: 48), // Padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium, color: Colors.orange, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          'CareerLens Premium',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock your full career potential with AI-powered insights.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPricingCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text(
            'Monthly Plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '৳',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '199',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                ' / month',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpgrading ? null : _handleUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isUpgrading 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(context, 'Salary Prediction', 'AI-powered salary estimates based on your profile.'),
        _buildFeatureItem(context, 'Unlimited Job Matching', 'Get daily personalized job matches without limits.'),
        _buildFeatureItem(context, 'Advanced Skill Gap Analysis', 'Detailed breakdown of missing skills and how to learn them.'),
        _buildFeatureItem(context, 'Premium Roadmaps', 'Detailed step-by-step career roadmaps with premium resources.'),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
