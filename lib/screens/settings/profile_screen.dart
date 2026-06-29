import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'User';
  String _userEmail = '';
  String _selectedMarket = '';
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? 'User';
    final userEmail = prefs.getString(AppConstants.keyUserEmail) ?? '';
    final market = prefs.getString(AppConstants.keyJobMarket);

    setState(() {
      _userName = userName;
      _userEmail = userEmail;
      _selectedMarket = market ?? AppConstants.marketBangladesh;
    });
  }

  Future<void> _handleUpgradePremium() async {
    setState(() => _isUpgrading = true);
    try {
      final apiService = ApiService();
      final gatewayUrl = await apiService.initPayment(
        amount: 500, // Example amount
        customerName: _userName,
        customerEmail: _userEmail,
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

  Future<void> _handleLogout() async {
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );

    if (!confirm || !mounted) return;

    try {
      final authService = AuthService();
      await authService.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      Helpers.showSuccessToast('Logged out successfully');
    } catch (e) {
      Helpers.showErrorToast('Logout failed: $e');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await Helpers.showConfirmDialog(
      context,
      title: 'Delete Account',
      message:
          'Are you sure you want to delete your account? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (!confirm || !mounted) return;

    try {
      final authService = AuthService();
      await authService.deleteAccount();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      Helpers.showSuccessToast('Account deleted successfully');
    } catch (e) {
      Helpers.showErrorToast('Failed to delete account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildProfileAnalytics(context),

            const SizedBox(height: 32),
            _buildBadges(context),

            const SizedBox(height: 32),

            // Settings Section
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Market Setting
            _buildSettingCard(
              icon: Icons.public,
              title: 'Job Market',
              subtitle: _selectedMarket == AppConstants.marketBangladesh
                  ? '🇧🇩 Bangladesh'
                  : '🌍 Global',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.marketSelection);
              },
            ),

            const SizedBox(height: 32),

            // Premium Section
            Text(
              'Subscription',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isUpgrading ? null : _handleUpgradePremium,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upgrade to Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isUpgrading ? 'Processing...' : 'Unlock advanced AI analytics',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isUpgrading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // About Section
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            _buildSettingCard(
              icon: Icons.info_outline,
              title: 'App Version',
              subtitle: AppConstants.appVersion,
              onTap: null,
            ),

            _buildSettingCard(
              icon: Icons.policy,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                Helpers.showInfoToast('Feature coming soon!');
              },
            ),

            _buildSettingCard(
              icon: Icons.description,
              title: 'Terms & Conditions',
              subtitle: 'Read terms and conditions',
              onTap: () {
                Helpers.showInfoToast('Feature coming soon!');
              },
            ),

            const SizedBox(height: 32),

            // Danger Zone
            Text(
              'Danger Zone',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.errorColor,
                  ),
            ),
            const SizedBox(height: 16),

            CustomButton(
              label: 'Logout',
              onPressed: _handleLogout,
              backgroundColor: AppTheme.textSecondary,
              icon: Icons.logout,
            ),

            const SizedBox(height: 12),

            CustomButton(
              label: 'Delete Account',
              onPressed: _handleDeleteAccount,
              backgroundColor: AppTheme.errorColor,
              icon: Icons.delete_forever,
            ),

            const SizedBox(height: 32),

            // Footer
            Text(
              '${AppConstants.appName} • Made with ❤️ for job seekers',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildProfileAnalytics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Profile Completion:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const Text('90%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 0.9,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  color: AppTheme.primaryColor,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 20),
              _buildChecklistItem('Name', true),
              _buildChecklistItem('Resume', true),
              _buildChecklistItem('Skills', true),
              _buildChecklistItem('Education', true),
              _buildChecklistItem('Projects', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String title, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Icon(
            isComplete ? Icons.check_circle : Icons.cancel,
            color: isComplete ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBadges(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievement Badges',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildBadgeItem('Resume Expert', Colors.amber),
            _buildBadgeItem('Skill Builder', Colors.blue),
            _buildBadgeItem('Career Explorer', Colors.green),
            _buildBadgeItem('Premium Member', Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeItem(String title, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.military_tech, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}