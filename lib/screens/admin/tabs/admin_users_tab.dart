import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../services/admin_service.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/glass_card.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic>? _users;

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
      final users = await adminService.getAllUsers(user.id, limit: 100);

      setState(() {
        _users = users;
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
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'View and manage registered users on the platform.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          if (_users == null || _users!.isEmpty)
            const GlassCard(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No users found.')),
              ),
            )
          else
            GlassCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Joined')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Role')),
                  ],
                  rows: _users!.map((u) {
                    DateTime? date;
                    if (u['created_at'] != null) {
                      date = DateTime.tryParse(u['created_at'].toString());
                    }
                    final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date.toLocal()) : 'Unknown';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                child: Text(
                                  (u['name']?.toString() ?? '').isNotEmpty ? u['name'].toString().substring(0, 1).toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(u['name'] ?? 'Unknown'),
                            ],
                          ),
                        ),
                        DataCell(Text(u['email'] ?? '')),
                        DataCell(Text(dateStr)),
                        DataCell(
                          u['is_premium'] == true
                              ? const Chip(
                                  label: Text('Premium', style: TextStyle(fontSize: 12, color: Colors.white)),
                                  backgroundColor: Colors.orange,
                                  visualDensity: VisualDensity.compact,
                                )
                              : const Chip(
                                  label: Text('Free', style: TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.grey,
                                  visualDensity: VisualDensity.compact,
                                ),
                        ),
                        DataCell(
                          Text(
                            u['is_admin'] == true ? 'Admin' : 'User',
                            style: TextStyle(fontWeight: u['is_admin'] == true ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
