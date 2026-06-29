import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../services/admin_service.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/glass_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  List<dynamic>? _users;
  List<dynamic>? _payments;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      final user = await authRepo.getCurrentUser();
      
      if (user == null) {
        throw 'Not logged in';
      }
      _userId = user.id;

      final adminService = context.read<AdminService>();
      
      final results = await Future.wait([
        adminService.getDashboardStats(_userId),
        adminService.getAllUsers(_userId, limit: 10),
        adminService.getAllPayments(_userId, limit: 10),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<dynamic>;
        _payments = results[2] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePaymentAction(String paymentId, String status) async {
    try {
      final adminService = context.read<AdminService>();
      await adminService.updatePaymentStatus(_userId, paymentId, status);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment $status successfully!')),
      );
      
      // Reload data
      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthRepository>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAdminData,
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAdminData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsGrid(),
                        const SizedBox(height: 32),
                        _buildPendingPayments(),
                        const SizedBox(height: 32),
                        _buildRecentUsers(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              'Total Users',
              _stats?['total_users']?.toString() ?? '0',
              Icons.people,
              Colors.blue,
            ),
            _buildStatCard(
              'Premium',
              _stats?['premium_users']?.toString() ?? '0',
              Icons.workspace_premium,
              Colors.orange,
            ),
            _buildStatCard(
              'Revenue',
              '\$${(_stats?['total_revenue'] ?? 0).toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildStatCard(
              'Resumes Analyzed',
              _stats?['resume_analyses']?.toString() ?? '0',
              Icons.document_scanner,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPayments() {
    final pending = _payments?.where((p) => p['status'] == 'pending').toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Payments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Chip(
              label: Text('${pending.length}'),
              backgroundColor: pending.isEmpty ? Colors.grey[200] : Colors.orange[100],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pending.isEmpty)
          const GlassCard(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No pending payments to approve.')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final payment = pending[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.payment, color: Colors.white),
                  ),
                  title: Text('\$${payment['amount']} - User: ${(payment['user_id']?.toString() ?? '').length >= 8 ? payment['user_id'].toString().substring(0, 8) : payment['user_id']}...'),
                  subtitle: Text('Date: ${payment['created_at']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _handlePaymentAction(payment['id'], 'approved'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _handlePaymentAction(payment['id'], 'rejected'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Users',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_users == null || _users!.isEmpty)
          const GlassCard(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No users found.')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users!.length,
            itemBuilder: (context, index) {
              final user = _users![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    child: Text((user['name']?.toString() ?? '').isNotEmpty ? user['name'].toString().substring(0, 1).toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user['name'] ?? 'Unknown'),
                  subtitle: Text(user['email'] ?? ''),
                  trailing: user['is_premium'] == true
                      ? const Icon(Icons.workspace_premium, color: Colors.orange)
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }
}
