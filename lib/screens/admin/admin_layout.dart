import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../repositories/auth_repository.dart';

// Tabs
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_payments_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_features_tab.dart';

class AdminLayoutScreen extends StatefulWidget {
  const AdminLayoutScreen({super.key});

  @override
  State<AdminLayoutScreen> createState() => _AdminLayoutScreenState();
}

class _AdminLayoutScreenState extends State<AdminLayoutScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const AdminOverviewTab(),
    const AdminAnalyticsTab(),
    const AdminUsersTab(),
    const AdminPaymentsTab(),
    const AdminFeaturesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: _tabs[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          )
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(0, 'Dashboard', Icons.dashboard),
                _buildNavItem(1, 'ML Analytics', Icons.analytics),
                _buildNavItem(2, 'Users', Icons.people),
                _buildNavItem(3, 'Payments', Icons.payment),
                _buildNavItem(4, 'Features', Icons.toggle_on),
              ],
            ),
          ),
          const Divider(),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(0, 'Dashboard', Icons.dashboard),
                _buildNavItem(1, 'ML Analytics', Icons.analytics),
                _buildNavItem(2, 'Users', Icons.people),
                _buildNavItem(3, 'Payments', Icons.payment),
                _buildNavItem(4, 'Features', Icons.toggle_on),
              ],
            ),
          ),
          const Divider(),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'CareerLens\nAdmin',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (MediaQuery.of(context).size.width < 800) {
          Navigator.pop(context); // Close drawer on mobile
        }
      },
    );
  }

  Widget _buildLogoutButton() {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text('Logout', style: TextStyle(color: Colors.red)),
      onTap: () async {
        await context.read<AuthRepository>().logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      },
    );
  }
}
