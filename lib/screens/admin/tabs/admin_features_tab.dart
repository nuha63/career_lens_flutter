import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../services/admin_service.dart';
import '../../../repositories/auth_repository.dart';
import '../../../widgets/glass_card.dart';

class AdminFeaturesTab extends StatefulWidget {
  const AdminFeaturesTab({super.key});

  @override
  State<AdminFeaturesTab> createState() => _AdminFeaturesTabState();
}

class _AdminFeaturesTabState extends State<AdminFeaturesTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic>? _features;
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
      final features = await adminService.getSystemFeatures(_userId);

      setState(() {
        _features = features;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFeature(String featureId, bool newValue) async {
    final originalFeatures = List<dynamic>.from(_features ?? []);
    
    // Optimistic UI update
    setState(() {
      final index = _features?.indexWhere((f) => f['id'] == featureId) ?? -1;
      if (index != -1) {
        _features![index]['is_active'] = newValue;
      }
    });

    try {
      final adminService = context.read<AdminService>();
      await adminService.toggleFeature(_userId, featureId, newValue);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feature updated successfully.')),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _features = originalFeatures;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
                'Feature Controls',
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
            'Toggle AI and core features ON or OFF across the entire platform instantly.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          if (_features == null || _features!.isEmpty)
            const GlassCard(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No features found in the database. Restart the backend to initialize.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _features!.length,
              itemBuilder: (context, index) {
                final feature = _features![index];
                final isActive = feature['is_active'] as bool? ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    child: SwitchListTile(
                      title: Text(feature['name'] ?? 'Unknown Feature', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(feature['description'] ?? ''),
                      value: isActive,
                      activeColor: AppTheme.primaryColor,
                      secondary: Icon(
                        Icons.memory, 
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                      ),
                      onChanged: (val) => _toggleFeature(feature['id'], val),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
