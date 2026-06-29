import 'package:flutter/material.dart';
import '../../models/career_roadmap_model.dart';
import '../../core/routes.dart';
import '../../repositories/roadmap_repository.dart';
import '../../core/theme.dart';

class CareerRoadmapScreen extends StatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  State<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends State<CareerRoadmapScreen> {
  final RoadmapRepository _roadmapRepository = RoadmapRepository();
  bool _isLoading = true;
  String? _error;
  List<CareerRoadmap> _roadmaps = [];

  @override
  void initState() {
    super.initState();
    _loadRoadmaps();
  }

  Future<void> _loadRoadmaps() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final roadmaps = await _roadmapRepository.getRoadmaps();
      setState(() {
        _roadmaps = roadmaps;
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Career Roadmaps',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading roadmaps: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRoadmaps,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_roadmaps.isEmpty) {
      return const Center(child: Text('No roadmaps found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roadmaps.length,
      itemBuilder: (context, index) {
        final roadmap = _roadmaps[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: const Icon(Icons.work_outline, color: AppTheme.primaryColor),
            ),
            title: Text(
              roadmap.careerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              roadmap.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { 
            debugPrint('Roadmap ID Sent: ${roadmap.id}'); 
              Navigator.pushNamed(
                context, 
                AppRoutes.careerRoadmapDetail, 
                arguments: {'roadmapId': roadmap.id},
              );
            },
          ),
        );
      },
    );
  }
}
