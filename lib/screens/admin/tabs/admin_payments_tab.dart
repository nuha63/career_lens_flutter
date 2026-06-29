import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../services/admin_service.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/glass_card.dart';

class AdminPaymentsTab extends StatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  State<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends State<AdminPaymentsTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic>? _payments;
  late String _userId;

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
      _userId = user.id;

      final adminService = context.read<AdminService>();
      final payments = await adminService.getAllPayments(_userId, limit: 50);

      setState(() {
        _payments = payments;
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
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment $status successfully!')),
      );
      
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    final pending = _payments?.where((p) => p['status'] == 'pending').toList() ?? [];
    final history = _payments?.where((p) => p['status'] != 'pending').toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Premium Approval Queue',
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
            'Review and approve user payments to grant them Premium status.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          Text('Pending Reviews (${pending.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            const GlassCard(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No pending payments.')),
              ),
            )
          else
            _buildPaymentsTable(pending, isPending: true),
            
          const SizedBox(height: 32),
          Text('History', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const GlassCard(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No payment history.')),
              ),
            )
          else
            _buildPaymentsTable(history, isPending: false),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable(List<dynamic> payments, {required bool isPending}) {
    return GlassCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('User ID')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: payments.map((payment) {
            DateTime? date;
            if (payment['created_at'] != null) {
              date = DateTime.tryParse(payment['created_at'].toString());
            }
            final dateStr = date != null ? DateFormat('MMM dd, yyyy HH:mm').format(date.toLocal()) : 'Unknown';

            return DataRow(
              cells: [
                DataCell(Text(dateStr)),
                DataCell(Text((payment['user_id']?.toString() ?? '').length >= 8 ? payment['user_id'].toString().substring(0, 8) : payment['user_id']?.toString() ?? 'Unknown')),
                DataCell(Text('৳ ${payment['amount']}')),
                DataCell(Text(payment['method'] ?? 'Unknown')),
                DataCell(
                  Chip(
                    label: Text(payment['status'] ?? 'unknown', style: const TextStyle(fontSize: 12)),
                    backgroundColor: payment['status'] == 'approved' 
                        ? Colors.green[100] 
                        : payment['status'] == 'rejected' ? Colors.red[100] : Colors.orange[100],
                  ),
                ),
                DataCell(
                  isPending ? Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _handlePaymentAction(payment['id'], 'approved'),
                        child: const Text('Approve'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _handlePaymentAction(payment['id'], 'rejected'),
                        child: const Text('Reject'),
                      ),
                    ],
                  ) : const Text('-'),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
